import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MoviNetEatingAnyModelDemo()));
}

class MoviNetEatingAnyModelDemo extends StatefulWidget {
  const MoviNetEatingAnyModelDemo({super.key});
  @override
  State<MoviNetEatingAnyModelDemo> createState() => _MoviNetEatingAnyModelDemoState();
}

class _MoviNetEatingAnyModelDemoState extends State<MoviNetEatingAnyModelDemo> {
  // Model nominal input size for A0
  static const int targetW = 172, targetH = 172;
  static const double targetFps = 2.0;

  bool _streamActive = false;
  // Camera
  CameraController? _cam;
  bool _initializing = true;
  String? _error;
  bool _busy = false;
  DateTime _lastInfer = DateTime.fromMillisecondsSinceEpoch(0);

  // TFLite
  tfl.Interpreter? _itp;

  // Video input (ordinal + rank + dtype string)
  int _videoInOrd = -1;        // position in getInputTensors()
  int _videoInRank = 0;        // 4 or 5
  late String _videoInKind;    // "float32" | "int8" | "uint8"

  // Logits output
  int _logitsOutOrd = -1;
  late String _logitsOutKind;  // type of logits tensor

  // States (optional): input-ordinal -> output-ordinal
  final Map<int, int> _stateInToOut = {};
  final Map<int, String> _stateInKind = {};
  final Map<int, String> _stateOutKind = {};
  final Map<int, Object> _stateInputs = {};   // typed buffers
  final Map<int, Object> _stateScratch = {};  // typed buffers

  // Labels + UI
  List<String> _labels = [];
  List<MapEntry<String,double>> _top = const [];
  double _eatingScore = 0.0;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      final perm = await Permission.camera.request();
      if (!perm.isGranted) { setState(() { _error = 'Camera permission denied'; _initializing=false; }); return; }
      _labels = (await rootBundle.loadString('assets/labels/kinetics_600_labels.txt'))
          .split('\n').map((s)=>s.trim()).where((s)=>s.isNotEmpty).toList();

      await _loadModelAnySignature();

