import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

// Tunables from the user's code
const bool _BATTERY_SAVER = true;
const int _FACE_IDLE_EVERY = 8;
const int _FACE_APPROACH_EVERY = 2;
const int _FACE_EAT_EVERY = 4;
const int _OBJ_APPROACH_EVERY = 2;
const int _POSE_IDLE_EVERY = 8;
const int _POSE_APPROACH_EVERY = 3;
const int _THUMB_W = 48, _THUMB_H = 36;
const double _MOTION_SKIP_THR = 1.5;
const int _WATCHDOG_FACE_EVERY = 20;
const _WIN_MAX = 60;
const _TEETH_BRIGHT_THR = 200;
const _TEETH_EDGE_THR = 35;
const _TEETH_SCORE_THR = 0.22;
const _MAR_MIN_FOR_TEETH = 0.10;
const _MAR_OPEN_THR = 0.14;
const _MAR_CLOSE_THR = 0.09;
const _MOUTH_BOX_W_SCALE = 0.95;
const _MOUTH_BOX_H_SCALE = 0.60;
const _NEAR_IOU_THR = 0.05;
const _NEAR_DIST_SCALE = 0.85;
const _OBJ_MOTION_DELTA = 4.0;
const _FOOD_PERSIST_MS = 2000;
const _FOOD_MIN_HITS = 2;
const _HAND_GATE_MS = 1200;
const _HAND_MIN_PIX_RATIO = 0.05;
const _WRIST_NEAR_SCALE = 0.95;
const _APPROACH_TIMEOUT_MS = 1800;
const _BITE_MAX_WINDOW_MS = 900;
const _CHEW_GRACE_MS = 2200;
const _MAR_SMOOTH_ALPHA = 0.30;
const _BITE_MIN_OPEN = 0.13;
const _BITE_DROP_DELTA = -0.040;
const double _CHEW_STD_MIN = 0.018;

enum EatState { idle, approach, bite, chewing, grace }

class InputPack {
  final InputImage image;
  final Uint8List bytes;
  final int width, height;
  final InputImageRotation rotation;
  final bool isNV21;
  final int bytesPerRow;
  InputPack({
    required this.image,
    required this.bytes,
    required this.width,
    required this.height,
    required this.rotation,
    required this.isNV21,
    required this.bytesPerRow,
  });
}

class DetVis {
  final Rect box;
  final String label;
  final double conf;
  final int? id;
  final bool near;
  final double iou;
  final double dist;
  final bool movingCloser;
  DetVis(this.box, this.label, this.conf, this.id, this.near, this.iou, this.dist, this.movingCloser);
}

class ChewingDetectionService extends ChangeNotifier {
  // Camera + hot-swap guards
  CameraController? _cam;
  CameraController? get cameraController => _cam;

  bool _camReady = false;
  bool get isCameraReady => _camReady;

  int _camGen = 0;
  bool _restartingCam = false;
  ResolutionPreset _currentPreset = _BATTERY_SAVER ? ResolutionPreset.medium : ResolutionPreset.high;
  int _frameCounter = 0;
  bool _busy = false;

