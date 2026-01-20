import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:document_camera_frame/document_camera_frame.dart';
import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../services/document_detection_service.dart';

/// A customizable camera view for capturing both sides of document images.
///
/// This widget provides a predefined frame for document capture,
/// with support for capturing front and back sides of documents.
class DocumentCameraFrame extends StatefulWidget {
  /// Width of the document capture frame.
  final double frameWidth;

  /// Height of the document capture frame.
  final double frameHeight;

  /// Animation styling configuration
  final DocumentCameraAnimationStyle animationStyle;

  /// Frame styling configuration
  final DocumentCameraFrameStyle frameStyle;

  /// Button styling configuration
  final DocumentCameraButtonStyle buttonStyle;

  /// Title styling configuration
  final DocumentCameraTitleStyle titleStyle;

  /// Side indicator styling configuration
  final DocumentCameraSideIndicatorStyle sideIndicatorStyle;

  /// Progress indicator styling configuration
  final DocumentCameraProgressStyle progressStyle;

  /// Instruction text styling configuration
  final DocumentCameraInstructionStyle instructionStyle;

  /// Callback triggered when front side is captured.
  final Function(String imgPath)? onFrontCaptured;

  /// Callback triggered when back side is captured.
  final Function(String imgPath)? onBackCaptured;

  /// Callback triggered when both sides are captured and saved.
  final Function(DocumentCaptureData documentData) onBothSidesSaved;

  /// Callback triggered when the "Retake" button is pressed.
  final VoidCallback? onRetake;

  /// Bottom container customization
  final Widget? bottomFrameContainerChild;

  /// Show close button
  final bool showCloseButton;

  /// Camera index
  final int? cameraIndex;

  /// Whether to require both sides (if false, can save with just front side)
  final bool requireBothSides;

  /// Optional bottom hint text shown in the bottom container.
  final String? bottomHintText;

  /// Optional widget shown on the right (e.g. a check icon).
  final Widget? sideInfoOverlay;

  /// Enables automatic capture when a document is aligned in the frame.
  final bool enableAutoCapture;

  /// Callback triggered when a camera-related error occurs (e.g., initialization, streaming, or capture failure).
  final void Function(Object error)? onCameraError;

  /// Callback triggered when capture is successful.
  /// Provides the bounding box of the document frame as a Rect.
  /// Rect contains: left (x), top (y), right (x + width), bottom (y + height)
  /// To get width: frameBounds.width, height: frameBounds.height
  /// Called once per successful capture.
  final void Function(Rect frameBounds)? onCaptureSuccess;

  /// Constructor for the [DocumentCameraFrame].
  const DocumentCameraFrame({
    super.key,
    required this.frameWidth,
    required this.frameHeight,
    this.animationStyle = const DocumentCameraAnimationStyle(),
    this.frameStyle = const DocumentCameraFrameStyle(),
    this.buttonStyle = const DocumentCameraButtonStyle(),
    this.titleStyle = const DocumentCameraTitleStyle(),
    this.sideIndicatorStyle = const DocumentCameraSideIndicatorStyle(),
    this.progressStyle = const DocumentCameraProgressStyle(),
    this.instructionStyle = const DocumentCameraInstructionStyle(),
    this.onFrontCaptured,
    this.onBackCaptured,
    required this.onBothSidesSaved,
    this.onRetake,
    this.bottomFrameContainerChild,
    this.showCloseButton = false,
    this.cameraIndex,
    this.requireBothSides = true,
    this.bottomHintText,
    this.sideInfoOverlay,
    this.enableAutoCapture = false,
    this.onCameraError,
    this.onCaptureSuccess,
  });

  @override
  State<DocumentCameraFrame> createState() => _DocumentCameraFrameState();
}

