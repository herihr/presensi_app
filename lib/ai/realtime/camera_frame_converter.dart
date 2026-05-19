import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class RealtimeCameraFrame {
  const RealtimeCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.rotationDegrees,
    required this.planes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final int width;
  final int height;
  final String format;
  final int rotationDegrees;
  final List<Uint8List> planes;
  final List<int> bytesPerRow;
  final List<int> bytesPerPixel;

  factory RealtimeCameraFrame.fromMessage(Map message) {
    return RealtimeCameraFrame(
      width: message['width'] as int,
      height: message['height'] as int,
      format: message['format'] as String,
      rotationDegrees: message['rotationDegrees'] as int? ?? 0,
      planes: (message['planes'] as List)
          .map(
            (item) =>
                (item as TransferableTypedData).materialize().asUint8List(),
          )
          .toList(),
      bytesPerRow: List<int>.from(message['bytesPerRow'] as List),
      bytesPerPixel: List<int>.from(message['bytesPerPixel'] as List),
    );
  }
}

img.Image cameraFrameToRgb(RealtimeCameraFrame frame) {
  if (frame.format != ImageFormatGroup.yuv420.name || frame.planes.length < 3) {
    throw StateError('Format kamera harus YUV420 untuk model deteksi wajah');
  }

  final out = img.Image(width: frame.width, height: frame.height);
  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];

  for (var y = 0; y < frame.height; y++) {
    final yRow = y * frame.bytesPerRow[0];
    final uvRow = (y >> 1) * frame.bytesPerRow[1];
    for (var x = 0; x < frame.width; x++) {
      final uvIndex = uvRow + (x >> 1) * frame.bytesPerPixel[1];
      final yp = yPlane[yRow + x].toDouble();
      final up = uPlane[uvIndex].toDouble() - 128.0;
      final vp = vPlane[uvIndex].toDouble() - 128.0;

      final red = (yp + 1.402 * vp).round().clamp(0, 255);
      final green =
          (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
      final blue = (yp + 1.772 * up).round().clamp(0, 255);
      out.setPixelRgb(x, y, red, green, blue);
    }
  }

  return out;
}

List<int> rotationCandidates(int rotationDegrees) {
  final normalizedRotation = rotationDegrees % 360;
  final inverseRotation = (360 - normalizedRotation) % 360;
  if (normalizedRotation == inverseRotation) return [normalizedRotation];
  return [normalizedRotation, inverseRotation];
}

img.Image rotateImage(img.Image image, int rotationDegrees) {
  final normalizedRotation = rotationDegrees % 360;
  if (normalizedRotation == 0) return image;
  return img.copyRotate(image, angle: normalizedRotation);
}