  // Models
  late final FaceDetector _faces = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    ),
  );
  late final ObjectDetector _obj = ObjectDetector(
    options: ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    ),
  );
  late final PoseDetector _pose = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  // Adaptive cadences
  int _faceEvery = _FACE_IDLE_EVERY;
  int _objEvery = 9999;
  int _poseEvery = _POSE_IDLE_EVERY;

  // Mouth / chewing
  final List<double> _marWin = <double>[];
  DateTime? _lastPeak;
  final List<DateTime> _recentPeaks = <DateTime>[];
  double? _marSmooth;
  double _marDelta = 0;
  bool _mouthOpen = false;

  // Cues / gates
  double _teethScore = 0.0;
  double get teethScore => _teethScore;

  final List<DateTime> _foodNearHits = [];
  DateTime? _lastHandNear;
  final Map<int, Offset> _lastObjCenter = {};
  double _approachScore = 0.0;
  double get approachScore => _approachScore;

  // FSM
  EatState _state = EatState.idle;
  EatState get state => _state;

  DateTime? _tState;
  DateTime? _tLastBite;

  // Motion gate
  Uint8List? _thumbPrev;

  // UI / debug
  String _status = 'Not Eating';
  String get status => _status;

  double _confidence = 0.0;
  double get confidence => _confidence;

  int _frames = 0;
  int _chewFrames = 0;
  Rect? _mouthBoxLast;
  Rect? get mouthBoxLast => _mouthBoxLast;

  List<DetVis> _visBoxes = [];
  List<DetVis> get visBoxes => _visBoxes;

  List<String> _objDebug = [];
  List<String> get objDebug => _objDebug;

  bool _isDisposed = false;

  Future<bool> initialize() async {
    _isDisposed = false;
    return await _initCam();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _camGen++;
    try {
      _cam?.stopImageStream();
    } catch (_) {}
    _cam?.dispose();
    _cam = null;
    _faces.close();
    _obj.close();
    _pose.close();
    super.dispose();
  }

  Future<bool> _initCam() async {
    _restartingCam = true;
    _camReady = false;
    notifyListeners();

    _camGen++;

    final ok = await Permission.camera.request();
    if (!ok.isGranted) {
      _status = 'Camera permission required';
      notifyListeners();
      return false;
    }

    final cams = await availableCameras();
    if (cams.isEmpty) {
      _status = 'No camera available';
      notifyListeners();
      return false;
    }

    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );

    final genAtStart = _camGen;

    final controller = CameraController(
      front,
      _currentPreset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
    } catch (e) {
      _status = "Failed to initialize camera";
      notifyListeners();
      return false;
    }

    if (_isDisposed || genAtStart != _camGen) {
      try {
        await controller.dispose();
      } catch (_) {}
      return false;
    }

    _cam = controller;

    await _cam!.startImageStream((img) async {
      if (genAtStart != _camGen) return;
      _frameCounter++;
      if (_busy) return;
      _busy = true;
      await _onFrame(img);
      _busy = false;
    });

    if (_isDisposed || genAtStart != _camGen) return false;

    _camReady = true;
    _restartingCam = false;
    notifyListeners();
    return true;
  }

  Future<void> _onFrame(CameraImage img) async {
    try {
      final pack = _toPack(img);
      if (pack == null) return;

      final watchdog = (_frameCounter % _WATCHDOG_FACE_EVERY == 0);
      if (_state == EatState.idle && !watchdog) {
        final motion = _cheapMotionScore(pack);
        if (motion < _MOTION_SKIP_THR) return;
      }

      _applyAdaptiveSchedule();

      final doFace = watchdog || (_frameCounter % _faceEvery == 0);
      if (!doFace) return;

      final faces = await _faces.processImage(pack.image);
      if (faces.isEmpty) {
        _pushMar(null);
        _teethScore = 0.0;
        _mouthBoxLast = null;
        _visBoxes = [];
        _objDebug = ['— no face —'];
        _stepFsm(noFace: true);
        return;
      }
      faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
      final f = faces.first;

      final mar = _computeMAR(f);
      _pushMar(mar);
      final prevSmooth = _marSmooth ?? (mar ?? 0.0);
      if (mar != null) {
        _marSmooth = prevSmooth * (1 - _MAR_SMOOTH_ALPHA) + mar * _MAR_SMOOTH_ALPHA;
      } else {
        _marSmooth = prevSmooth * 0.98;
      }
      _marDelta = _marSmooth! - prevSmooth;
      final wasOpen = _mouthOpen;
      _mouthOpen = (mar ?? 0) > _MAR_OPEN_THR || ((mar ?? 0) > _MAR_CLOSE_THR && wasOpen);

      _teethScore = _estimateTeethScore(f, pack);
      final teethGate = (_teethScore > _TEETH_SCORE_THR) && (mar != null && mar > _MAR_MIN_FOR_TEETH);

      final lm = f.landmarks[FaceLandmarkType.leftMouth]?.position;
      final rm = f.landmarks[FaceLandmarkType.rightMouth]?.position;
      Rect? mouthBox;
      Offset? mouthCenter;
      if (lm != null && rm != null) {
        mouthCenter = Offset((lm.x + rm.x) / 2.0, (lm.y + rm.y) / 2.0);
        final faceW = f.boundingBox.width.toDouble();
        final faceH = f.boundingBox.height.toDouble();
        mouthBox = Rect.fromCenter(
          center: mouthCenter,
          width: faceW * _MOUTH_BOX_W_SCALE,
          height: faceH * _MOUTH_BOX_H_SCALE,
        );
      }
      _mouthBoxLast = mouthBox;

      bool objNearNow = false;
      bool handNearNow = false;
      double wristNearScore = 0.0;

      if (mouthBox != null) {
        handNearNow = _handNearHeuristic(pack, mouthBox);
        if (handNearNow) _lastHandNear = DateTime.now();

        final poseCadence = (_state == EatState.approach) ? _POSE_APPROACH_EVERY : _POSE_IDLE_EVERY;
        if (_frameCounter % poseCadence == 0 && mouthCenter != null) {
          final d = await _wristToMouthDistance(pack, f);
          if (d != null) {
            final faceW = f.boundingBox.width.toDouble();
            final thr = faceW * _WRIST_NEAR_SCALE;
            wristNearScore = (1.0 - (d / (thr + 1e-6))).clamp(0.0, 1.0);
          }
        }

        if (_state == EatState.approach && _frameCounter % _objEvery == 0) {
          await _detectFoodNearMouth(f, pack, mouthBox);
          objNearNow =
              _foodNearHits.isNotEmpty && DateTime.now().difference(_foodNearHits.last).inMilliseconds < 450;
        } else if (_state != EatState.approach) {
          if (_objDebug.isEmpty) _objDebug = ['(obj idle)'];
          _visBoxes = [];
        }
      }

      final objScore = objNearNow ? 1.0 : 0.0;
      final handScore = handNearNow ? 0.7 : 0.0;
      _approachScore = math.max(objScore, math.max(handScore, wristNearScore));

      _updateFoodGate();

      final chewingNow = _chewingNow();
      _stepFsm(
        mouthOpen: _mouthOpen,
        chewingNow: chewingNow,
        approachScore: _approachScore,
        noFace: false,
        marSmooth: _marSmooth,
        marDelta: _marDelta,
        teethGate: teethGate,
      );
    } catch (_) {
      // swallow per-frame errors
    }
  }

  Future<void> _ensurePreset(ResolutionPreset preset) async {
    if (_currentPreset == preset) return;

    _restartingCam = true;
    _camReady = false;
    notifyListeners();

    _camGen++;

    try {
      await _cam?.stopImageStream();
    } catch (_) {}
    try {
      await _cam?.dispose();
    } catch (_) {}
    _cam = null;

    _currentPreset = preset;

    final cams = await availableCameras();
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    final genAtStart = _camGen;

    final controller = CameraController(
      front,
      _currentPreset,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (_isDisposed || genAtStart != _camGen) {
      try {
        await controller.dispose();
      } catch (_) {}
      return;
    }

    _cam = controller;

    await _cam!.startImageStream((img) async {
      if (genAtStart != _camGen) return;
      _frameCounter++;
      if (_busy) return;
      _busy = true;
      await _onFrame(img);
      _busy = false;
    });

    if (_isDisposed || genAtStart != _camGen) return;

    _camReady = true;
    _restartingCam = false;
    notifyListeners();
  }

  void _applyAdaptiveSchedule() {
    switch (_state) {
      case EatState.idle:
        _faceEvery = _FACE_IDLE_EVERY;
        _objEvery = 9999;
        _poseEvery = _POSE_IDLE_EVERY;
        if (_BATTERY_SAVER) {
          _ensurePreset(ResolutionPreset.medium);
        }
        break;
      case EatState.approach:
        _faceEvery = _FACE_APPROACH_EVERY;
        _objEvery = _OBJ_APPROACH_EVERY;
        _poseEvery = _POSE_APPROACH_EVERY;
        if (_BATTERY_SAVER) {
          _ensurePreset(ResolutionPreset.high);
        }
        break;
      case EatState.bite:
        _faceEvery = _FACE_APPROACH_EVERY;
        _objEvery = 9999;
        _poseEvery = 9999;
        break;
      case EatState.chewing:
      case EatState.grace:
        _faceEvery = _FACE_EAT_EVERY;
        _objEvery = 9999;
        _poseEvery = 9999;
        if (_BATTERY_SAVER) {
          _ensurePreset(ResolutionPreset.medium);
        }
        break;
    }
  }

  double _cheapMotionScore(InputPack p) {
    final thumb = _makeThumb(p);
    double avg = 255.0;
    if (_thumbPrev != null && _thumbPrev!.length == thumb.length) {
      int sum = 0;
      for (int i = 0; i < thumb.length; i++) {
        sum += (thumb[i] - _thumbPrev![i]).abs();
      }
      avg = sum / thumb.length;
    }
    _thumbPrev = thumb;
    return avg.toDouble();
  }

  Uint8List _makeThumb(InputPack p) {
    final out = Uint8List(_THUMB_W * _THUMB_H);
    final srcW = p.width, srcH = p.height;
    final cx0 = ((srcW - (srcH * 4 ~/ 3)) / 2).clamp(0, srcW).toInt();
    final cw = srcW - 2 * cx0;
    for (int ty = 0; ty < _THUMB_H; ty++) {
      final sy = (ty * srcH / _THUMB_H).floor();
      for (int tx = 0; tx < _THUMB_W; tx++) {
        final sx = cx0 + (tx * cw / _THUMB_W).floor();
        final y = _getLuma(sx, sy, p) ?? 0;
        out[ty * _THUMB_W + tx] = y;
      }
    }
    return out;
  }

  InputPack? _toPack(CameraImage image) {
    final camDesc = _cam?.description;
    final rot = camDesc != null
        ? InputImageRotationValue.fromRawValue(camDesc.sensorOrientation)
        : InputImageRotation.rotation0deg;

    if (Platform.isAndroid) {
      Uint8List nv21Bytes;
      if (image.format.group == ImageFormatGroup.nv21 && image.planes.length == 1) {
        nv21Bytes = image.planes[0].bytes;
      } else {
        if (image.planes.length != 3) return null;
        nv21Bytes = _yuv420ToNv21(image);
      }
      final input = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rot!,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
      return InputPack(
        image: input,
        bytes: nv21Bytes,
        width: image.width,
        height: image.height,
        rotation: rot,
        isNV21: true,
        bytesPerRow: image.width,
      );
    } else {
      if (image.format.group != ImageFormatGroup.bgra8888 || image.planes.length != 1) return null;
      final p0 = image.planes[0];
      final input = InputImage.fromBytes(
        bytes: p0.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rot!,
          format: InputImageFormat.bgra8888,
          bytesPerRow: p0.bytesPerRow,
        ),
      );
      return InputPack(
        image: input,
        bytes: p0.bytes,
        width: image.width,
        height: image.height,
        rotation: rot,
        isNV21: false,
        bytesPerRow: p0.bytesPerRow,
      );
    }
  }

  Uint8List _yuv420ToNv21(CameraImage img) {
    final w = img.width, h = img.height;
    final yPlane = img.planes[0];
    final uPlane = img.planes[1];
    final vPlane = img.planes[2];

    final out = Uint8List(w * h + (w * h) ~/ 2);
    int di = 0;
    for (int r = 0; r < h; r++) {
      final srcOff = r * yPlane.bytesPerRow;
      out.setRange(di, di + w, yPlane.bytes.sublist(srcOff, srcOff + w));
      di += w;
    }

    final uvHeight = h ~/ 2;
    final uvWidth = w ~/ 2;
    final uRow = uPlane.bytesPerRow;
    final vRow = vPlane.bytesPerRow;
    final uPix = uPlane.bytesPerPixel ?? 1;
    final vPix = vPlane.bytesPerPixel ?? 1;

    for (int r = 0; r < uvHeight; r++) {
      final uBase = r * uRow;
      final vBase = r * vRow;
      for (int c = 0; c < uvWidth; c++) {
        final u = uPlane.bytes[uBase + c * uPix];
        final v = vPlane.bytes[vBase + c * vPix];
        out[di++] = v;
        out[di++] = u;
      }
    }
    return out;
  }

  void _pushMar(double? mar) {
    _frames++;
    _marWin.add(mar ?? double.nan);
    if (_marWin.length > _WIN_MAX) _marWin.removeAt(0);
  }

  double? _computeMAR(Face f) {
    final upperIn = f.contours[FaceContourType.upperLipBottom]?.points;
    final lowerIn = f.contours[FaceContourType.lowerLipTop]?.points;
    final up = (upperIn != null && upperIn.isNotEmpty) ? _avgPoint(upperIn) : null;
    final lo = (lowerIn != null && lowerIn.isNotEmpty) ? _avgPoint(lowerIn) : null;

    final ml = f.landmarks[FaceLandmarkType.leftMouth]?.position;
    final mr = f.landmarks[FaceLandmarkType.rightMouth]?.position;

    double? width;
    if (ml != null && mr != null) {
      width = _dist(ml.x, ml.y, mr.x, mr.y);
    } else {
      final allLip = <Offset>[];
      for (final t in [
        FaceContourType.upperLipTop,
        FaceContourType.upperLipBottom,
        FaceContourType.lowerLipTop,
        FaceContourType.lowerLipBottom,
      ]) {
        final pts = f.contours[t]?.points ?? const [];
        for (final p in pts) {
          allLip.add(Offset(p.x.toDouble(), p.y.toDouble()));
        }
      }
      if (allLip.isNotEmpty) {
        final xs = allLip.map((e) => e.dx).toList()..sort();
        width = xs.last - xs.first;
      }
    }

    if (up == null || lo == null || width == null || width <= 1) return null;
    final gap = (lo.dy - up.dy).abs();
    return gap / width;
  }

  bool _chewingNow() {
    if (_marWin.isEmpty) return false;

    final vals = <double>[];
    for (final v in _marWin) if (!v.isNaN) vals.add(v);
    if (vals.length < 8) return false;

    final mean = vals.reduce((a, b) => a + b) / vals.length;
    double variance = 0.0;
    for (final v in vals) {
      final d = v - mean;
      variance += d * d;
    }
    final std = math.sqrt(variance / vals.length);

    final now = DateTime.now();
    final thr = mean + math.max(0.03, 0.5 * std);
    final last = vals.last;
    final prev = vals[vals.length - 2];
    final minGap = const Duration(milliseconds: 300);
    final maxGap = const Duration(milliseconds: 1600);
    final lastPeakOk = _lastPeak == null || now.difference(_lastPeak!) >= minGap;

    if (prev <= thr && last > thr && lastPeakOk) {
      _lastPeak = now;
      _recentPeaks.add(now);
      _recentPeaks.removeWhere((t) => now.difference(t).inMilliseconds > 4000);
    }

    int validPeaks = 0;
    for (int i = 1; i < _recentPeaks.length; i++) {
      final gap = _recentPeaks[i].difference(_recentPeaks[i - 1]);
      if (gap >= minGap && gap <= maxGap) validPeaks++;
    }

    final chewing = (validPeaks >= 2) && (std > _CHEW_STD_MIN);
    if (chewing) _chewFrames++;
    return chewing;
  }

  double _estimateTeethScore(Face f, InputPack p) {
    final up = f.contours[FaceContourType.upperLipBottom]?.points ?? const [];
    final lo = f.contours[FaceContourType.lowerLipTop]?.points ?? const [];
    final lm = f.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rm = f.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (up.isEmpty || lo.isEmpty) return 0.0;

    final mouthPts = <Offset>[
      ...up.map((e) => Offset(e.x.toDouble(), e.y.toDouble())),
      ...lo.map((e) => Offset(e.x.toDouble(), e.y.toDouble())),
      if (lm != null) Offset(lm.x.toDouble(), lm.y.toDouble()),
      if (rm != null) Offset(rm.x.toDouble(), rm.y.toDouble()),
    ];

    double minX = double.infinity, minY = double.infinity, maxX = -1, maxY = -1;
    for (final o in mouthPts) {
      if (o.dx < minX) minX = o.dx;
      if (o.dy < minY) minY = o.dy;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy > maxY) maxY = o.dy;
    }
    if (minX.isInfinite) return 0.0;

    final w = (maxX - minX);
    final h = (maxY - minY);
    minX = (minX - 0.15 * w).clamp(0, p.image.metadata!.size.width);
    maxX = (maxX + 0.15 * w).clamp(0, p.image.metadata!.size.width);
    minY = (minY - 0.15 * h).clamp(0, p.image.metadata!.size.height);
    maxY = (maxY + 0.15 * h).clamp(0, p.image.metadata!.size.height);

    int samples = 0, bright = 0, edges = 0;
    const step = 2;
    for (int iy = minY.floor(); iy < maxY.ceil(); iy += step) {
      for (int ix = minX.floor(); ix < maxX.ceil(); ix += step) {
        final raw = _visionToRaw(ix, iy, p);
        if (raw == null) continue;
        final Y = _getLuma(raw.$1, raw.$2, p);
        if (Y == null) continue;

        final rawR = _visionToRaw(ix + 1, iy, p);
        final rawL = _visionToRaw(ix - 1, iy, p);
        final rawU = _visionToRaw(ix, iy - 1, p);
        final rawD = _visionToRaw(ix, iy + 1, p);
        final Yr = rawR != null ? _getLuma(rawR.$1, rawR.$2, p) ?? Y : Y;
        final Yl = rawL != null ? _getLuma(rawL.$1, rawL.$2, p) ?? Y : Y;
        final Yu = rawU != null ? _getLuma(rawU.$1, rawU.$2, p) ?? Y : Y;
        final Yd = rawD != null ? _getLuma(rawD.$1, rawD.$2, p) ?? Y : Y;

        final grad = (Yr - Yl).abs() + (Yd - Yu).abs();
        samples++;
        if (Y > _TEETH_BRIGHT_THR) bright++;
        if (grad > _TEETH_EDGE_THR) edges++;
      }
    }
    if (samples < 40) return 0.0;
    final brightRatio = bright / samples;
    final edgeRatio = edges / samples;
    return (0.55 * brightRatio + 0.45 * edgeRatio).clamp(0.0, 1.0);
  }

  (int, int)? _visionToRaw(int vx, int vy, InputPack p) {
    int rx, ry;
    switch (p.rotation) {
      case InputImageRotation.rotation0deg:
        rx = vx;
        ry = vy;
        break;
      case InputImageRotation.rotation90deg:
        rx = vy;
        ry = p.width - 1 - vx;
        break;
      case InputImageRotation.rotation180deg:
        rx = p.width - 1 - vx;
        ry = p.height - 1 - vy;
        break;
      case InputImageRotation.rotation270deg:
        rx = p.height - 1 - vy;
        ry = vx;
        break;
    }
    if (rx < 0 || ry < 0 || rx >= p.width || ry >= p.height) return null;
    return (rx, ry);
  }

  int? _getLuma(int rx, int ry, InputPack p) {
    if (p.isNV21) {
      final idx = ry * p.width + rx;
      if (idx < 0 || idx >= p.bytes.length) return null;
      return p.bytes[idx];
    } else {
      final stride = p.bytesPerRow;
      final base = ry * stride + rx * 4; // BGRA
      if (base + 3 >= p.bytes.length) return null;
      final b = p.bytes[base], g = p.bytes[base + 1], r = p.bytes[base + 2];
      return (0.299 * r + 0.587 * g + 0.114 * b).round();
    }
  }

  Future<void> _detectFoodNearMouth(Face f, InputPack p, Rect mouthBox) async {
    final objs = await _obj.processImage(p.image);
    _objDebug = [];
    _visBoxes = [];

    final lm = f.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rm = f.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (lm == null || rm == null) return;
    final mouth = Offset((lm.x + rm.x) / 2.0, (lm.y + rm.y) / 2.0);
    final faceW = f.boundingBox.width.toDouble();

    bool nearNow = false;

    for (final o in objs) {
      final box = o.boundingBox;
      final center = Offset(box.center.dx, box.center.dy);

      String best = '';
      double bestConf = 0.0;
      for (final l in o.labels) {
        if (l.confidence > bestConf) {
          best = l.text.trim().toLowerCase();
          bestConf = l.confidence;
        }
      }

      final iou = _iou(mouthBox, box);
      final dist = (center - mouth).distance;

      bool movingCloser = false;
      if (o.trackingId != null) {
        final prev = _lastObjCenter[o.trackingId!];
        if (prev != null) {
          final prevDist = (prev - mouth).distance;
          movingCloser = dist < prevDist - _OBJ_MOTION_DELTA;
        }
        _lastObjCenter[o.trackingId!] = center;
      }

      final labelIsFoodish = best == 'food' || best == 'home goods' || (best == 'unknown' && movingCloser);
      final isNear = (iou > _NEAR_IOU_THR) || (dist < faceW * _NEAR_DIST_SCALE);

      _objDebug.add(
          '[${o.trackingId ?? -1}] ${best.isEmpty ? "no-label" : best} ${(bestConf * 100).toStringAsFixed(0)}% '
          'd:${dist.toStringAsFixed(0)} iou:${iou.toStringAsFixed(2)} ${movingCloser ? "→mouth " : ""}${isNear ? "NEAR" : ""}');

      _visBoxes.add(DetVis(box, best.isEmpty ? 'obj' : best, bestConf, o.trackingId, isNear, iou, dist, movingCloser));

      if (labelIsFoodish && isNear) nearNow = true;
    }

    if (nearNow) _foodNearHits.add(DateTime.now());
    _foodNearHits.removeWhere((t) => DateTime.now().difference(t).inMilliseconds > _FOOD_PERSIST_MS);
  }

  Future<double?> _wristToMouthDistance(InputPack p, Face f) async {
    final lm = f.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rm = f.landmarks[FaceLandmarkType.rightMouth]?.position;
    if (lm == null || rm == null) return null;
    final mouth = Offset((lm.x + rm.x) / 2.0, (lm.y + rm.y) / 2.0);

    final poses = await _pose.processImage(p.image);
    if (poses.isEmpty) return null;

    PoseLandmark? lw = poses.first.landmarks[PoseLandmarkType.leftWrist];
    PoseLandmark? rw = poses.first.landmarks[PoseLandmarkType.rightWrist];
    if (lw == null && rw == null) return null;

    double best = double.infinity;
    if (lw != null) best = math.min(best, (Offset(lw.x, lw.y) - mouth).distance);
    if (rw != null) best = math.min(best, (Offset(rw.x, rw.y) - mouth).distance);
    return best.isFinite ? best : null;
  }

  bool _handNearHeuristic(InputPack p, Rect mouthBox) {
    int total = 0, skinish = 0;
    const step = 3;
    for (int iy = mouthBox.top.floor(); iy < mouthBox.bottom.ceil(); iy += step) {
      for (int ix = mouthBox.left.floor(); ix < mouthBox.right.ceil(); ix += step) {
        final raw = _visionToRaw(ix, iy, p);
        if (raw == null) continue;
        final y = _getLuma(raw.$1, raw.$2, p);
        if (y == null) continue;
        if (y > 120 && y < 210) skinish++;
        total++;
      }
    }
    if (total < 40) return false;
    return (skinish / total) > _HAND_MIN_PIX_RATIO;
  }

  void _updateFoodGate() {
    final now = DateTime.now();
    _foodNearHits.removeWhere((t) => now.difference(t).inMilliseconds > _FOOD_PERSIST_MS);
  }

  void _stepFsm({
    bool mouthOpen = false,
    bool chewingNow = false,
    double approachScore = 0.0,
    bool noFace = false,
    double? marSmooth,
    double? marDelta,
    bool teethGate = false,
  }) {
    final now = DateTime.now();
    _tState ??= now;
    EatState nextState = _state;

    switch (_state) {
      case EatState.idle:
        if (!noFace && approachScore > 0.50) {
          nextState = EatState.approach;
          _tState = now;
        }
        break;

      case EatState.approach:
        if (noFace) {
          nextState = EatState.idle;
          _tState = now;
          break;
        }
        if (now.difference(_tState!).inMilliseconds > _APPROACH_TIMEOUT_MS) {
          nextState = EatState.idle;
          _tState = now;
          break;
        }
        if (approachScore > 0.50) {
          if (mouthOpen && (marSmooth ?? 0.0) > _BITE_MIN_OPEN && _tLastBite == null) {
            _tLastBite = now; // arm
          }
          final armed = _tLastBite != null && now.difference(_tLastBite!).inMilliseconds <= _BITE_MAX_WINDOW_MS;
          final fastClose = (marDelta ?? 0.0) <= _BITE_DROP_DELTA;
          final fullClose = !mouthOpen;
          if (armed && (fastClose || fullClose)) {
            nextState = EatState.bite;
            _tState = now;
            _tLastBite = null;
            break;
          }
          if (_tLastBite != null && now.difference(_tLastBite!).inMilliseconds > _BITE_MAX_WINDOW_MS) {
            _tLastBite = null;
          }
        } else {
          nextState = chewingNow ? EatState.chewing : EatState.idle;
          _tState = now;
        }
        break;

      case EatState.bite:
        if (chewingNow) {
          nextState = EatState.chewing;
          _tState = now;
          break;
        }
        if (now.difference(_tState!).inMilliseconds > 400) {
          nextState = (approachScore > 0.4) ? EatState.approach : EatState.idle;
          _tState = now;
        }
        break;

      case EatState.chewing:
        if (chewingNow) {
          _tState = now;
        } else {
          nextState = EatState.grace;
          _tState = now;
        }
        break;

      case EatState.grace:
        if (chewingNow) {
          nextState = EatState.chewing;
          _tState = now;
          break;
        }
        if (now.difference(_tState!).inMilliseconds > _CHEW_GRACE_MS) {
          nextState = EatState.idle;
          _tState = now;
        }
        break;
    }

    if (_state != nextState) {
      _state = nextState;
    }
    final eatingNow = _state == EatState.chewing || _state == EatState.grace;
    _applyDecision(eatingNow, _computeConfidence(eatingNow, teethGate: teethGate));
  }

  double _computeConfidence(bool eating, {required bool teethGate}) {
    final peakDensity = (_recentPeaks.length.clamp(0, 4)) / 4.0;

    double std = 0.0;
    final vals = <double>[];
    for (final v in _marWin) {
      if (!v.isNaN) vals.add(v);
    }
    if (vals.length >= 2) {
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      double var_ = 0.0;
      for (final v in vals) {
        final d = v - mean;
        var_ += d * d;
      }
      std = math.sqrt(var_ / vals.length).clamp(0.0, 0.08) / 0.08;
    }

    final chewConf = (0.6 * peakDensity + 0.4 * std).clamp(0.0, 1.0);
    final teethConf = (teethGate ? _teethScore : 0.0).clamp(0.0, 1.0);
    final approachConf = _approachScore;

    return eating
        ? (0.55 * chewConf + 0.25 * approachConf + 0.20 * teethConf)
        : (0.55 * chewConf + 0.20 * approachConf + 0.25 * teethConf);
  }

  void _applyDecision(bool eating, double conf) {
    _confidence = conf;
    _status = eating ? 'Eating' : 'Not Eating';
    notifyListeners();
  }

  double _iou(Rect a, Rect b) {
    final inter = Rect.fromLTRB(
      math.max(a.left, b.left),
      math.max(a.top, b.top),
      math.min(a.right, b.right),
      math.min(a.bottom, b.bottom),
    );
    if (inter.width <= 0 || inter.height <= 0) return 0.0;
    final interArea = inter.width * inter.height;
    final unionArea = a.width * a.height + b.width * b.height - interArea;
    if (unionArea <= 0) return 0.0;
    return interArea / unionArea;
  }

  Offset _avgPoint(List<math.Point<int>> pts) {
    double sx = 0, sy = 0;
    for (final p in pts) {
      sx += p.x.toDouble();
      sy += p.y.toDouble();
    }
    final n = pts.length.toDouble();
    return Offset(sx / n, sy / n);
  }

  double _dist(int x1, int y1, int x2, int y2) {
    final dx = x1 - x2, dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}