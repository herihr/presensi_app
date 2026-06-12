import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../utils/constants.dart';
import 'face_detection_models.dart';

class ServerYoloDetector {
  const ServerYoloDetector({
    this.confidenceThreshold = 0.50,
    this.iouThreshold = 0.60,
    this.faceCropPaddingRatio = 0.25,
    this.timeout = const Duration(seconds: 8),
  });

  final double confidenceThreshold;
  final double iouThreshold;
  final double faceCropPaddingRatio;
  final Duration timeout;

  Future<void> load() async {}

  Future<List<YoloDetectedFace>> detectImage(img.Image image) async {
    final jpegBytes = img.encodeJpg(image, quality: 85);
    final response = await _sendWithFallback(jpegBytes);
    final body = _tryDecodeJson(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = body is Map ? body['detail'] : response.body;
      throw Exception('YOLO server gagal: ${detail ?? response.reasonPhrase}');
    }
    if (body is! Map) return const [];

    final rawBoxes = body['boxes'];
    if (rawBoxes is! List) return const [];

    return rawBoxes
        .whereType<Map>()
        .map((item) => _faceFromMap(image, Map<String, dynamic>.from(item)))
        .whereType<YoloDetectedFace>()
        .toList();
  }

  void close() {}

  Future<http.Response> _sendWithFallback(List<int> jpegBytes) async {
    Object? lastError;
    http.Response? lastResponse;

    for (final baseUrl in _candidateBaseUrls()) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/api/ai/detect-faces'),
        );
        request.fields['confidence_threshold'] = confidenceThreshold.toString();
        request.fields['iou_threshold'] = iouThreshold.toString();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            jpegBytes,
            filename: 'frame.jpg',
          ),
        );

        final streamed = await request.send().timeout(timeout);
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 404 || response.statusCode == 503) {
          lastResponse = response;
          continue;
        }
        return response;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } on HandshakeException catch (error) {
        lastError = error;
      }
    }

    if (lastResponse != null) return lastResponse;
    throw Exception('Tidak bisa terhubung ke YOLO server: $lastError');
  }

  List<String> _candidateBaseUrls() {
    if (!Constants.enableBackendFallback) return [Constants.baseUrl];
    return Constants.fallbackBaseUrls.toSet().toList();
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  YoloDetectedFace? _faceFromMap(img.Image image, Map<String, dynamic> map) {
    final left = (map['left'] as num?)?.toDouble();
    final top = (map['top'] as num?)?.toDouble();
    final width = (map['width'] as num?)?.toDouble();
    final height = (map['height'] as num?)?.toDouble();
    final confidence = (map['confidence'] as num?)?.toDouble();
    if (left == null ||
        top == null ||
        width == null ||
        height == null ||
        confidence == null) {
      return null;
    }

    final box = YoloFaceBox(
      left: left,
      top: top,
      width: width,
      height: height,
      confidence: confidence,
    );
    final croppedFace = _cropFace(image, box);
    return YoloDetectedFace(
      x: left.round(),
      y: top.round(),
      width: width.round(),
      height: height.round(),
      confidence: confidence,
      croppedFace: croppedFace,
      box: box,
    );
  }

  img.Image _cropFace(img.Image image, YoloFaceBox box) {
    final centerX = box.left + box.width / 2;
    final centerY = box.top + box.height / 2;
    final paddedSize = box.width > box.height ? box.width : box.height;
    final halfSize = paddedSize * (1 + faceCropPaddingRatio) / 2;

    final left = (centerX - halfSize).clamp(0, image.width - 1).toDouble();
    final top = (centerY - halfSize).clamp(0, image.height - 1).toDouble();
    final right = (centerX + halfSize).clamp(left + 1, image.width).toDouble();
    final bottom = (centerY + halfSize).clamp(top + 1, image.height).toDouble();

    final x = left.round().clamp(0, image.width - 1).toInt();
    final y = top.round().clamp(0, image.height - 1).toInt();
    final cropWidth = (right - left).round().clamp(1, image.width - x).toInt();
    final cropHeight = (bottom - top).round().clamp(1, image.height - y).toInt();

    return img.copyCrop(
      image,
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
  }
}
