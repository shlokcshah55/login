import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../animations/animation_builders.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_typography.dart';

class ProfilePhotoSelector extends StatefulWidget {
  // Required callbacks
  final Function(File) onPhotoSelected;
  final VoidCallback? onPhotoRemoved;

  // Optional customization
  final File? currentImage;
  final double size;
  final Color? borderColor;
  final String titleText;
  final String subtitleText;

  // Animation support
  final AnimationController? animationController;

  const ProfilePhotoSelector({
    super.key,
    required this.onPhotoSelected,
    this.onPhotoRemoved,
    this.currentImage,
    this.size = 180.0,
    this.borderColor,
    this.titleText = 'Add a profile picture',
    this.subtitleText = 'Help friends recognize you (optional)',
    this.animationController,
  });

  @override
  State<ProfilePhotoSelector> createState() => _ProfilePhotoSelectorState();
}

class _ProfilePhotoSelectorState extends State<ProfilePhotoSelector> {
  final ImagePicker _imagePicker = ImagePicker();
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  @override
  void dispose() {
    errorNotifier.dispose();
    super.dispose();
  }

  // Animation helpers
  Animation<Offset> _createFieldSlideAnimation() {
    if (widget.animationController == null) {
      return AlwaysStoppedAnimation(Offset.zero);
    }
    return AnimationBuilders.createFieldSlideAnimation(
        widget.animationController!);
  }

  Animation<double> _createFadeAnimation() {
    if (widget.animationController == null) {
      return const AlwaysStoppedAnimation(1.0);
    }
    return AnimationBuilders.createFadeAnimation(widget.animationController!);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        widget.onPhotoSelected(File(pickedFile.path));
      }
    } catch (e) {
      errorNotifier.value = 'Failed to pick image: $e';
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        widget.onPhotoSelected(File(pickedFile.path));
      }
    } catch (e) {
      errorNotifier.value = 'Failed to take photo: $e';
    }
  }

  void _removeImage() {
    widget.onPhotoRemoved?.call();
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: errorNotifier,
      builder: (context, error, _) {
        if (error == null) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.red.shade700),
                onPressed: () => errorNotifier.value = null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePicker() {
    final slideAnimation = _createFieldSlideAnimation();
    final fadeAnimation = _createFadeAnimation();

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.currentImage != null
                  ? Colors.transparent
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
              image: widget.currentImage != null
                  ? DecorationImage(
                      image: FileImage(widget.currentImage!),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: widget.borderColor ??
                    const Color(0xFF6A1B9A).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: widget.currentImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _removeImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.titleText.isNotEmpty) ...[
          Text(
            widget.titleText,
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        if (widget.subtitleText.isNotEmpty) ...[
          Text(
            widget.subtitleText,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],
        _buildErrorBanner(),
        _buildImagePicker(),
      ],
    );
  }
}
