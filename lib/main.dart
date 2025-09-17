import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String>? _labels;
  String _prediction = "Not Eating";
  bool _isDetecting = false;

  List<Object>? _modelState;
  final Map<int, Object> _outputBuffers = {};
  int _logitsOutputIndex = 0;

  @override
  void initState() {
    super.initState();
    _initEverything();
  }

  Future<void> _initEverything() async {
    await _initTflite();
    await _initCamera();
  }

  Future<void> _initTflite() async {
    try {
      final interpreterOptions = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(
        'assets/models/movinet_a0_stream_float16.tflite',
        options: interpreterOptions,
      );
      _interpreter!.allocateTensors();

      // Print input and output tensor details
      print("Input Tensors:");
      for (final tensor in _interpreter!.getInputTensors()) {
        print("- ${tensor.name}: ${tensor.shape}");
      }
      print("Output Tensors:");
      for (final tensor in _interpreter!.getOutputTensors()) {
        print("- ${tensor.name}: ${tensor.shape}");
      }

      // Initialize state
      _modelState = [];
      for (final tensor in _interpreter!.getInputTensors().sublist(1)) {
        _modelState!.add(List.filled(tensor.shape.reduce((a, b) => a * b), 0.0).reshape(tensor.shape));
      }

      // Prepare output buffers
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < outputTensors.length; i++) {
        final tensor = outputTensors[i];
        _outputBuffers[i] = List.filled(tensor.shape.reduce((a, b) => a * b), 0.0).reshape(tensor.shape);
      }

      // Assuming the first output tensor is the logits
      _logitsOutputIndex = 0;

      _labels = await _loadLabels();
    } catch (e) {
      print('Failed to load TFLite model: $e');
    }
  }

  Future<List<String>> _loadLabels() async {
    final labelsData = await rootBundle.loadString('assets/labels/kinetics_600_labels.txt');
    return labelsData.split('\n');
  }

  Future<void> _initCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras available');
        return;
      }

      // Find the front camera
      CameraDescription frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras[0], // fallback to the first camera if no front camera is found
      );

      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
      _startDetection();
    } else {
      print('Camera permission denied');
    }
  }

  void _startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _cameraController!.startImageStream((CameraImage image) {
      if (_isDetecting) return;
      _isDetecting = true;
      _runInference(image);
    });
  }

  Future<void> _runInference(CameraImage image) async {
    try {
      var inputImage = _preprocessImage(image);
      if (_interpreter == null || inputImage == null || _modelState == null) {
        return;
      }

      final inputs = [inputImage, ..._modelState!];

      _interpreter!.run(inputs, _outputBuffers);

      // Update state
      // Assuming the output state tensors are in the same order as the input state tensors, starting from index 1.
      for (int i = 0; i < _modelState!.length; i++) {
        _modelState![i] = _outputBuffers[i+1]!;
      }

      final outputLogits = _outputBuffers[_logitsOutputIndex] as List<List<double>>;

      // Process logits
      var maxScore = 0.0;
      var maxIndex = -1;
      for (var i = 0; i < outputLogits[0].length; i++) {
          if (outputLogits[0][i] > maxScore) {
              maxScore = outputLogits[0][i];
              maxIndex = i;
          }
      }

      if (maxIndex != -1) {
          final predictedLabel = _labels![maxIndex];
          print("Prediction: $predictedLabel, Score: ${outputLogits[0][maxIndex]}");
          _updatePrediction(predictedLabel);
      }
    } catch (e) {
      print("Error running inference: $e");
    } finally {
      _isDetecting = false;
    }
  }

  void _updatePrediction(String predictedLabel) {
    const eatingKeywords = ['eating', 'tasting food', 'chewing gum', 'drinking'];
    bool isEating = eatingKeywords.any((keyword) => predictedLabel.toLowerCase().contains(keyword));

    setState(() {
      _prediction = isEating ? 'Eating' : 'Not Eating';
    });
  }

  dynamic _preprocessImage(CameraImage image) {
    img.Image? convertedImage = _convertCameraImage(image);
    if (convertedImage == null) {
      return null;
    }

    img.Image resizedImage = img.copyResize(convertedImage, width: 172, height: 172);

    var imageAsFloat32List = Float32List(1 * 1 * 172 * 172 * 3);
    var buffer = Float32List.view(imageAsFloat32List.buffer);
    int pixelIndex = 0;
    for (var y = 0; y < resizedImage.height; y++) {
      for (var x = 0; x < resizedImage.width; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return imageAsFloat32List.reshape([1, 1, 172, 172, 3]);
  }

  img.Image? _convertCameraImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToImage(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888ToImage(image);
    }
    return null;
  }

  img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final imageWidth = cameraImage.width;
    final imageHeight = cameraImage.height;

    final yBuffer = cameraImage.planes[0].bytes;
    final uBuffer = cameraImage.planes[1].bytes;
    final vBuffer = cameraImage.planes[2].bytes;

    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = img.Image(width: imageWidth, height: imageHeight);

    for (int h = 0; h < imageHeight; h++) {
      int uvh = (h / 2).floor();

      for (int w = 0; w < imageWidth; w++) {
        int uvw = (w / 2).floor();

        final yIndex = (h * yRowStride) + (w * yPixelStride);

        final int y = yBuffer[yIndex];

        final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

        final int u = uBuffer[uvIndex];
        final int v = vBuffer[uvIndex];

        int r = (y + v * 1436 / 1024 - 179).round();
        int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
        int b = (y + u * 1814 / 1024 - 227).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(w, h, r, g, b);
      }
    }

    return image;
  }

  img.Image _convertBGRA8888ToImage(CameraImage image) {
    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Am I Eating?'),
      ),
      body: Stack(
        children: [
          _cameraController == null || !_cameraController!.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : CameraPreview(_cameraController!),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _prediction,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
