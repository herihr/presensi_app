import 'package:image/image.dart' as img;

class YoloDetectedFace {
  const YoloDetectedFace({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.croppedFace,
    required this.box,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;
  final img.Image croppedFace;
  final YoloFaceBox box;

  img.Image? get faceImage => croppedFace;
}

class YoloFaceBox {
  const YoloFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    this.faceImage,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
  final img.Image? faceImage;

  YoloFaceBox copyWith({img.Image? faceImage}) {
    return YoloFaceBox(
      left: left,
      top: top,
      width: width,
      height: height,
      confidence: confidence,
      faceImage: faceImage ?? this.faceImage,
    );
  }
}
