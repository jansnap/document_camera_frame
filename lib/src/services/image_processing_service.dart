import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageProcessingService {
  String cropImageToFrame(
    String filePath,
    double frameWidth,
    double frameHeight,
    int screenWidth,
    int screenHeight, {
    int sensorOrientation = 0,
  }) {
    final File imageFile = File(filePath);
    final img.Image originalImage = img.decodeImage(
      imageFile.readAsBytesSync(),
    )!;

    debugPrint('[cropImageToFrame] Original image: ${originalImage.width}x${originalImage.height}(元の画像: ${originalImage.width}x${originalImage.height})');
    debugPrint('[cropImageToFrame] Sensor orientation: $sensorOrientation(センサー方向: $sensorOrientation)');

    // Step 1: Determine the correct analysis dimensions based on sensor orientation.
    // ML Kit returns bounding boxes in a coordinate system that accounts for sensor rotation.
    // When sensorOrientation is 90 or 270, ML Kit uses a rotated coordinate system.
    // The saved image file has pixel data in the original orientation (not rotated).
    final bool isImageRotated = sensorOrientation == 90 || sensorOrientation == 270;
    final int analysisWidth = isImageRotated
        ? originalImage.height
        : originalImage.width;
    final int analysisHeight = isImageRotated
        ? originalImage.width
        : originalImage.height;

    debugPrint('[cropImageToFrame] Analysis dimensions: ${analysisWidth}x${analysisHeight}, isRotated: $isImageRotated(分析 dimensions: ${analysisWidth}x${analysisHeight}, 回転: $isImageRotated)');

    // Step 2: Calculate the crop area in the same coordinate system as document detection.
    // Add margin to expand crop area on all sides (15% margin on each side = 30% total expansion).
    const double marginFactor = 0.15; // 15% margin on each side
    final int baseCropWidth = (frameWidth / screenWidth * analysisWidth).round();
    final int baseCropHeight = (frameHeight / screenHeight * analysisHeight).round();

    // Expand width and height by adding margins
    final int cropWidth = (baseCropWidth * (1 + marginFactor * 2)).round();
    final int cropHeight = (baseCropHeight * (1 + marginFactor * 2)).round();

    // Adjust position to center the expanded crop area
    // Ensure crop area doesn't exceed image bounds
    final int maxCropWidth = analysisWidth;
    final int maxCropHeight = analysisHeight;
    final int finalCropWidth = cropWidth > maxCropWidth ? maxCropWidth : cropWidth;
    final int finalCropHeight = cropHeight > maxCropHeight ? maxCropHeight : cropHeight;

    final int cropX = (analysisWidth - finalCropWidth) ~/ 2;
    final int cropY = (analysisHeight - finalCropHeight) ~/ 2;

    debugPrint('[cropImageToFrame] Crop area (analysis coords): x=$cropX, y=$cropY, w=$finalCropWidth, h=$finalCropHeight(クロップ領域(分析座標): x=$cropX, y=$cropY, w=$finalCropWidth, h=$finalCropHeight)');

    // Step 3: Convert coordinates from analysis coordinate system to original image coordinate system.
    // ML Kit returns bounding boxes in the rotated coordinate system (analysis coordinates).
    // We need to convert back to the original image pixel coordinates.
    final int actualCropX;
    final int actualCropY;
    final int actualCropWidth;
    final int actualCropHeight;

    if (isImageRotated) {
      // For rotated images, convert analysis coordinates to original image coordinates.
      // ML Kit returns bounding boxes in the rotated coordinate system (analysis coordinates).
      // The saved image file has pixel data in the original orientation (not rotated).
      //
      // When image is rotated 90 degrees clockwise (sensorOrientation 90):
      // - Analysis coordinate (x, y) maps to Original coordinate (y, originalWidth - x - width)
      // - Analysis width/height swap to Original height/width
      //
      // When image is rotated 270 degrees (sensorOrientation 270):
      // - Analysis coordinate (x, y) maps to Original coordinate (originalHeight - y - height, x)
      // - Analysis width/height swap to Original height/width

      if (sensorOrientation == 90) {
        // 90-degree clockwise rotation
        // Analysis coordinate system: (0,0) at top-left of rotated view
        // Original image: pixel data is not rotated
        // Analysis (cropX, cropY) -> Original (cropY, analysisHeight - cropX - finalCropWidth)
        // Note: analysisHeight = originalImage.width when rotated
        actualCropX = cropY;
        actualCropY = analysisHeight - cropX - finalCropWidth;
        actualCropWidth = finalCropHeight;
        actualCropHeight = finalCropWidth;
      } else if (sensorOrientation == 270) {
        // 270-degree counter-clockwise rotation
        // Analysis (cropX, cropY) -> Original (analysisWidth - cropY - finalCropHeight, cropX)
        // Note: analysisWidth = originalImage.height when rotated
        actualCropX = analysisWidth - cropY - finalCropHeight;
        actualCropY = cropX;
        actualCropWidth = finalCropHeight;
        actualCropHeight = finalCropWidth;
      } else {
        // Default: assume 90-degree rotation (most common)
        // Use analysis dimensions for coordinate conversion
        actualCropX = cropY;
        actualCropY = analysisHeight - cropX - finalCropWidth;
        actualCropWidth = finalCropHeight;
        actualCropHeight = finalCropWidth;
      }
    } else {
      // No rotation: coordinates are the same
      actualCropX = cropX;
      actualCropY = cropY;
      actualCropWidth = finalCropWidth;
      actualCropHeight = finalCropHeight;
    }

    debugPrint('[cropImageToFrame] Crop area (original coords): x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight(クロップ領域(元の座標): x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight)');

    // Ensure crop coordinates are within image bounds
    final int safeCropX = actualCropX.clamp(0, originalImage.width - 1);
    final int safeCropY = actualCropY.clamp(0, originalImage.height - 1);
    final int safeCropWidth = actualCropWidth.clamp(1, originalImage.width - safeCropX);
    final int safeCropHeight = actualCropHeight.clamp(1, originalImage.height - safeCropY);

    if (safeCropX != actualCropX || safeCropY != actualCropY ||
        safeCropWidth != actualCropWidth || safeCropHeight != actualCropHeight) {
      debugPrint('[cropImageToFrame] Warning: Crop coordinates adjusted to fit image bounds(警告: クロップ座標が画像境界に合わせて調整されました)');
      debugPrint('[cropImageToFrame]   Original: x=$actualCropX, y=$actualCropY, w=$actualCropWidth, h=$actualCropHeight');
      debugPrint('[cropImageToFrame]   Adjusted: x=$safeCropX, y=$safeCropY, w=$safeCropWidth, h=$safeCropHeight');
    }

    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: safeCropX,
      y: safeCropY,
      width: safeCropWidth,
      height: safeCropHeight,
    );

    debugPrint('[cropImageToFrame] Cropped image: ${croppedImage.width}x${croppedImage.height}(クロップ後の画像: ${croppedImage.width}x${croppedImage.height})');

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