      final cams = await availableCameras();
      if (cams.isEmpty) { setState(() { _error = 'No camera (simulator?)'; _initializing=false; }); return; }
      final front = cams.firstWhere((c)=>c.lensDirection==CameraLensDirection.front, orElse: ()=>cams.first);
      _cam = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
      );
      await _cam!.initialize();

      await _startStream();
      await _cam!.startImageStream(_onFrame);
      setState(()=>_initializing=false);
    } catch (e) {
      setState(() { _error = 'Init error: $e'; _initializing=false; });
    }
  }

  Future<void> _startStream() async {
    if (!mounted || _cam == null || _streamActive) return;
    _streamActive = true;
    await _cam!.startImageStream(_onFrame);
  }

  Future<void> _stopStream() async {
    if (!_streamActive || _cam == null) return;
    _streamActive = false;
    try { await _cam!.stopImageStream(); } catch (_) {}
  }

  // ---------- Model load (supports 4-D or 5-D; int8/uint8/float32; optional states) ----------
  String _kindOf(Object tEnum) {
    final s = tEnum.toString(); // "TfLiteType.float32" or "TensorType.uint8"
    final dot = s.lastIndexOf('.');
    return (dot>=0 ? s.substring(dot+1) : s).toLowerCase();
  }
  bool _isFloat(String k)=>k.contains('float');
  bool _isInt8(String k)=>k=='int8';
  bool _isUint8(String k)=>k=='uint8';

  Future<void> _loadModelAnySignature() async {
    _itp = await tfl.Interpreter.fromAsset(
      'assets/models/movinet_a0_stream_int.tflite',
      options: tfl.InterpreterOptions()..threads=2,
    );

    final ins  = _itp!.getInputTensors();
    final outs = _itp!.getOutputTensors();

    // --- pick video input: prefer rank-5 [1,1,H,W,3], else rank-4 [1,H,W,3] (channels-last) ---
    _videoInOrd = -1; _videoInRank = 0; _videoInKind = 'float32';
    for (int i=0;i<ins.length;i++) {
      final s = ins[i].shape;
      if (s.isNotEmpty && s.last==3 && (s.length==5 || s.length==4)) {
        if (_videoInOrd==-1 || s.length>_videoInRank) { _videoInOrd=i; _videoInRank=s.length; }
      }
    }
    if (_videoInOrd<0) {
      // Dump shapes to console to help debugging
      for (int i=0;i<ins.length;i++){ debugPrint('IN[$i] ${ins[i].name} shape=${ins[i].shape} type=${ins[i].type}'); }
      for (int j=0;j<outs.length;j++){ debugPrint('OUT[$j] ${outs[j].name} shape=${outs[j].shape} type=${outs[j].type}'); }
      throw StateError('Could not find 4-D/5-D channels-last video input (C==3).');
    }
    _videoInKind = _kindOf(ins[_videoInOrd].type);

    // --- pick logits output: prefer name with "logit"/"classifier"; else rank-2 with largest C; else largest rank-1 ---
    _logitsOutOrd = 0;
    int bestC = 0; int bestRank = 0;
    for (int j=0;j<outs.length;j++) {
      final n = (outs[j].name).toLowerCase();
      if (n.contains('logit') || n.contains('classifier')) { _logitsOutOrd=j; break; }
      final s = outs[j].shape;
      if ((s.length==2 && s.last>=bestC) || (s.length==1 && bestRank<2)) {
        bestC = s.last; bestRank = s.length; _logitsOutOrd=j;
      }
    }
    _logitsOutKind = _kindOf(outs[_logitsOutOrd].type);

    // --- set video shape and allocate once so state shapes materialize ---
    if (_videoInRank==5) {
      _itp!.resizeInputTensor(_videoInOrd, [1,1,targetH,targetW,3]);
    } else { // rank-4
      _itp!.resizeInputTensor(_videoInOrd, [1,targetH,targetW,3]);
    }
    _itp!.allocateTensors();

    // --- pair states by normalized name; fallback by size. If none, it's a non-stream model. ---
    String norm(String s)=>s.toLowerCase()
        .replaceAll(RegExp(r'serving_default[:/]*'),'')
        .replaceAll(RegExp(r'statefulpartitionedcall[:/]*'),'')
        .replaceAll(RegExp(r'call[:/]*'),'')
        .replaceAll(RegExp(r'init_states[:/]*'),'')
        .replaceAll(RegExp(r'init[:_/]*'),'')
        .replaceAll(RegExp(r'state[:_/]*'),'state_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'),'_')
        .replaceAll(RegExp(r'_+'),'_')
        .trim();

    final inByName=<String,int>{}, outByName=<String,int>{};
    for (int i=0;i<ins.length;i++) {
      if (i==_videoInOrd) continue;
      final k = norm(ins[i].name);
      if (k.startsWith('state_')) inByName[k]=i;
    }
    for (int j=0;j<outs.length;j++) {
      if (j==_logitsOutOrd) continue;
      final k = norm(outs[j].name);
      if (k.startsWith('state_')) outByName[k]=j;
    }

    _stateInToOut.clear(); _stateInKind.clear(); _stateOutKind.clear();
    final usedOut=<int>{};
    inByName.forEach((k,iOrd){ final oOrd=outByName[k]; if (oOrd!=null){ _stateInToOut[iOrd]=oOrd; usedOut.add(oOrd); } });

    int numElems(List<int> s)=>s.fold<int>(1,(a,b)=>a*(b<0?1:b));
    final remainingIns = List<int>.generate(ins.length,(i)=>i)
        .where((i)=>i!=_videoInOrd && !_stateInToOut.containsKey(i)).toList();
    final remainingOuts = List<int>.generate(outs.length,(j)=>j)
        .where((j)=>j!=_logitsOutOrd && !usedOut.contains(j)).toList();

    for (final iOrd in remainingIns) {
      final want=numElems(ins[iOrd].shape);
      final idx=remainingOuts.indexWhere((j)=>numElems(outs[j].shape)==want);
      if (idx>=0){ final oOrd=remainingOuts.removeAt(idx); _stateInToOut[iOrd]=oOrd; usedOut.add(oOrd); }
    }

    // resize state inputs to output shapes; remember kinds; allocate again
    _stateInputs.clear(); _stateScratch.clear();
    _stateInToOut.forEach((iOrd,oOrd){
      _itp!.resizeInputTensor(iOrd, outs[oOrd].shape);
    });
    _itp!.allocateTensors();
    _stateInToOut.forEach((iOrd,oOrd){
      _stateInKind[iOrd]=_kindOf(ins[iOrd].type);
      _stateOutKind[oOrd]=_kindOf(outs[oOrd].type);
      final inLen = numElems(ins[iOrd].shape);
      final outLen= numElems(outs[oOrd].shape);
      _stateInputs[iOrd]=_zerosForKind(_stateInKind[iOrd]!, inLen);
      _stateScratch[oOrd]=_zerosForKind(_stateOutKind[oOrd]!, outLen);
    });

    // Optional: print shapes to log for sanity
    // for (int i=0;i<ins.length;i++){ debugPrint('IN[$i] ${ins[i].name} ${ins[i].shape} ${ins[i].type}'); }
    // for (int j=0;j<outs.length;j++){ debugPrint('OUT[$j] ${outs[j].name} ${outs[j].shape} ${outs[j].type}'); }
  }

  Object _zerosForKind(String k, int len){
    if (_isFloat(k)) return Float32List(len);
    if (_isInt8(k))  return Int8List(len);
    if (_isUint8(k)) return Uint8List(len);
    return Float32List(len);
  }

  // ---------- Camera loop ----------
  Future<void> _onFrame(CameraImage img) async {
    // Pause to avoid piling up buffers
    await _stopStream();

    final now = DateTime.now();
    if (_busy || now.difference(_lastInfer).inMilliseconds < (1000/targetFps)) return;
    if (_itp==null || _videoInOrd<0) return;
    _busy = true; _lastInfer = now;
    await Future.microtask((){}); // help ImageReader recycle

    try {
      final rgb = _toRGB(img);
      final side = math.min(img.width, img.height);
      final square = _centerCropSquare(rgb, img.width, img.height, side);
      final resized = _resizeBilinear(square, side, side, targetW, targetH);

      // Flatten video buffer according to dtype; for rank-5 we still just send flat (1*1*H*W*3)
      final n = targetW*targetH*3;
      late Object videoBuf;
      if (_isInt8(_videoInKind)) {
        final out = Int8List(n);
        for (int i=0;i<n;i++) out[i]=(resized[i]-128).clamp(-128,127);
        videoBuf = out;
      } else if (_isUint8(_videoInKind)) {
        final out = Uint8List(n)..setAll(0,resized);
        videoBuf = out;
      } else {
        final out = Float32List(n);
        for (int i=0;i<n;i++) out[i]=resized[i]/255.0;
        videoBuf = out;
      }

      // Build inputs by ordinal
      final ins = _itp!.getInputTensors();
      final inputs = List<Object>.filled(ins.length, []);
      inputs[_videoInOrd] = videoBuf;
      _stateInputs.forEach((iOrd,buf){ inputs[iOrd]=buf; });

      // Prepare outputs (logits + states) by ordinal
      final outs = _itp!.getOutputTensors();
      final outputs = <int,Object>{};

      final outShape = outs[_logitsOutOrd].shape;
      final rank = outShape.length;
      final classes = outShape.last;
      // Allocate logits container in native dtype
      if (rank==1) {
        outputs[_logitsOutOrd] = _zerosForKind(_logitsOutKind, classes);
      } else { // [1, C]
        if (_isInt8(_logitsOutKind)) {
          outputs[_logitsOutOrd] = [Int8List(classes)];
        } else if (_isUint8(_logitsOutKind)) {
          outputs[_logitsOutOrd] = [Uint8List(classes)];
        } else {
          outputs[_logitsOutOrd] = [List<double>.filled(classes, 0.0)];
        }
      }
      _stateScratch.forEach((oOrd,buf){ outputs[oOrd]=buf; });

      // Inference
      _itp!.runForMultipleInputs(inputs, outputs);

      // Copy states back
      _stateInputs.forEach((iOrd,_){
        final oOrd = _stateInToOut[iOrd]!;
        _copyBuf(_stateInputs[iOrd]!, _stateScratch[oOrd]!);
      });

      // Extract logits to float for softmax
      late Float32List logits;
      if (rank==1) {
        logits = _asFloat1D(outputs[_logitsOutOrd]!, _logitsOutKind);
      } else {
        final obj = outputs[_logitsOutOrd]!;
        if (_isInt8(_logitsOutKind)) {
          logits = _asFloat1D((obj as List)[0] as Int8List, _logitsOutKind);
        } else if (_isUint8(_logitsOutKind)) {
          logits = _asFloat1D((obj as List)[0] as Uint8List, _logitsOutKind);
        } else {
          logits = _asFloat1D(Float32List.fromList(List<double>.from((obj as List)[0])), 'float32');
        }
      }

      final probs = _softmax(logits);
      final pairs = <MapEntry<String,double>>[];
      for (int i=0;i<probs.length && i<_labels.length;i++){
        pairs.add(MapEntry(_labels[i], probs[i]));
      }
      pairs.sort((a,b)=>b.value.compareTo(a.value));
      final top = pairs.take(5).toList();

      double eat=0.0;
      for (final kv in top) {
        final n = kv.key.toLowerCase();
        if (n.startsWith('eating ') || n.contains('eat') || n.contains('chew') || n.contains('drink')) eat += kv.value;
      }

      setState((){ _top=top; _eatingScore=eat.clamp(0.0,1.0); });
    } catch (e) {
      setState(()=>_error='Init/Run error: $e');
    } finally {
      _busy=false;
    }
  }

  // ---------- typed helpers ----------
  void _copyBuf(Object dst, Object src){
    if (dst is Float32List && src is Float32List) { dst.setAll(0, src); return; }
    if (dst is Int8List && src is Int8List) { dst.setAll(0, src); return; }
    if (dst is Uint8List && src is Uint8List) { dst.setAll(0, src); return; }
    final db=_bytesOf(dst), sb=_bytesOf(src); db.setAll(0,sb);
  }
  Uint8List _bytesOf(Object o){
    if (o is Uint8List) return o;
    if (o is Int8List)  return Uint8List.fromList(o);
    if (o is Float32List){
      final bb=BytesBuilder();
      for (final v in o){ final b=ByteData(4)..setFloat32(0,v,Endian.little); bb.add(b.buffer.asUint8List()); }
      return bb.toBytes();
    }
    return Uint8List(0);
  }
  Float32List _asFloat1D(Object buf, String kind){
    if (_isInt8(kind))  { final b=buf as Int8List;  final o=Float32List(b.length); for(int i=0;i<b.length;i++) o[i]=b[i].toDouble(); return o; }
    if (_isUint8(kind)) { final b=buf as Uint8List; final o=Float32List(b.length); for(int i=0;i<b.length;i++) o[i]=(b[i]-128).toDouble(); return o; }
    return (buf is Float32List) ? buf : Float32List.fromList((buf as List).cast<double>());
  }

  // ---------- image utils ----------
  Uint8List _toRGB(CameraImage img){
    if (Platform.isIOS && img.format.group==ImageFormatGroup.bgra8888){
      final p=img.planes[0].bytes; final out=Uint8List(img.width*img.height*3);
      int si=0, di=0;
      for (int i=0;i<img.width*img.height;i++){
        final b=p[si], g=p[si+1], r=p[si+2];
        out[di]=r; out[di+1]=g; out[di+2]=b; si+=4; di+=3;
      }
      return out;
    } else {
      return _yuv420toRgb(img);
    }
  }
  Uint8List _yuv420toRgb(CameraImage img){
    final w=img.width, h=img.height;
    final yPlane=img.planes[0], uPlane=img.planes[1], vPlane=img.planes[2];
    final out=Uint8List(w*h*3);
    final yRow=yPlane.bytesPerRow, uvRow=uPlane.bytesPerRow, uvPix=uPlane.bytesPerPixel ?? 1;
    int di=0;
    for(int y=0;y<h;y++){
      final yi=y*yRow, ui=(y~/2)*uvRow;
      for(int x=0;x<w;x++){
        final yp=yi+x, uvp=ui+(x~/2)*uvPix;
        final Y=yPlane.bytes[yp]&0xFF, U=uPlane.bytes[uvp]&0xFF, V=vPlane.bytes[uvp]&0xFF;
        int C=Y-16; if (C<0) C=0; final D=U-128, E=V-128;
        int r=(298*C + 409*E + 128)>>8, g=(298*C - 100*D - 208*E + 128)>>8, b=(298*C + 516*D + 128)>>8;
        r=r.clamp(0,255); g=g.clamp(0,255); b=b.clamp(0,255);
        out[di++]=r; out[di++]=g; out[di++]=b;
      }
    }
    return out;
  }
  Uint8List _centerCropSquare(Uint8List rgb, int w, int h, int side){
    final x0=(w-side)~/2, y0=(h-side)~/2; final out=Uint8List(side*side*3); int di=0;
    for (int y=0;y<side;y++){
      final sy=y0+y;
      for (int x=0;x<side;x++){
        final sx=x0+x; final si=(sy*w+sx)*3;
        out[di++]=rgb[si]; out[di++]=rgb[si+1]; out[di++]=rgb[si+2];
      }
    }
    return out;
  }
  Uint8List _resizeBilinear(Uint8List src, int srcW, int srcH, int dstW, int dstH){
    final out=Uint8List(dstW*dstH*3);
    final xRatio=(srcW-1)/dstW, yRatio=(srcH-1)/dstH;
    int di=0;
    for (int y=0;y<dstH;y++){
      final sy=yRatio*y, yL=sy.floor(), yH=math.min(yL+1,srcH-1), yW=sy-yL;
      for (int x=0;x<dstW;x++){
        final sx=xRatio*x, xL=sx.floor(), xH=math.min(xL+1,srcW-1), xW=sx-xL;
        final i00=(yL*srcW + xL)*3, i01=(yL*srcW + xH)*3, i10=(yH*srcW + xL)*3, i11=(yH*srcW + xH)*3;
        for (int c=0;c<3;c++){
          final v00=src[i00+c], v01=src[i01+c], v10=src[i10+c], v11=src[i11+c];
          final v0=v00 + (v01-v00)*xW, v1=v10 + (v11-v10)*xW, v=v0 + (v1-v0)*yW;
          out[di++]=v.round().clamp(0,255);
        }
      }
    }
    return out;
  }
  Float32List _softmax(Float32List x){
    double m=-1e30; for(final v in x){ if(v>m) m=v; }
    double sum=0; final out=Float32List(x.length);
    for (int i=0;i<x.length;i++){ final e=math.exp((x[i]-m).toDouble()); out[i]=e.toDouble(); sum+=e; }
    final inv=sum==0?1.0:1.0/sum; for(int i=0;i<out.length;i++) out[i]=(out[i]*inv).toDouble(); return out;
  }

  @override
  void dispose() {
    try { _cam?.stopImageStream(); } catch (_) {}
    _cam?.dispose();
    _itp?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eating = _eatingScore > 0.30;
    final color = eating ? Colors.greenAccent : Colors.orangeAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MoViNet Eating • Any TFLite'),
        actions: [
          TextButton(onPressed: _resetStates, child: const Text('Reset', style: TextStyle(color: Colors.white70))),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: color.withOpacity(.15), border: Border.all(color: color), borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: Text('Eating: ${eating ? "YES" : "NO"} (${_eatingScore.toStringAsFixed(2)})', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : (_error!=null)
          ? Center(child: Padding(padding: const EdgeInsets.all(18), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
          : Column(children: [
        Expanded(child: Center(child: AspectRatio(
          aspectRatio: 3/4,
          child: _cam!=null && _cam!.value.isInitialized
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(fit: StackFit.expand, children: [
            CameraPreview(_cam!),
            Positioned(left:8,right:8,bottom:8, child: _hud()),
          ]))
              : const Center(child: Text('Camera unavailable', style: TextStyle(color: Colors.white70))),
        ))),
        _legend(),
      ]),
    );
  }

  void _resetStates(){
    for (final e in _stateInputs.entries){
      final b=e.value;
      if (b is Float32List){ for (int i=0;i<b.length;i++) b[i]=0.0; }
      else if (b is Int8List){ for (int i=0;i<b.length;i++) b[i]=0; }
      else if (b is Uint8List){ for (int i=0;i<b.length;i++) b[i]=0; }
    }
  }

  Widget _hud(){
    return Container(
      padding: const EdgeInsets.symmetric(vertical:8,horizontal:10),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Top-5 actions'),
          const SizedBox(height:4),
          for (final kv in _top) Text('${kv.key}  •  ${(kv.value*100).toStringAsFixed(1)}%'),
        ],
      )),
    );
  }

  Widget _legend(){
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(color: Color(0xFF111215), border: Border(top: BorderSide(color: Colors.white10))),
      child: const Text(
        'Supports 4-D or 5-D inputs (HWC), INT8/UINT8/FLOAT.\n'
            'Tip: good light; keep upper body + hand in frame.\n'
            '"Eating" is derived from Kinetics labels (eating/chew/drink).',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
