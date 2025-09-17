import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:io';

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
  String _prediction = "Not Eating";
  bool _isDetecting = false;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());

  @override
  void initState() {
    super.initState();
    _initCamera();
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
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    final List<Pose> poses = await _poseDetector.processImage(inputImage);

    bool isEating = false;
    for (final pose in poses) {
      // Check for hand-to-mouth gesture
      isEating = _isEatingGesture(pose);
      if (isEating) break;
    }

    setState(() {
      _prediction = isEating ? 'Eating' : 'Not Eating';
    });

    _isDetecting = false;
  }

  bool _isEatingGesture(Pose pose) {
    // This is a simplified logic. A more robust implementation would be needed.
    final rightHand = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHand = pose.landmarks[PoseLandmarkType.leftWrist];
    final mouthLeft = pose.landmarks[PoseLandmarkType.mouthLeft];
    final mouthRight = pose.landmarks[PoseLandmarkType.mouthRight];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (mouthLeft == null || mouthRight == null || nose == null) return false;

    final mouthX = (mouthLeft.x + mouthRight.x) / 2;
    final mouthY = (mouthLeft.y + mouthRight.y) / 2;

    bool rightHandNearMouth = false;
    if (rightHand != null) {
      final distance = (rightHand.x - mouthX).abs() + (rightHand.y - mouthY).abs();
      // Also check if hand is higher than the nose (to avoid detecting hand on chin)
      if (distance < 80 && rightHand.y < nose.y) {
        rightHandNearMouth = true;
      }
    }

    bool leftHandNearMouth = false;
    if (leftHand != null) {
      final distance = (leftHand.x - mouthX).abs() + (leftHand.y - mouthY).abs();
      if (distance < 80 && leftHand.y < nose.y) {
        leftHandNearMouth = true;
      }
    }

    return rightHandNearMouth || leftHandNearMouth;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // then get it from the device specification
    final sensorOrientation = _cameraController!.description.sensorOrientation;
    InputImageRotation? rotation;
    final orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final rotationCompensation = orientations[_cameraController!.value.deviceOrientation] ?? 0;
    final finalRotation = (sensorOrientation + rotationCompensation) % 360;
    rotation = InputImageRotationValue.fromRawValue(finalRotation);
    if (rotation == null) return null;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
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
