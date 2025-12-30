import 'dart:io';
import 'package:image/image.dart' as img;

class ImageProcessingService {
  String cropImageToFrame(
    String filePath,
    double frameWidth,
    double frameHeight,
    int screenWidth,
    int screenHeight,
  ) {
    final File imageFile = File(filePath);
    final img.Image originalImage = img.decodeImage(
      imageFile.readAsBytesSync(),
    )!;

    final int cropWidth = originalImage.width * frameWidth ~/ screenWidth;
    final int cropHeight = originalImage.height * frameHeight ~/ screenHeight;

    final int cropX = (originalImage.width - cropWidth) ~/ 2;
    final int cropY = (originalImage.height - cropHeight) ~/ 2;

    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    // Replace file extension with .png for lossless image quality
    final int lastDotIndex = filePath.lastIndexOf('.');
    final String basePath = lastDotIndex >= 0
        ? filePath.substring(0, lastDotIndex)
        : filePath;
    final String croppedFilePath = '${basePath}_cropped.png';
    // Use PNG format for lossless image quality (no compression artifacts)
    File(croppedFilePath).writeAsBytesSync(img.encodePng(croppedImage));

    return croppedFilePath;
  }
}