class _DocumentCameraFrameState extends State<DocumentCameraFrame>
    with TickerProviderStateMixin {
  Timer? _debounceTimer;
  bool _isDebouncing = false;
  Timer? _autoFocusTimer;
  Size? _layoutSize;

  late DocumentCameraController _controller;

  // State notifiers
  final ValueNotifier<bool> _isInitializedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<String> _capturedImageNotifier = ValueNotifier("");
  final ValueNotifier<DocumentSide> _currentSideNotifier = ValueNotifier(
    DocumentSide.front,
  );
  final ValueNotifier<DocumentCaptureData> _documentDataNotifier =
      ValueNotifier(DocumentCaptureData());
  final ValueNotifier<bool> _isDocumentAlignedNotifier = ValueNotifier(false);
  final ValueNotifier<String> _detectionStatusNotifier =
      ValueNotifier('ドキュメントを検出中...');

  // Animation controllers
  AnimationController? _progressAnimationController;
  Animation<double>? _progressAnimation;

  // Document detection
  DocumentDetectionService? _documentDetectionService;
  bool _isDetectorBusy = false;
  bool _isImageStreamActive = false;

  // Frame dimensions
  late double _updatedFrameWidth;
  late double _updatedFrameHeight;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedFrameDimensions) {
      _calculateFrameDimensions();
      _hasInitializedFrameDimensions = true;
    }
  }

  void _calculateFrameDimensions({Size? maxSize}) {
    final size = maxSize ?? _layoutSize ?? MediaQuery.of(context).size;

    final maxWidth = size.width;
    final maxHeight = size.height;

    // Calculate aspect ratio from original dimensions
    final aspectRatio = widget.frameHeight / widget.frameWidth;

    // Use provided frame width and keep aspect ratio
    _updatedFrameWidth = widget.frameWidth;
    _updatedFrameHeight = _updatedFrameWidth * aspectRatio;

    debugPrint(
      '[FrameDimensions] input=${widget.frameWidth.toStringAsFixed(1)}x'
      '${widget.frameHeight.toStringAsFixed(1)} '
      'max=${maxWidth.toStringAsFixed(1)}x${maxHeight.toStringAsFixed(1)} '
      'updated=${_updatedFrameWidth.toStringAsFixed(1)}x'
      '${_updatedFrameHeight.toStringAsFixed(1)}',
    );
  }

  bool _hasInitializedFrameDimensions = false;

  Future<void> _initializeComponents() async {
    if (widget.sideIndicatorStyle.showSideIndicator) {
      _initializeProgressAnimation();
    }

    if (widget.enableAutoCapture) {
      _documentDetectionService = DocumentDetectionService(
        onError: widget.onCameraError,
      );
      _documentDetectionService!.initialize();
    }

    await _initializeCamera();
  }

  void _initializeProgressAnimation() {
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Initializes the camera and updates the state when ready.
  Future<void> _initializeCamera() async {
    try {
      _controller = DocumentCameraController();
      await _controller.initialize(
        widget.cameraIndex ?? 0,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      if (!mounted) return;

      setState(() {
        _calculateFrameDimensions();
        _hasInitializedFrameDimensions = true;
      });

      _isInitializedNotifier.value = true;

      // Trigger auto focus at frame center after initialization
      final frameCenter = _calculateFrameCenter();
      _controller.triggerAutoFocus(frameCenter);

      if (widget.enableAutoCapture) {
        await _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      widget.onCameraError?.call(e);
    }
  }

  // Safe image stream management methods
  Future<void> _startImageStream() async {
    if (_isImageStreamActive ||
        _controller.cameraController == null ||
        !_controller.cameraController!.value.isInitialized) {
      return;
    }

    try {
      await _controller.cameraController!.startImageStream(_processCameraImage);
      _isImageStreamActive = true;
      // Start periodic auto focus
      _startAutoFocusTimer();
    } catch (e) {
      debugPrint('Failed to start image stream: $e');
      _isImageStreamActive = false;
      widget.onCameraError?.call(e);
    }
  }

  /// Calculate frame center position in normalized coordinates (0.0-1.0)
  Offset _calculateFrameCenter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final frameTotalHeight =
        _updatedFrameHeight + AppConstants.bottomFrameContainerHeight;
    final bottomPosition = (screenHeight - frameTotalHeight) / 2;

    final frameLeft = (screenWidth - _updatedFrameWidth) / 2;
    final frameTop = screenHeight - bottomPosition - _updatedFrameHeight;
    final frameCenterX = (frameLeft + _updatedFrameWidth / 2) / screenWidth;
    final frameCenterY = (frameTop + _updatedFrameHeight / 2) / screenHeight;

    return Offset(frameCenterX, frameCenterY);
  }

  /// Start periodic auto focus timer
  void _startAutoFocusTimer() {
    _autoFocusTimer?.cancel();
    _autoFocusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted &&
          _isImageStreamActive &&
          _controller.cameraController != null) {
        final frameCenter = _calculateFrameCenter();
        _controller.triggerAutoFocus(frameCenter);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _stopImageStream() async {
    final controller = _controller.cameraController;
    if (!_isImageStreamActive ||
        controller == null ||
        !controller.value.isStreamingImages) {
      debugPrint(
        '[stopImageStream] Image stream is not active, skipping stop(画像ストリームはアクティブではないため、停止をスキップします)',
      );
      return;
    }

    try {
      debugPrint('[stopImageStream] Stopping image stream(画像ストリームを停止します)');
      // Stop auto focus timer
      _autoFocusTimer?.cancel();
      _autoFocusTimer = null;
      await controller.stopImageStream();
      debugPrint(
        '[stopImageStream] Image stream stopped successfully(画像ストリームを正常に停止しました)',
      );
    } catch (e) {
      debugPrint(
        '[stopImageStream] Failed to stop image stream: $e(画像ストリームの停止に失敗しました: $e)',
      );
      widget.onCameraError?.call(e);
    } finally {
      _isImageStreamActive = false;
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetectorBusy || !mounted || _documentDetectionService == null) {
      return;
    }

    if (_capturedImageNotifier.value.isNotEmpty) {
      if (_isDocumentAlignedNotifier.value) {
        _isDocumentAlignedNotifier.value = false;
      }
      if (_detectionStatusNotifier.value.isNotEmpty) {
        _detectionStatusNotifier.value = '';
      }
      return;
    }

    _isDetectorBusy = true;

    try {
      final bool isAligned = await _documentDetectionService!.processImage(
        image: image,
        cameraController: _controller.cameraController!,
        context: context,
        frameWidth: _updatedFrameWidth,
        frameHeight: _updatedFrameHeight,
        screenWidth: MediaQuery.of(context).size.width.toInt(),
        screenHeight: MediaQuery.of(context).size.height.toInt(),
        onStatusUpdated: (status) {
          if (mounted) {
            _detectionStatusNotifier.value = status;
          }
        },
      );

      if (!mounted) return;

      // Log document detection state changes
      final previousAlignedState = _isDocumentAlignedNotifier.value;
      if (previousAlignedState != isAligned) {
        if (isAligned) {
          debugPrint(
            '[processCameraImage] Document detected - frame color changed to green(ドキュメントが検出されました - 枠の色が緑色に変わりました)',
          );
        } else {
          debugPrint(
            '[processCameraImage] Document position not aligned with frame - frame color changed to white(ドキュメントの位置が合っていません - 枠の色が白色に変わりました)',
          );
        }
      }

      _isDocumentAlignedNotifier.value = isAligned;

      if (isAligned) {
        if (!_isDebouncing) {
          _isDebouncing = true;

          _debounceTimer = Timer(const Duration(seconds: 1), () async {
            if (_isDocumentAlignedNotifier.value && mounted) {
              await _captureAndHandleImageUnified(
                context,
                _updatedFrameWidth,
                _updatedFrameHeight + AppConstants.bottomFrameContainerHeight,
                1.sw(context).toInt(),
                1.sh(context).toInt(),
              );
            }
            _isDebouncing = false;
            _debounceTimer = null;
          });
        }
      } else {
        if (_isDebouncing) {
          _debounceTimer?.cancel();
          _debounceTimer = null;
          _isDebouncing = false;
        }
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
      widget.onCameraError?.call(e);
    } finally {
      _isDetectorBusy = false;
    }
  }

  Future<void> _captureAndHandleImageUnified(
    BuildContext context,
    double frameWidth,
    double frameHeight,
    int screenWidth,
    int screenHeight,
  ) async {
    if (_isLoadingNotifier.value) {
      return; // Prevent multiple simultaneous captures
    }

    _isLoadingNotifier.value = true;

    debugPrint(
      '[captureAndHandleImageUnified] Starting capture process(キャプチャ処理を開始します)',
    );
    debugPrint(
      '[captureAndHandleImageUnified] Frame: ${frameWidth}x${frameHeight}, Screen: ${screenWidth}x${screenHeight}(フレーム: ${frameWidth}x${frameHeight}, 画面: ${screenWidth}x${screenHeight})',
    );

    try {
      // Stop image stream before capture to prevent conflicts
      if (widget.enableAutoCapture && _isImageStreamActive) {
        await _stopImageStream();
      }

      debugPrint(
        '[captureAndHandleImageUnified] Capturing and cropping image(画像をキャプチャしてクロップします)',
      );
      await _controller.takeAndCropPicture(
        frameWidth,
        frameHeight,
        screenWidth,
        screenHeight,
      );
      debugPrint(
        '[captureAndHandleImageUnified] Image captured and cropped successfully(画像のキャプチャとクロップが正常に完了しました)',
      );

      _capturedImageNotifier.value = _controller.imagePath;
      _handleCapture(_controller.imagePath);
      debugPrint(
        '[captureAndHandleImageUnified] Capture handling completed(キャプチャ処理が完了しました)',
      );

      // 撮影成功時にフレームのバウンディングボックスを通知（1回だけ）
      if (mounted && widget.onCaptureSuccess != null) {
        final frameBounds = _calculateFrameBounds(context);
        widget.onCaptureSuccess!(frameBounds);
      }

      // Release camera after successful capture
      debugPrint(
        '[captureAndHandleImageUnified] Releasing camera after successful capture(撮影成功後にカメラを解放します)',
      );
      await _controller.releaseCamera();
      debugPrint(
        '[captureAndHandleImageUnified] Capture process completed successfully(キャプチャ処理が正常に完了しました)',
      );
    } catch (e) {
      debugPrint(
        '[captureAndHandleImageUnified] Capture failed: $e(キャプチャに失敗しました: $e)',
      );
      widget.onCameraError?.call(e);

      // Release camera even on capture failure
      debugPrint(
        '[captureAndHandleImageUnified] Releasing camera after capture failure(撮影失敗後にカメラを解放します)',
      );
      try {
        await _controller.releaseCamera();
      } catch (releaseError) {
        debugPrint(
          '[captureAndHandleImageUnified] Error releasing camera after failure: $releaseError(撮影失敗後のカメラ解放中にエラーが発生しました: $releaseError)',
        );
      }
    } finally {
      if (mounted) {
        _isLoadingNotifier.value = false;
      }
    }
  }

  /// Handle image capture based on current side
  void _handleCapture(String imagePath) {
    final currentSide = _currentSideNotifier.value;
    final currentData = _documentDataNotifier.value;

    if (currentSide == DocumentSide.front) {
      _documentDataNotifier.value = currentData.copyWith(
        frontImagePath: imagePath,
      );
      widget.onFrontCaptured?.call(imagePath);
    } else {
      _documentDataNotifier.value = currentData.copyWith(
        backImagePath: imagePath,
      );
      widget.onBackCaptured?.call(imagePath);
    }
  }

  /// Switch to back side capture
  void _switchToBackSide() {
    _currentSideNotifier.value = DocumentSide.back;
    _controller.resetImage();
    _capturedImageNotifier.value = _controller.imagePath;

    _progressAnimationController?.animateTo(1.0);

    // Restart stream for auto-capture
    if (widget.enableAutoCapture) {
      _restartImageStreamSafely();
    }
  }

  /// Switch to front side capture
  void _switchToFrontSide() {
    _currentSideNotifier.value = DocumentSide.front;
    final frontImagePath = _documentDataNotifier.value.frontImagePath;

    if (frontImagePath != null && frontImagePath.isNotEmpty) {
      _capturedImageNotifier.value = frontImagePath;
    } else {
      _controller.resetImage();
      _capturedImageNotifier.value = _controller.imagePath;
    }

    _progressAnimationController?.animateTo(0.0);

    // Restart stream for auto-capture if no front image exists
    if (widget.enableAutoCapture &&
        (frontImagePath == null || frontImagePath.isEmpty)) {
      _restartImageStreamSafely();
    }
  }

  /// Handle save action
  void _handleSave() {
    final data = _documentDataNotifier.value;
    if (!widget.requireBothSides ||
        data.isCompleteFor(requireBothSides: widget.requireBothSides)) {
      widget.onBothSidesSaved(data);
      _resetCapture();
    }
  }

  /// Handle retake current side
  void _handleRetake() {
    final currentSide = _currentSideNotifier.value;
    final currentData = _documentDataNotifier.value;

    if (currentSide == DocumentSide.front) {
      _documentDataNotifier.value = currentData.copyWith(frontImagePath: "");
    } else {
      _documentDataNotifier.value = currentData.copyWith(backImagePath: "");
    }

    _controller.retakeImage();
    _capturedImageNotifier.value = _controller.imagePath;

    // Restart image stream for auto-capture if enabled
    if (widget.enableAutoCapture) {
      _restartImageStreamSafely();
    }

    widget.onRetake?.call();
  }

  // Helper method to safely restart image stream
  Future<void> _restartImageStreamSafely() async {
    try {
      // Ensure stream is stopped first
      if (_isImageStreamActive) {
        await _stopImageStream();
      }

      // Small delay to ensure camera is ready
      await Future.delayed(widget.animationStyle.frameFlipDuration);

      // Start the stream again
      await _startImageStream();
    } catch (e) {
      debugPrint('Failed to restart image stream: $e');
      widget.onCameraError?.call(e);
    }
  }

  void _resetCapture() {
    _controller.resetImage();
    _capturedImageNotifier.value = _controller.imagePath;
    // _currentSideNotifier.value = DocumentSide.front;
    // _documentDataNotifier.value = DocumentCaptureData();
    // _progressAnimationController?.reset();
  }

  Widget _buildProgressIndicator() {
    if (_progressAnimation == null) return const SizedBox.shrink();

    return Container(
      height: widget.progressStyle.progressIndicatorHeight,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _progressAnimation!,
        builder: (context, child) {
          return LinearProgressIndicator(
            value: _progressAnimation!.value,
            backgroundColor: Colors.white.withAlpha((0.3 * 255).toInt()),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.progressStyle.progressIndicatorColor ??
                  Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionText() {
    return ValueListenableBuilder<DocumentSide>(
      valueListenable: _currentSideNotifier,
      builder: (context, currentSide, child) {
        final instruction = currentSide == DocumentSide.front
            ? (widget.instructionStyle.frontSideInstruction ??
                  "Position the front side of your document within the frame\n"
                  "表面を枠内に合わせてください")
            : (widget.instructionStyle.backSideInstruction ??
                  "Now position the back side of your document within the frame\n"
                  "裏面を枠内に合わせてください");

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((0.6 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            instruction,
            style:
                widget.instructionStyle.instructionTextStyle ??
                const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  Widget _buildStatusText() {
    return ValueListenableBuilder<String>(
      valueListenable: _detectionStatusNotifier,
      builder: (context, status, child) {
        if (status.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(
          status,
          textAlign: TextAlign.center,
          style: widget.instructionStyle.instructionTextStyle ??
              const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
        );
      },
    );
  }

  Widget _buildCurrentTitle() {
    return ValueListenableBuilder<DocumentSide>(
      valueListenable: _currentSideNotifier,
      builder: (context, currentSide, child) {
        Widget? currentTitle;

        if (currentSide == DocumentSide.front &&
            widget.titleStyle.frontSideTitle != null) {
          currentTitle = widget.titleStyle.frontSideTitle;
        } else if (currentSide == DocumentSide.back &&
            widget.titleStyle.backSideTitle != null) {
          currentTitle = widget.titleStyle.backSideTitle;
        } else if (widget.titleStyle.title != null) {
          currentTitle = widget.titleStyle.title;
        }

        return currentTitle ?? const SizedBox.shrink();
      },
    );
  }

  /// Calculates and returns the bounding box of the document frame in screen coordinates.
  /// Returns a Rect with: left (x), top (y), right (x + width), bottom (y + height)
  Rect _calculateFrameBounds(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final frameTotalHeight =
        _updatedFrameHeight + AppConstants.bottomFrameContainerHeight;
    // フレームを画面の中央に配置
    final bottomPosition = (screenHeight - frameTotalHeight) / 2;

    // Calculate frame position in screen coordinates
    final left = (screenWidth - _updatedFrameWidth) / 2; // x position
    final top =
        screenHeight - bottomPosition - _updatedFrameHeight; // y position
    final right = left + _updatedFrameWidth; // x + width
    final bottom = screenHeight - bottomPosition; // y + height

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _syncLayoutSize(Size size) {
    if (_layoutSize == size) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _layoutSize = size;
        _calculateFrameDimensions(maxSize: size);
        _hasInitializedFrameDimensions = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    debugPrint('═══════════════════════════════════════');
    debugPrint(
      '[CameraPreview] Widget size: ${screenSize.width.toStringAsFixed(0)} x ${screenSize.height.toStringAsFixed(0)}',
    );
    debugPrint(
      '[CameraPreview] Preview size: ${screenSize.width.toStringAsFixed(0)} x ${screenSize.height.toStringAsFixed(0)}',
    );
    debugPrint('═══════════════════════════════════════');

    return Scaffold(
      backgroundColor: Colors.black,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _syncLayoutSize(constraints.biggest);
            return ValueListenableBuilder<bool>(
              valueListenable: _isInitializedNotifier,
              builder: (context, isInitialized, child) => Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview
                  if (isInitialized && _controller.cameraController != null)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cameraValue = _controller.cameraController!.value;
                        final previewSize = cameraValue.previewSize;
                        double aspectRatio = 3264 / 2448; // Fallback aspect ratio

                        if (previewSize != null) {
                          // Use actual preview size from camera stream
                          aspectRatio = previewSize.height / previewSize.width;
                          debugPrint(
                            '[CameraPreview] Actual preview size: ${previewSize.width}x${previewSize.height}, '
                            'aspect ratio: $aspectRatio',
                          );
                        }

                        final maxWidth = constraints.maxWidth;
                        final maxHeight = constraints.maxHeight;
                        final fittedWidth = maxWidth;
                        final fittedHeight = maxWidth / aspectRatio;

                        final heightGap = (maxHeight - fittedHeight).abs();
                        const epsilon = 0.5;
                        String letterbox;
                        if (fittedHeight > maxHeight + epsilon) {
                          letterbox = '上下をトリミング';
                        } else if (fittedHeight < maxHeight - epsilon) {
                          letterbox = '上下に黒帯';
                        } else {
                          letterbox = '黒帯なし';
                        }

                        debugPrint('═══════════════════════════════════════');
                        debugPrint(
                          '[CameraPreview] Fit: '
                          'container=${maxWidth.toStringAsFixed(1)}x${maxHeight.toStringAsFixed(1)}, '
                          'preview=${fittedWidth.toStringAsFixed(1)}x${fittedHeight.toStringAsFixed(1)}, '
                          'gapH=${heightGap.toStringAsFixed(1)}, result=$letterbox',
                        );
                        debugPrint('═══════════════════════════════════════');

                        return SizedBox(
                          width: maxWidth,
                          height: maxHeight,
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: fittedWidth,
                                height: fittedHeight,
                                child: CameraPreview(
                                  _controller.cameraController!,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

              // Captured image preview
              if (false)
                if (isInitialized)
                  CapturedImagePreview(
                    capturedImageNotifier: _capturedImageNotifier,
                    detectionFrameWidth: _updatedFrameWidth,
                    detectionFrameHeight: _updatedFrameHeight,
                    borderRadius: widget.frameStyle.outerFrameBorderRadius,
                  ),

              // Frame capture animation
              if (false)
                if (isInitialized)
                  ValueListenableBuilder<bool>(
                    valueListenable: _isLoadingNotifier,
                    child: FrameCaptureAnimation(
                      frameWidth: _updatedFrameWidth,
                      frameHeight: _updatedFrameHeight,
                      animationDuration:
                          widget.animationStyle.capturingAnimationDuration,
                      animationColor:
                          widget.animationStyle.capturingAnimationColor,
                      curve: widget.animationStyle.capturingAnimationCurve,
                    ),
                    builder: (context, isLoading, child) {
                      return isLoading ? child! : const SizedBox.shrink();
                    },
                  ),

              // Document frame
              ValueListenableBuilder<bool>(
                valueListenable: _isDocumentAlignedNotifier,
                builder: (context, isAligned, child) {
                  return TwoSidedAnimatedFrame(
                    detectionFrameHeight: _updatedFrameHeight,
                    detectionFrameWidth: _updatedFrameWidth,
                    detectionFrameOuterBorderRadius:
                        widget.frameStyle.outerFrameBorderRadius,
                    detectionFrameInnerCornerBorderRadius:
                        widget.frameStyle.innerCornerBroderRadius,
                    detectionFrameFlipDuration:
                        widget.animationStyle.frameFlipDuration,
                    detectionFrameFlipCurve: widget.animationStyle.frameFlipCurve,
                    border: widget.frameStyle.frameBorder,
                    currentSideNotifier: _currentSideNotifier,
                    isDocumentAligned: isAligned,
                  );
                },
              ),

              // Bottom frame container
              if (false)
                TwoSidedBottomFrameContainer(
                  width: _updatedFrameWidth,
                  height: _updatedFrameHeight,
                  borderRadius: widget.frameStyle.outerFrameBorderRadius,
                  currentSideNotifier: _currentSideNotifier,
                  documentDataNotifier: _documentDataNotifier,
                  bottomHintText: widget.bottomHintText,
                  sideInfoOverlay: widget.sideInfoOverlay,
                ),

              // Progress indicator
              if (false)
                if (widget.requireBothSides &&
                    widget.sideIndicatorStyle.showSideIndicator)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 0,
                    right: 0,
                    child: _buildProgressIndicator(),
                  ),

              // Instruction text
              Positioned(
                top:
                    widget.requireBothSides &&
                        widget.sideIndicatorStyle.showSideIndicator
                    ? MediaQuery.of(context).padding.top + 120
                    : MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: _buildInstructionText(),
              ),

              // Status text
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 40,
                left: 0,
                right: 0,
                child: _buildStatusText(),
              ),

              // Screen title
              if (false)
                if (widget.titleStyle.title != null ||
                    widget.titleStyle.frontSideTitle != null ||
                    widget.titleStyle.backSideTitle != null ||
                    widget.showCloseButton)
                  ScreenTitle(
                    title: _buildCurrentTitle(),
                    showCloseButton: widget.showCloseButton,
                    screenTitleAlignment:
                        widget.titleStyle.screenTitleAlignment,
                    screenTitlePadding: widget.titleStyle.screenTitlePadding,
                  ),

              // Side indicator
              if (false)
                if (widget.requireBothSides &&
                    widget.sideIndicatorStyle.showSideIndicator)
                  SideIndicator(
                    currentSideNotifier: _currentSideNotifier,
                    documentDataNotifier: _documentDataNotifier,
                    rightPosition: 20,
                    backgroundColor:
                        widget
                            .sideIndicatorStyle
                            .sideIndicatorBackgroundColor ??
                        Colors.black.withAlpha((0.8 * 255).toInt()),
                    borderColor:
                        widget.sideIndicatorStyle.sideIndicatorBorderColor,
                    activeColor:
                        widget.sideIndicatorStyle.sideIndicatorActiveColor ??
                        Colors.blue,
                    inactiveColor:
                        widget.sideIndicatorStyle.sideIndicatorInactiveColor ??
                        Colors.grey,
                    completedColor:
                        widget.sideIndicatorStyle.sideIndicatorCompletedColor ??
                        Colors.green,
                    textStyle: widget.sideIndicatorStyle.sideIndicatorTextStyle,
                  ),

              // Action buttons
              if (false)
                TwoSidedActionButtons(
                  captureOuterCircleRadius:
                      widget.buttonStyle.captureOuterCircleRadius,
                  captureInnerCircleRadius:
                      widget.buttonStyle.captureInnerCircleRadius,
                  captureButtonAlignment:
                      widget.buttonStyle.captureButtonAlignment,
                  captureButtonPadding: widget.buttonStyle.captureButtonPadding,
                  captureButtonText: widget.buttonStyle.captureButtonText,
                  captureFrontButtonText:
                      widget.buttonStyle.captureFrontButtonText,
                  captureBackButtonText:
                      widget.buttonStyle.captureBackButtonText,
                  saveButtonText: widget.buttonStyle.saveButtonText,
                  nextButtonText: widget.buttonStyle.nextButtonText,
                  previousButtonText: widget.buttonStyle.previousButtonText,
                  retakeButtonText: widget.buttonStyle.retakeButtonText,
                  captureButtonTextStyle:
                      widget.buttonStyle.captureButtonTextStyle,
                  actionButtonTextStyle:
                      widget.buttonStyle.actionButtonTextStyle,
                  retakeButtonTextStyle:
                      widget.buttonStyle.retakeButtonTextStyle,
                  captureButtonStyle: widget.buttonStyle.captureButtonStyle,
                  actionButtonStyle: widget.buttonStyle.actionButtonStyle,
                  retakeButtonStyle: widget.buttonStyle.retakeButtonStyle,
                  actionButtonPadding: widget.buttonStyle.actionButtonPadding,
                  actionButtonWidth: widget.buttonStyle.actionButtonWidth,
                  actionButtonHeight: widget.buttonStyle.actionButtonHeight,
                  captureButtonWidth: widget.buttonStyle.captureButtonWidth,
                  captureButtonHeight: widget.buttonStyle.captureButtonHeight,
                  capturedImageNotifier: _capturedImageNotifier,
                  isLoadingNotifier: _isLoadingNotifier,
                  currentSideNotifier: _currentSideNotifier,
                  documentDataNotifier: _documentDataNotifier,
                  frameWidth: _updatedFrameWidth,
                  frameHeight: _updatedFrameHeight,
                  bottomFrameContainerHeight:
                      AppConstants.bottomFrameContainerHeight,
                  controller: _controller,
                  onManualCapture: _captureAndHandleImageUnified,
                  onSave: _handleSave,
                  onRetake: _handleRetake,
                  onNext: _switchToBackSide,
                  onPrevious: _switchToFrontSide,
                  onCameraSwitched: () async {
                    _isInitializedNotifier.value = false;
                    if (widget.enableAutoCapture) {
                      await _stopImageStream();
                    }

                    await _controller.switchCamera();
                    _isInitializedNotifier.value = true;

                    // Trigger auto focus at frame center after camera switch
                    final frameCenter = _calculateFrameCenter();
                    _controller.triggerAutoFocus(frameCenter);

                    if (widget.enableAutoCapture) {
                      await _startImageStream();
                    }
                  },
                  requireBothSides: widget.requireBothSides,
                ),

              // Touch to focus detector (placed at the top to capture all touch events)
              if (isInitialized && _controller.cameraController != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (TapDownDetails details) {
                      // Convert tap position to normalized coordinates (0.0-1.0)
                      final screenSize = MediaQuery.of(context).size;
                      final normalizedX =
                          details.globalPosition.dx / screenSize.width;
                      final normalizedY =
                          details.globalPosition.dy / screenSize.height;

                      debugPrint(
                        '[TouchToFocus] Tapped at screen: (${details.globalPosition.dx}, ${details.globalPosition.dy})',
                      );
                      debugPrint(
                        '[TouchToFocus] Normalized coordinates: ($normalizedX, $normalizedY)',
                      );

                      // Trigger focus at tapped position
                      _controller.triggerAutoFocus(
                        Offset(normalizedX, normalizedY),
                      );
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
            ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Start async disposal but don't await it here
    _disposeAsync();

    // Dispose sync stuff
    _controller.dispose();
    _documentDetectionService?.dispose();
    _progressAnimationController?.dispose();

    _isInitializedNotifier.dispose();
    _isLoadingNotifier.dispose();
    _capturedImageNotifier.dispose();
    _currentSideNotifier.dispose();
    _documentDataNotifier.dispose();
    _isDocumentAlignedNotifier.dispose();
    _detectionStatusNotifier.dispose();

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _autoFocusTimer?.cancel();
    _autoFocusTimer = null;

    super.dispose();
  }

  Future<void> _disposeAsync() async {
    debugPrint('[disposeAsync] Starting async disposal(非同期破棄を開始します)');

    try {
      // Stop image stream if active
      if (widget.enableAutoCapture) {
        await _stopImageStream();
      }

      // Release camera resources
      debugPrint('[disposeAsync] Releasing camera resources(カメラリソースを解放します)');
      await _controller.releaseCamera();
      debugPrint('[disposeAsync] Camera resources released(カメラリソースを解放しました)');
    } catch (e) {
      debugPrint(
        '[disposeAsync] Error during async disposal: $e(非同期破棄中にエラーが発生しました: $e)',
      );
    }
  }
}
