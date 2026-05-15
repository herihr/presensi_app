import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbedder {
  static const modelPath = 'lib/assets/mobilefacenet.tflite';

  FaceEmbedder({Uint8List? modelBytes}) : _modelBytes = modelBytes;

  final Uint8List? _modelBytes;
  Interpreter? _interpreter;
  bool _hasLoggedModelInfo = false;

  Future<List<double>> embed(dynamic face) async {
    if (face is String) {
      return embedImageFile(face);
    }
    if (face is File) {
      return embedImageFile(face.path);
    }
    throw ArgumentError('FaceEmbedder membutuhkan path foto lokal atau File');
  }

  Future<List<double>> embedImageFile(String imagePath) async {
    final interpreter = await _loadInterpreter();
    _logModelInfo(interpreter);
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;

    if (inputShape.length != 4) {
      throw StateError('Input model MobileFaceNet tidak valid: $inputShape');
    }

    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];
    final input = await _imageToInput(imagePath, inputWidth, inputHeight);
    final output = _zeros(outputShape);

    interpreter.run(input, output);

    return _l2Normalize(_flattenDoubles(output));
  }

  Future<List<double>> embedImage(img.Image image) async {
    final interpreter = await _loadInterpreter();
    _logModelInfo(interpreter);
    final inputShape = interpreter.getInputTensor(0).shape;
    final outputShape = interpreter.getOutputTensor(0).shape;

    if (inputShape.length != 4) {
      throw StateError('Input model MobileFaceNet tidak valid: $inputShape');
    }

    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];
    final input = _decodedImageToInput(image, inputWidth, inputHeight);
    final output = _zeros(outputShape);

    interpreter.run(input, output);

    return _l2Normalize(_flattenDoubles(output));
  }

  Future<Interpreter> _loadInterpreter() async {
    final existing = _interpreter;
    if (existing != null) return existing;

    final options = InterpreterOptions()..threads = 2;
    final bytes = _modelBytes;
    final interpreter = bytes == null
        ? await Interpreter.fromAsset(modelPath, options: options)
        : Interpreter.fromBuffer(bytes, options: options);
    _interpreter = interpreter;
    return interpreter;
  }

  void _logModelInfo(Interpreter interpreter) {
    if (_hasLoggedModelInfo) return;
    _hasLoggedModelInfo = true;

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);

    debugPrint('MobileFaceNet input name: ${inputTensor.name}');
    debugPrint('MobileFaceNet input shape: ${inputTensor.shape}');
    debugPrint('MobileFaceNet input type: ${inputTensor.type}');
    debugPrint('MobileFaceNet output name: ${outputTensor.name}');
    debugPrint('MobileFaceNet output shape: ${outputTensor.shape}');
    debugPrint('MobileFaceNet output type: ${outputTensor.type}');
  }

  Future<List<List<List<List<double>>>>> _imageToInput(
    String imagePath,
    int width,
    int height,
  ) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Foto siswa tidak bisa dibaca');
    }

    return _decodedImageToInput(decoded, width, height);
  }

  List<List<List<List<double>>>> _decodedImageToInput(
    img.Image image,
    int width,
    int height,
  ) {
    final cropped = _centerCropSquare(image);
    final resized = img.copyResize(cropped, width: width, height: height);

    return [
      List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [
            (pixel.r.toDouble() - 127.5) / 128.0,
            (pixel.g.toDouble() - 127.5) / 128.0,
            (pixel.b.toDouble() - 127.5) / 128.0,
          ];
        });
      }),
    ];
  }

  img.Image _centerCropSquare(img.Image image) {
    final size = min(image.width, image.height);
    final x = ((image.width - size) / 2).round();
    final y = ((image.height - size) / 2).round();
    return img.copyCrop(image, x: x, y: y, width: size, height: size);
  }

  dynamic _zeros(List<int> shape) {
    if (shape.length == 1) {
      return List<double>.filled(shape.first, 0);
    }

    return List.generate(
      shape.first,
      (_) => _zeros(shape.sublist(1)),
    );
  }

  List<double> _flattenDoubles(dynamic value) {
    if (value is num) return [value.toDouble()];
    if (value is Iterable) {
      return value.expand(_flattenDoubles).toList();
    }
    return const [];
  }

  List<double> _l2Normalize(List<double> vector) {
    final norm = sqrt(vector.fold<double>(0, (sum, item) => sum + item * item));
    if (norm == 0) return vector;
    return vector.map((item) => item / norm).toList();
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
