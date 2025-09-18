import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ChewingDetectionService {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      final modelData = await rootBundle.load('assets/models/movinet_a0_stream_int.tflite');
      _interpreter = Interpreter.create(
        modelData.buffer.asUint8List(),
        options: options,
      );
      _isInitialized = true;
    } catch (e) {
      print("Failed to load TFLite model: $e");
    }
  }

  // This is a placeholder. Actual implementation would require converting
  // the CameraImage to the model's expected input format (e.g., resizing, normalization).
  Uint8List _preprocessImage(dynamic image) {
    // Placeholder: returns a dummy tensor of the correct shape and type.
    return Uint8List(1 * 1 * 172 * 172 * 3);
  }

  bool isChewing(dynamic image) {
    if (!_isInitialized) {
      print("Interpreter not initialized, cannot run inference.");
      return false;
    }

    final preprocessedImage = _preprocessImage(image);

    // The output is a tensor with shape [1, 600] representing probabilities for 600 classes.
    var output = List.filled(1 * 600, 0.0).reshape([1, 600]);
    _interpreter.run(preprocessedImage, output);

    // Placeholder: This logic would need to be replaced with actual post-processing.
    // For example, finding the index with the highest probability and checking if it corresponds
    // to a "chewing" class from the labels file.
    // For now, let's pretend it detects chewing 50% of the time.
    return output[0].first > 0.5;
  }

  void close() {
    if (_isInitialized) {
      _interpreter.close();
    }
  }
}
