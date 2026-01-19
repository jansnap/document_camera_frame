import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';

class CapturedImagePreview extends StatelessWidget {
  final ValueNotifier<String> capturedImageNotifier;
  final double detectionFrameWidth;
  final double detectionFrameHeight;

  final double borderRadius;
  const CapturedImagePreview({
    super.key,
    required this.capturedImageNotifier,
    required this.detectionFrameWidth,
    required this.detectionFrameHeight,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: capturedImageNotifier,
      builder: (context, imagePath, child) {
        if (imagePath.isEmpty) {
          return const SizedBox.shrink();
        }

        final previewHeight =
            detectionFrameHeight + AppConstants.bottomFrameContainerHeight;
        debugPrint('----------------------------------');
        debugPrint(
          '[CapturedImagePreview] Widget size: ${detectionFrameWidth.toStringAsFixed(0)} x ${previewHeight.toStringAsFixed(0)}',
        );
        debugPrint(
          '[CapturedImagePreview] Preview size: ${detectionFrameWidth.toStringAsFixed(0)} x ${detectionFrameHeight.toStringAsFixed(0)}',
        );
        debugPrint('----------------------------------');

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: detectionFrameWidth,
            height: previewHeight,
            child: Stack(
              children: [
                // Black background for padding
                Container(
                  width: detectionFrameWidth,
                  height: previewHeight,
                  color: Colors.black,
                ),
                // Image with centered alignment
                Positioned(
                  top: 3,
                  left: 3,
                  right: 3,
                  child: Center(
                    child: Container(
                      width: detectionFrameWidth,
                      height: detectionFrameHeight,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
