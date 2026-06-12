import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../static_face/face_detector.dart';

class EmbeddingArtifactRecorder {
  const EmbeddingArtifactRecorder._();

  // Mode pengujian: hanya menyimpan satu rangkaian artefak per aplikasi dijalankan.
  static const bool enabled = false;
  static bool _hasSaved = false;
  static bool _isSaving = false;

  static bool get canSave => enabled && !_hasSaved && !_isSaving;

  static Future<String?> saveOnce({
    required img.Image originalImage,
    required List<DetectedFace> detectedFaces,
    required DetectedFace selectedFace,
    required img.Image faceNetInput,
    required List<double> embedding,
  }) async {
    if (!canSave) return null;
    _isSaving = true;

    final now = DateTime.now();
    final folderName = 'embedding_debug_${_timestamp(now)}';

    try {
      final annotated = _drawDetections(
        originalImage,
        detectedFaces,
        selectedFace,
      );
      final yoloJson = const JsonEncoder.withIndent('  ').convert({
        'dibuat': now.toIso8601String(),
        'ukuran_gambar_asli': {
          'width': originalImage.width,
          'height': originalImage.height,
        },
        'jumlah_wajah_terdeteksi': detectedFaces.length,
        'wajah_terpilih': _faceToJson(selectedFace),
        'semua_deteksi': detectedFaces.map(_faceToJson).toList(),
      });
      final embeddingText = const JsonEncoder.withIndent('  ').convert({
        'dimensi': embedding.length,
        'l2_normalized': true,
        'embedding': embedding,
      });
      final readme = [
        'Artefak Pengujian Embedding Awal',
        'Dibuat: ${now.toIso8601String()}',
        '',
        'Urutan proses:',
        '1. 01_foto_asli.jpg: foto sebelum deteksi.',
        '2. 02_hasil_yolo.json: koordinat dan confidence hasil YOLO server.',
        '3. 03_bounding_box.jpg: visualisasi bounding box hasil deteksi.',
        '4. 04_crop_wajah.jpg: wajah terpilih setelah crop dan padding.',
        '5. 05_input_mobilefacenet_112x112.jpg: citra masuk MobileFaceNet.',
        '6. 06_embedding_192_dimensi.json: hasil embedding ternormalisasi.',
        '',
        'Folder ini hanya dibuat sekali per aplikasi dijalankan.',
      ].join('\n');

      final files = <_ArtifactFile>[
        _ArtifactFile(
          '01_foto_asli.jpg',
          Uint8List.fromList(img.encodeJpg(originalImage, quality: 95)),
          'image/jpeg',
        ),
        _ArtifactFile(
          '02_hasil_yolo.json',
          Uint8List.fromList(utf8.encode(yoloJson)),
          'application/json',
        ),
        _ArtifactFile(
          '03_bounding_box.jpg',
          Uint8List.fromList(img.encodeJpg(annotated, quality: 95)),
          'image/jpeg',
        ),
        _ArtifactFile(
          '04_crop_wajah.jpg',
          Uint8List.fromList(
            img.encodeJpg(selectedFace.croppedFace, quality: 95),
          ),
          'image/jpeg',
        ),
        _ArtifactFile(
          '05_input_mobilefacenet_112x112.jpg',
          Uint8List.fromList(img.encodeJpg(faceNetInput, quality: 95)),
          'image/jpeg',
        ),
        _ArtifactFile(
          '06_embedding_192_dimensi.json',
          Uint8List.fromList(utf8.encode(embeddingText)),
          'application/json',
        ),
        _ArtifactFile(
          'README.txt',
          Uint8List.fromList(utf8.encode(readme)),
          'text/plain',
        ),
      ];

      final savedPath = await _saveFiles(folderName, files);
      _hasSaved = true;
      return savedPath;
    } finally {
      _isSaving = false;
    }
  }

  static Map<String, dynamic> _faceToJson(DetectedFace face) {
    return {
      'left': face.x,
      'top': face.y,
      'width': face.width,
      'height': face.height,
      'confidence': face.confidence,
      'crop_width': face.croppedFace.width,
      'crop_height': face.croppedFace.height,
    };
  }

  static img.Image _drawDetections(
    img.Image original,
    List<DetectedFace> faces,
    DetectedFace selected,
  ) {
    final annotated = img.decodeJpg(img.encodeJpg(original, quality: 100))!;
    for (final face in faces) {
      final isSelected = identical(face, selected);
      _drawBox(
        annotated,
        face.x,
        face.y,
        face.width,
        face.height,
        isSelected ? const [22, 163, 74] : const [239, 68, 68],
        isSelected ? 6 : 4,
      );
    }
    return annotated;
  }

  static void _drawBox(
    img.Image image,
    int left,
    int top,
    int width,
    int height,
    List<int> color,
    int thickness,
  ) {
    final x1 = left.clamp(0, image.width - 1);
    final y1 = top.clamp(0, image.height - 1);
    final x2 = (left + width).clamp(0, image.width - 1);
    final y2 = (top + height).clamp(0, image.height - 1);

    for (var offset = 0; offset < thickness; offset++) {
      final topY = (y1 + offset).clamp(0, image.height - 1);
      final bottomY = (y2 - offset).clamp(0, image.height - 1);
      for (var x = x1; x <= x2; x++) {
        image.setPixelRgb(x, topY, color[0], color[1], color[2]);
        image.setPixelRgb(x, bottomY, color[0], color[1], color[2]);
      }

      final leftX = (x1 + offset).clamp(0, image.width - 1);
      final rightX = (x2 - offset).clamp(0, image.width - 1);
      for (var y = y1; y <= y2; y++) {
        image.setPixelRgb(leftX, y, color[0], color[1], color[2]);
        image.setPixelRgb(rightX, y, color[0], color[1], color[2]);
      }
    }
  }

  static Future<String> _saveFiles(
    String folderName,
    List<_ArtifactFile> files,
  ) async {
    try {
      const channel = MethodChannel('presensi_app/downloads');
      String? savedPath;
      for (final file in files) {
        savedPath = await channel.invokeMethod<String>('saveArtifact', {
          'fileName': file.name,
          'bytes': file.bytes,
          'mimeType': file.mimeType,
          'relativeFolder': 'PresenSatu/$folderName',
        });
      }
      return savedPath?.replaceFirst('/${files.last.name}', '') ??
          'Download/PresenSatu/$folderName';
    } catch (_) {
      return _saveFilesFallback(folderName, files);
    }
  }

  static Future<String> _saveFilesFallback(
    String folderName,
    List<_ArtifactFile> files,
  ) async {
    final roots = [
      Directory('/storage/emulated/0/Download/PresenSatu'),
      Directory('/storage/emulated/0/Downloads/PresenSatu'),
      Directory.systemTemp,
    ];

    Object? lastError;
    for (final root in roots) {
      try {
        final folder = Directory(
          '${root.path}${Platform.pathSeparator}$folderName',
        );
        await folder.create(recursive: true);
        for (final file in files) {
          await File(
            '${folder.path}${Platform.pathSeparator}${file.name}',
          ).writeAsBytes(file.bytes, flush: true);
        }
        return folder.path;
      } catch (error) {
        lastError = error;
      }
    }
    throw Exception(
      'Folder artefak pengujian tidak dapat disimpan: $lastError',
    );
  }

  static String _timestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}_'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}

class _ArtifactFile {
  const _ArtifactFile(this.name, this.bytes, this.mimeType);

  final String name;
  final Uint8List bytes;
  final String mimeType;
}
