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

  Map<int, Object> _modelState = {};
  final Map<int, Object> _outputBuffers = {};
  int _imageInputIndex = -1;
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
        'assets/models/movinet_a0_stream_int.tflite',
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

      // Find image and state tensor indices
      final inputTensors = _interpreter!.getInputTensors();
      for (int i = 0; i < inputTensors.length; i++) {
        if (inputTensors[i].name == 'serving_default_image:0') {
          _imageInputIndex = i;
        } else {
          _modelState[i] = Uint8List(inputTensors[i].shape.reduce((a, b) => a * b)).reshape(inputTensors[i].shape);
        }
      }

      // Prepare output buffers
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < outputTensors.length; i++) {
        final tensor = outputTensors[i];
        _outputBuffers[i] = Uint8List(tensor.shape.reduce((a, b) => a * b)).reshape(tensor.shape);
      }

      // Find logits output tensor index
      for (int i = 0; i < outputTensors.length; i++) {
        if (outputTensors[i].shape.length == 2 && outputTensors[i].shape[1] == 600) {
          _logitsOutputIndex = i;
          break;
        }
      }

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
      if (_interpreter == null || inputImage == null) {
        return;
      }

      // Prepare inputs
      final inputs = List<Object>.filled(_interpreter!.getInputTensors().length, 0);
      if (_imageInputIndex != -1) {
        inputs[_imageInputIndex] = inputImage;
      }
      for (var entry in _modelState.entries) {
        inputs[entry.key] = entry.value;
      }

      _interpreter!.run(inputs, _outputBuffers);

      // Update state
      final inputStateIndices = _modelState.keys.toList();
      final outputStateIndices = _outputBuffers.keys.where((i) => i != _logitsOutputIndex).toList();

      for (int i = 0; i < inputStateIndices.length; i++) {
        final inputIndex = inputStateIndices[i];
        final outputIndex = outputStateIndices[i];
        _modelState[inputIndex] = _outputBuffers[outputIndex]!;
      }

      final outputLogits = (_outputBuffers[_logitsOutputIndex] as List<Uint8List>)[0];

      // Dequantize the output
      final logitsTensor = _interpreter!.getOutputTensor(_logitsOutputIndex);
      final scale = logitsTensor.params?.scale ?? 1.0;
      final zeroPoint = logitsTensor.params?.zeroPoint ?? 0;

      final dequantizedLogits = outputLogits.map((value) => (value - zeroPoint) * scale).toList();

      // Process logits
      var maxScore = 0.0;
      var maxIndex = -1;
      for (var i = 0; i < dequantizedLogits.length; i++) {
          if (dequantizedLogits[i] > maxScore) {
              maxScore = dequantizedLogits[i];
              maxIndex = i;
          }
      }

      if (maxIndex != -1) {
          final predictedLabel = _labels![maxIndex];
          print("Prediction: $predictedLabel, Score: $maxScore");
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

    var imageAsBytes = resizedImage.getBytes(order: img.ChannelOrder.rgb);
    var imageAsUint8List = Uint8List.fromList(imageAsBytes);

    return imageAsUint8List.reshape([1, 1, 172, 172, 3]);
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
