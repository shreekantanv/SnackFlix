import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SnackFlixChewPOC()));

class SnackFlixChewPOC extends StatefulWidget {
  const SnackFlixChewPOC({super.key});
  @override
  State<SnackFlixChewPOC> createState() => _SnackFlixChewPOCState();
}

class _SnackFlixChewPOCState extends State<SnackFlixChewPOC> with WidgetsBindingObserver {
  // Video
  YoutubePlayerController? _yt;

  // Camera
  CameraController? _cam;
  bool _camReady = false;

  // Face detector (contours!)
  late final FaceDetector _faces = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
    ),
  );

  // Throttle
  int _frameSkip = 0;
  final int _frameStride = 2; // process every 2nd frame (~15 fps -> ~7.5 effective)

  // MAR series (chewing detector)
  final List<double> _marWin = <double>[];
  final List<DateTime> _tsWin = <DateTime>[];
  final int _winMax = 60; // ~4s if 15fps/2

  // Peaks
  DateTime? _lastPeak;
  final List<DateTime> _recentPeaks = <DateTime>[]; // rolling timestamps

  // UI
  String _status = 'Not Eating';
  double _confidence = 0.0;
  bool _isDetecting = false;
  Timer? _pauseDwell;

  // Stats (optional)
  int _frames = 0;
  int _chewFrames = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initYT();
    _initCam();
  }

  void _initYT() {
    _yt = YoutubePlayerController.fromVideoId(
      videoId: 'M-wjK4p_g_s',
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
      ),
    );
  }

  Future<void> _initCam() async {
    final ok = await Permission.camera.request();
    if (!ok.isGranted) {
      _toast('Camera permission required');
      return;
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      _toast('No camera available');
      return;
    }
    final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    _cam = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420 // <— instead of nv21
          : ImageFormatGroup.bgra8888,
    );
    await _cam!.initialize();
    if (!mounted) return;
    setState(() => _camReady = true);

    _cam!.startImageStream((img) {
      _frameSkip++;
      if (_frameSkip % _frameStride != 0) return;
      if (_isDetecting) return;
      _isDetecting = true;
      _onFrame(img).whenComplete(() => _isDetecting = false);
    });
  }

  Future<void> _onFrame(CameraImage img) async {
    try {
      final input = _toInput(img);
      if (input == null) return;

      final faces = await _faces.processImage(input);
      if (faces.isEmpty) {
        _pushMar(null);
        _decide();
        return;
      }

      // Take largest face (kid)
      faces.sort((a, b) => b.boundingBox.width.compareTo(a.boundingBox.width));
      final f = faces.first;

      // Compute MAR (mouth aspect ratio)
      final mar = _computeMAR(f);
      _pushMar(mar);

      // Decide chewing vs not
      _decide();
    } catch (_) {
      // per-frame errors ignored
    }
  }

  // ---------- InputImage (NV21/BGRA) ----------
  InputImage? _toInput(CameraImage image) {
    final rot = InputImageRotationValue.fromRawValue(_cam!.description.sensorOrientation);
    if (rot == null) return null;

    if (Platform.isAndroid) {
      // Accept either NV21 (1 plane) or YUV420 (3 planes) and convert to NV21 bytes.
      Uint8List nv21Bytes;

      if (image.format.group == ImageFormatGroup.nv21 && image.planes.length == 1) {
        nv21Bytes = image.planes[0].bytes; // ready to go
      } else if (image.format.group == ImageFormatGroup.yuv420 && image.planes.length == 3) {
        nv21Bytes = _yuv420ToNv21(image);  // pack into NV21
      } else {
        // Some devices still report YUV420 with 2 planes; try to convert anyway
        if (image.planes.length == 3) {
          nv21Bytes = _yuv420ToNv21(image);
        } else {
          return null; // unsupported layout
        }
      }

      return InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rot,
          format: InputImageFormat.nv21,          // tell ML Kit we’re providing NV21
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // iOS: BGRA8888 plane[0]
      if (image.format.group != ImageFormatGroup.bgra8888 || image.planes.length != 1) return null;
      final p0 = image.planes[0];
      return InputImage.fromBytes(
        bytes: p0.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rot,
          format: InputImageFormat.bgra8888,
          bytesPerRow: p0.bytesPerRow,
        ),
      );
    }
  }

  Uint8List _yuv420ToNv21(CameraImage img) {
    // NV21 = Y full plane + interleaved VU at quarter res
    final w = img.width, h = img.height;
    final yPlane = img.planes[0];
    final uPlane = img.planes[1];
    final vPlane = img.planes[2];

    final out = Uint8List(w * h + (w * h) ~/ 2);
    // Copy Y (row by row to respect bytesPerRow)
    int di = 0;
    for (int r = 0; r < h; r++) {
      final srcOff = r * yPlane.bytesPerRow;
      out.setRange(di, di + w, yPlane.bytes.sublist(srcOff, srcOff + w));
      di += w;
    }

    // Interleave VU for chroma (quarter res). Respect strides.
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
        out[di++] = v; // V first
        out[di++] = u; // then U  => NV21 (VU)
      }
    }
    return out;
  }

  // ---------- MAR & Chewing ----------
  // MAR = vertical gap between inner lips / mouth width
  double? _computeMAR(Face f) {
    // Prefer contours
    final upperIn = f.contours[FaceContourType.upperLipBottom]?.points;
    final lowerIn = f.contours[FaceContourType.lowerLipTop]?.points;
    final up = upperIn?.isNotEmpty == true ? _avgPoint(upperIn!) : null;
    final lo = lowerIn?.isNotEmpty == true ? _avgPoint(lowerIn!) : null;

    // Mouth width from corners (landmarks) or contour extremes
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
        final ys = allLip.map((e) => e.dy).toList()..sort();
        width = xs.last - xs.first;
        // vertical gap fallback if needed
        if (up == null || lo == null) {
          final midYTop = ys[(ys.length * 0.45).floor()];
          final midYBot = ys[(ys.length * 0.55).floor()];
          final gap = (midYBot - midYTop).abs();
          return (width <= 1) ? null : (gap / width);
        }
      }
    }

    if (up == null || lo == null || width == null || width <= 1) return null;
    final gap = (lo.dy - up.dy).abs(); // inner-lip vertical gap
    return gap / width;
  }

  Offset _avgPoint(List<math.Point<int>> pts) {
    double sx = 0, sy = 0;
    for (final p in pts) { sx += p.x.toDouble(); sy += p.y.toDouble(); }
    final n = pts.length.toDouble();
    return Offset(sx / n, sy / n);
  }

  double _dist(int x1, int y1, int x2, int y2) {
    final dx = x1 - x2, dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _pushMar(double? mar) {
    _frames++;
    if (mar == null) {
      _marWin.add(double.nan);
      _tsWin.add(DateTime.now());
    } else {
      _marWin.add(mar);
      _tsWin.add(DateTime.now());
    }
    if (_marWin.length > _winMax) {
      _marWin.removeAt(0);
      _tsWin.removeAt(0);
    }
  }

  void _decide() {
    if (_marWin.isEmpty) return;

    // Clean window: drop NaNs when computing stats
    final vals = <double>[];
    for (final v in _marWin) { if (!v.isNaN) vals.add(v); }
    if (vals.length < 8) { _applyDecision(false, 0.0); return; }

    // Rolling mean & std
    final mean = vals.reduce((a, b) => a + b) / vals.length;

    double variance = 0.0;
    for (final v in vals) {
      final d = v - mean;
      variance += d * d;
    }
    final std = math.sqrt(variance / vals.length);

    // Peak detection (simple, hysteresis on dynamic threshold)
    final now = DateTime.now();
    final thr = mean + math.max(0.03, 0.5 * std); // adaptive
    final last = vals.last;
    final prev = vals[vals.length - 2];

    final minGap = const Duration(milliseconds: 300);
    final maxGap = const Duration(milliseconds: 1600);
    final lastPeakOk = _lastPeak == null || now.difference(_lastPeak!) >= minGap;

    if (prev <= thr && last > thr && lastPeakOk) {
    // rising edge over threshold -> candidate peak
    _lastPeak = now;
    _recentPeaks.add(now);
    // purge old peaks (>4s)
    _recentPeaks.removeWhere((t) => now.difference(t).inMilliseconds > 4000);
    }

    // Count peaks in the last 3.5s and check inter-peak gaps ~ chew rate
    int validPeaks = 0;
    for (int i = 1; i < _recentPeaks.length; i++) {
    final gap = _recentPeaks[i].difference(_recentPeaks[i - 1]);
    if (gap >= minGap && gap <= maxGap) validPeaks++;
    }

    final chewing = (validPeaks >= 2) && (std > 0.02); // simple rule
    if (chewing) _chewFrames++;

    // Confidence: blend normalized std & peak density
    final peakDensity = (_recentPeaks.length.clamp(0, 4)) / 4.0;
    final conf = (peakDensity * 0.6 + (std.clamp(0.0, 0.08) / 0.08) * 0.4).clamp(0.0, 1.0);

    _applyDecision(chewing, conf);
    }

  void _applyDecision(bool chewing, double conf) {
    setState(() {
      _confidence = conf;
      _status = chewing ? 'Eating (chewing)' : 'Not Eating';
    });

    if (chewing) {
      _pauseDwell?.cancel();
      _pauseDwell = null;
      if (_yt != null && _yt!.value.playerState != PlayerState.playing) {
        _yt!.playVideo();
      }
    } else {
      // small dwell to avoid flicker pauses
      _pauseDwell ??= Timer(const Duration(seconds: 2), () {
        if (_yt != null && _yt!.value.playerState == PlayerState.playing) {
          _yt!.pauseVideo();
        }
      });
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cam == null || !_camReady) return;
    if (state == AppLifecycleState.inactive) {
      _cam!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCam();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try { _cam?.stopImageStream(); } catch (_) {}
    _cam?.dispose();
    _faces.close();
    _yt?.close();
    _pauseDwell?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eating = _status.startsWith('Eating');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SnackFlix (Chewing Detector)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (eating ? Colors.green : Colors.red).withOpacity(.15),
              border: Border.all(color: eating ? Colors.green : Colors.red),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _status,
              style: TextStyle(
                color: eating ? Colors.green : Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_yt != null)
            YoutubePlayerScaffold(
              controller: _yt!,
              builder: (context, player) => Center(child: player),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Camera preview tile
          Positioned(
            top: 16, right: 16,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: eating ? Colors.green : Colors.red, width: 3),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 128, height: 168,
                  child: (_cam != null && _camReady)
                      ? CameraPreview(_cam!)
                      : const ColoredBox(color: Colors.black12),
                ),
              ),
            ),
          ),

          // Confidence chip
          Positioned(
            top: 192, right: 16, width: 128,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: (eating ? Colors.green : Colors.red).withOpacity(.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Conf: ${(_confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _confidence,
                    backgroundColor: Colors.white30,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ),

          // Optional stats
          Positioned(
            left: 16, bottom: 16,
            child: Opacity(
              opacity: .85,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Stats', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Frames: $_frames'),
                      Text('Chew%: ${_frames == 0 ? 0 : (_chewFrames / _frames * 100).toStringAsFixed(1)}'),
                      Text('Peaks (4s): ${_recentPeaks.length}'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
