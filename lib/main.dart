import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:io';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  final FaceDetector _faceDetector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast, enableClassification: true));
  bool _isChewing = false;
  YoutubePlayerController? _youtubeController;
  Timer? _notEatingTimer;

  @override
  void initState() {
    super.initState();
    _youtubeController = YoutubePlayerController.fromVideoId(
      videoId: 'M-wjK4p_g_s', // A placeholder video
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
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

    final results = await Future.wait([
      _poseDetector.processImage(inputImage),
      _faceDetector.processImage(inputImage),
    ]);

    final List<Pose> poses = results[0] as List<Pose>;
    final List<Face> faces = results[1] as List<Face>;

    bool isEatingGesture = false;
    for (final pose in poses) {
      isEatingGesture = _isEatingGesture(pose);
      if (isEatingGesture) break;
    }

    bool isChewing = false;
    for (final face in faces) {
      if (face.smilingProbability != null && face.smilingProbability! > 0.7) {
        isChewing = true;
        break;
      }
    }

    bool isEating = isEatingGesture && isChewing;

    if (isEating) {
      _notEatingTimer?.cancel();
      _youtubeController?.play();
      if (_prediction != 'Eating') {
        setState(() {
          _prediction = 'Eating';
        });
      }
    } else {
      if (_notEatingTimer == null || !_notEatingTimer!.isActive) {
        _notEatingTimer = Timer(const Duration(seconds: 3), () {
          _youtubeController?.pause();
          if (_prediction != 'Not Eating') {
            setState(() {
              _prediction = 'Not Eating';
            });
          }
        });
      }
    }

    _isDetecting = false;
  }

  bool _isEatingGesture(Pose pose) {
    final mouthLeft = pose.landmarks[PoseLandmarkType.mouthLeft];
    final mouthRight = pose.landmarks[PoseLandmarkType.mouthRight];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (mouthLeft == null || mouthRight == null || leftEye == null || rightEye == null) {
      return false;
    }

    final mouthX = (mouthLeft.x + mouthRight.x) / 2;
    final mouthY = (mouthLeft.y + mouthRight.y) / 2;

    final eyeDistance = (leftEye.x - rightEye.x).abs();
    if (eyeDistance < 10) return false;

    final handLandmarks = [
      pose.landmarks[PoseLandmarkType.rightWrist],
      pose.landmarks[PoseLandmarkType.rightIndex],
      pose.landmarks[PoseLandmarkType.rightThumb],
      pose.landmarks[PoseLandmarkType.leftWrist],
      pose.landmarks[PoseLandmarkType.leftIndex],
      pose.landmarks[PoseLandmarkType.leftThumb],
    ];

    for (final landmark in handLandmarks) {
      if (landmark != null) {
        final distance = (landmark.x - mouthX).abs() + (landmark.y - mouthY).abs();
        final normalizedDistance = distance / eyeDistance;
        if (normalizedDistance < 1.0) { // Increased threshold
          return true; // Eating gesture detected
        }
      }
    }

    return false; // No eating gesture detected
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
    _faceDetector.close();
    _youtubeController?.close();
    _notEatingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnackFlix'),
      ),
      body: Stack(
        children: [
          if (_youtubeController != null)
            YoutubePlayerScaffold(
              controller: _youtubeController!,
              builder: (context, player) {
                return player;
              },
            ),
          Positioned(
            top: 20,
            right: 20,
            child: SizedBox(
              width: 100,
              height: 150,
              child: _cameraController != null && _cameraController!.value.isInitialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CameraPreview(_cameraController!),
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
            ),
          ),
          Positioned(
            top: 175,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: _prediction == 'Eating' ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _prediction,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
