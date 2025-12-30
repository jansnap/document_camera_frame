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

    // Step 1: Determine the correct analysis dimensions based on image rotation.
    // We assume a portrait UI, so if the image buffer is wider than it is tall, it's been rotated.
    final bool isImageRotated = originalImage.width > originalImage.height;
    final int analysisWidth = isImageRotated
        ? originalImage.height
        : originalImage.width;
    final int analysisHeight = isImageRotated
        ? originalImage.width
        : originalImage.height;

    // Step 2: Calculate the crop area in the same coordinate system as document detection.
    final int cropWidth = (frameWidth / screenWidth * analysisWidth).round();
    final int cropHeight = (frameHeight / screenHeight * analysisHeight).round();

    final int cropX = (analysisWidth - cropWidth) ~/ 2;
    final int cropY = (analysisHeight - cropHeight) ~/ 2;

    // Step 3: Convert coordinates to original image coordinate system if rotated.
    final int actualCropX;
    final int actualCropY;
    final int actualCropWidth;
    final int actualCropHeight;

    if (isImageRotated) {
      // For rotated images, convert analysis coordinates to original image coordinates
      // Analysis: (cropX, cropY) with size (cropWidth, cropHeight)
      // Original: rotated 90 degrees, so swap and transform coordinates
      actualCropX = cropY;
      actualCropY = (analysisWidth - cropX - cropWidth);
      actualCropWidth = cropHeight;
      actualCropHeight = cropWidth;
    } else {
      actualCropX = cropX;
      actualCropY = cropY;
      actualCropWidth = cropWidth;
      actualCropHeight = cropHeight;
    }

    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: actualCropX,
      y: actualCropY,
      width: actualCropWidth,
      height: actualCropHeight,
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
