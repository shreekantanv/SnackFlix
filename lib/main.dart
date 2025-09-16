import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
      _cameraController = CameraController(cameras[0], ResolutionPreset.high);
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
    var input = _preprocessImage(image);

    if (_interpreter == null || input == null) {
      _isDetecting = false;
      return;
    }

    var output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);
    try {
      _interpreter!.run(input, output);

      var maxScore = 0.0;
      var maxIndex = -1;
      for (var i = 0; i < output[0].length; i++) {
        if (output[0][i] > maxScore) {
          maxScore = output[0][i];
          maxIndex = i;
        }
      }

      if (maxIndex != -1) {
        final predictedLabel = _labels![maxIndex];
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

    img.Image resizedImage = img.copyResize(convertedImage, width: 224, height: 224);

    var imageAsFloat32List = Float32List(1 * 224 * 224 * 3);
    var buffer = Float32List.view(imageAsFloat32List.buffer);
    int pixelIndex = 0;
    for (var y = 0; y < resizedImage.height; y++) {
      for (var x = 0; x < resizedImage.width; x++) {
        var pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    return imageAsFloat32List.reshape([1, 224, 224, 3]);
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
