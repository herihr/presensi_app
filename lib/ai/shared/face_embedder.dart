import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbedder {
  static const modelPath = 'lib/assets/mobilefacenet.tflite';

  FaceEmbedder({Uint8List? modelBytes, this.logModelInfo = true})
    : _modelBytes = modelBytes;

  final Uint8List? _modelBytes;
  final bool logModelInfo;

  Interpreter? _interpreter;
  bool _hasLoggedModelInfo = false;

  Future<List<double>> embed(dynamic face) async {
    if (face is String) {
      return embedImageFile(face);
    }

    if (face is File) {
      return embedImageFile(face.path);
    }

    if (face is img.Image) {
      return embedImage(face);
    }

    throw ArgumentError(
      'FaceEmbedder membutuhkan path foto lokal, File, atau img.Image',
    );
  }

  Future<List<double>> embedImageFile(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw StateError('File gambar tidak ditemukan: $imagePath');
    }

    final decoded = img.decodeImage(await file.readAsBytes());
    if (decoded == null) {
      throw StateError('Gagal decode gambar: $imagePath');
    }

    return embedImage(decoded);
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

  Future<img.Image> prepareInputImage(img.Image image) async {
    final interpreter = await _loadInterpreter();
    final inputShape = interpreter.getInputTensor(0).shape;
    if (inputShape.length != 4) {
      throw StateError('Input model MobileFaceNet tidak valid: $inputShape');
    }
    return img.copyResize(image, width: inputShape[2], height: inputShape[1]);
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
    if (!logModelInfo || _hasLoggedModelInfo) return;
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

  List<List<List<List<double>>>> _decodedImageToInput(
    img.Image image,
    int width,
    int height,
  ) {
    final resized = img.copyResize(image, width: width, height: height);

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

  dynamic _zeros(List<int> shape) {
    if (shape.length == 1) return List<double>.filled(shape.first, 0);
    return List.generate(shape.first, (_) => _zeros(shape.sublist(1)));
  }

  List<double> _flattenDoubles(dynamic value) {
    if (value is num) return [value.toDouble()];
    if (value is Iterable) return value.expand(_flattenDoubles).toList();
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
