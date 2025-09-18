import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:snackflix/services/chewing_detection_service.dart';

class VerifyOverlay extends StatefulWidget {
  final VoidCallback onVerificationSuccess;
  final VoidCallback onManualContinue;

  const VerifyOverlay({
    Key? key,
    required this.onVerificationSuccess,
    required this.onManualContinue,
  }) : super(key: key);

  @override
  _VerifyOverlayState createState() => _VerifyOverlayState();
}

class _VerifyOverlayState extends State<VerifyOverlay> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  Timer? _manualContinueTimer;
  bool _showManualContinue = false;
  String _statusText = "Looking for face...";
  AnimationController? _animationController;
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final _chewingDetectionService = ChewingDetectionService();
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _chewingDetectionService.loadModel();
    _initializeCamera();
    _manualContinueTimer = Timer(Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _showManualContinue = true;
        });
      }
    });
    _animationController = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first);

    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
      _startImageStream();
    }
  }

  void _startImageStream() {
    _cameraController!.startImageStream((image) {
      if (_isDetecting) return;
      _isDetecting = true;
      _detectFace(image);
    });
  }

  Future<void> _detectFace(CameraImage image) async {
    final inputImage = InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty) {
      setState(() {
        _statusText = "Looking for snack...";
      });
      // TODO: Implement snack detection
      setState(() {
        _statusText = "Listening for chewing...";
      });

      final isChewing = _chewingDetectionService.isChewing(image);

      if (isChewing) {
        widget.onVerificationSuccess();
      }
    } else {
      if(mounted) {
        setState(() {
          _statusText = "Looking for face...";
        });
      }
    }

    _isDetecting = false;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _manualContinueTimer?.cancel();
    _animationController?.dispose();
    _faceDetector.close();
    _chewingDetectionService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "Time for a bite!",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          SizedBox(height: 20),
          _buildCameraPreview(),
          SizedBox(height: 20),
          Text(
            _statusText,
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          Spacer(),
          if (_showManualContinue)
            ElevatedButton(
              child: Text("Continue Manually"),
              onPressed: widget.onManualContinue,
            ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AnimatedBuilder(
      animation: _animationController!,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.withOpacity(_animationController!.value),
              width: 6,
            ),
          ),
          child: ClipOval(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  width: 150,
                  height: 150 / _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
