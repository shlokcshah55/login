import 'dart:async';
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/service.dart';
import 'package:login/themes/app_colors.dart';
import 'package:provider/provider.dart';

/// A popover widget that processes a URL and displays a loading animation
/// followed by the result.
class UrlProcessingPopover extends StatefulWidget {
  /// The URL to be processed
  final String url;

  /// The async function that processes the URL and returns location data
  final Future<Map<String, dynamic>> Function(String) onProcess;

  /// Optional callback when the popover is dismissed
  final VoidCallback? onDismiss;

  const UrlProcessingPopover({
    Key? key,
    required this.url,
    required this.onProcess,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<UrlProcessingPopover> createState() => _UrlProcessingPopoverState();
}

class _UrlProcessingPopoverState extends State<UrlProcessingPopover>
    with SingleTickerProviderStateMixin {
  ProcessingState _state = ProcessingState.loading;
  Map<String, dynamic>? _result;
  String? _error;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  final Set<int> _selectedIndices = {}; // Track selected location indices
  bool _isSaving = false;
  late SupabaseService _supabaseService;

  // Status message tracking
  String _statusMessage = 'Analyzing URL...';
  Timer? _statusTimer;
  final List<String> _statusMessages = [
    'Analyzing URL...',
    'Connecting to TikTok...',
    'Fetching video data...',
    'Extracting metadata...',
    'Analyzing video content...',
    'Finding locations...',
    'Processing location data...',
    'Almost there...',
  ];

  @override
  void initState() {
    super.initState();

    // Setup smooth progress animation that goes to 88% over 18 seconds
    // This accounts for typical 20-25 second processing time
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 18000),
    );

    // Use a custom curve that starts fast then slows down
    // This makes it feel like progress is being made, but slows as it gets harder
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOut,
      ),
    );

    // Start the progress animation
    _progressController.forward();

    // Cycle through status messages
    _startStatusCycle();

    _supabaseService = Provider.of<SupabaseService>(context, listen: false);

    // Start processing automatically
    _processUrl();
  }

  void _startStatusCycle() {
    int currentIndex = 0;

    _statusTimer = Timer.periodic(Duration(milliseconds: 300), (timer) {
      if (!mounted || _state != ProcessingState.loading) {
        timer.cancel();
        return;
      }

      final progress = _progressAnimation.value;

      // Update status based on progress milestones (8 messages)
      // Each message shows for roughly 12.5% of progress (~2.25 seconds)
      int newIndex = currentIndex;

      if (progress < 0.125) {
        newIndex = 0; // "Analyzing URL..."
      } else if (progress < 0.25) {
        newIndex = 1; // "Connecting to TikTok..."
      } else if (progress < 0.375) {
        newIndex = 2; // "Fetching video data..."
      } else if (progress < 0.50) {
        newIndex = 3; // "Extracting metadata..."
      } else if (progress < 0.625) {
        newIndex = 4; // "Analyzing video content..."
      } else if (progress < 0.75) {
        newIndex = 5; // "Finding locations..."
      } else if (progress < 0.875) {
        newIndex = 6; // "Processing location data..."
      } else {
        newIndex = 7; // "Almost there..."
      }

      if (newIndex != currentIndex) {
        setState(() => _statusMessage = _statusMessages[newIndex]);
        currentIndex = newIndex;
      }
    });
  }

  Future<void> _processUrl() async {
    setState(() {
      _state = ProcessingState.loading;
      _result = null;
      _error = null;
    });

    try {
      final result = await widget.onProcess(widget.url);
      if (mounted) {
        // Animate to 100% completion
        setState(() => _statusMessage = 'Complete!');
        await _progressController.animateTo(
          1.0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );

        // Small delay to show 100% before transitioning
        await Future.delayed(Duration(milliseconds: 200));

        if (mounted) {
          setState(() {
            _state = ProcessingState.completed;
            _result = result;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = ProcessingState.error;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _handleClose() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  /// Save selected locations to the database
  Future<void> _saveSelectedLocations() async {
    if (_result == null || _selectedIndices.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final locations = _result!['locations'] as List;

      for (int index in _selectedIndices) {
        final loc = locations[index];
        final locationModel = loc['location'] as LocationModel;

        // Save location using the Supabase service
       await _supabaseService.locations.saveLocation(
          locationModel,
          savedMethod: 'tiktok',
        );

        // TODO: Save video data
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Succesfully added locations'
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Close the popover
        _handleClose();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving locations: $e'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              Row(
                children: [
                  Icon(
                    Icons.link_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Processing URL',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: _handleClose,
                  ),
                ],
              ),
              SizedBox(height: 24),

              // URL Display
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.divider,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.url,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Content based on state
              if (_state == ProcessingState.loading) ...[
                _buildLoadingContent(),
              ] else if (_state == ProcessingState.completed) ...[
                _buildCompletedContent(),
              ] else if (_state == ProcessingState.error) ...[
                _buildErrorContent(),
              ],

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        SmoothProgressBar(
          animation: _progressAnimation,
        ),
        SizedBox(height: 12),
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            final percentage = (_progressAnimation.value * 100).toInt();
            return Text(
              '$percentage% complete',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompletedContent() {
    if (_result == null || _result!['locations'] == null) {
      return _buildErrorMessage('No locations found');
    }

    final locations = _result!['locations'] as List;

    if (locations.isEmpty) {
      return _buildErrorMessage('No locations extracted from this video');
    }

    // Select all locations by default
    if (_selectedIndices.isEmpty) {
      for (int i = 0; i < locations.length; i++) {
        _selectedIndices.add(i);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 28,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Found ${locations.length} Location${locations.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Scrollable list of locations
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 400),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: locations.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final loc = locations[index];
              final locationModel = loc['location'] as LocationModel;
              final videoData = loc['video_data'] as Map<String, dynamic>;
              final isSelected = _selectedIndices.contains(index);

              return _buildLocationCard(
                locationModel,
                videoData,
                index,
                isSelected,
              );
            },
          ),
        ),

        SizedBox(height: 16),

        // Add Selected Locations button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving || _selectedIndices.isEmpty
                ? null
                : _saveSelectedLocations,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: AppColors.divider,
            ),
            child: _isSaving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Add ${_selectedIndices.length} Location${_selectedIndices.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String message) {
    return Column(
      children: [
        Icon(Icons.info_outline, color: AppColors.textSecondary, size: 48),
        SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Close'),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(
    LocationModel location,
    Map<String, dynamic> videoData,
    int index,
    bool isSelected,
  ) {
    final author = videoData['author'] as String? ?? 'Unknown';
    final description = videoData['description'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 12),

            // Location info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Place name
                  Text(
                    location.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // Address
                  Text(
                    location.vicinity!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 8),

                  // Video author
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '@$author',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Rating if available
            if (location.rating != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 4),
                    Text(
                      location.rating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_rounded,
              color: AppColors.error,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.error.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            _error ?? 'An unknown error occurred',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _processUrl,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Smooth progress bar with shimmer effect
class SmoothProgressBar extends StatefulWidget {
  final Animation<double> animation;

  const SmoothProgressBar({
    Key? key,
    required this.animation,
  }) : super(key: key);

  @override
  State<SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.divider.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.animation, _shimmerController]),
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Filled progress
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.animation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
                // Shimmer overlay
                if (widget.animation.value < 1.0)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.animation.value,
                    child: CustomPaint(
                      painter: _ShimmerPainter(
                        shimmerProgress: _shimmerController.value,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for shimmer effect
class _ShimmerPainter extends CustomPainter {
  final double shimmerProgress;
  final Color color;

  _ShimmerPainter({
    required this.shimmerProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shimmerProgress * 3, 0),
        end: Alignment(-0.5 + shimmerProgress * 3, 0),
        colors: [
          color.withOpacity(0.0),
          color,
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) {
    return oldDelegate.shimmerProgress != shimmerProgress;
  }
}

/// Processing state enum
enum ProcessingState {
  loading,
  completed,
  error,
}

/// Placeholder async function that simulates URL processing
/// Replace this with your actual processing logic
Future<String> placeholderProcessingFunction(String url) async {
  // Simulate network delay (3-5 seconds)
  await Future.delayed(Duration(seconds: 3));

  // Simulate some processing and return a result
  return 'Successfully processed: $url\n\nMock data:\n- Extracted 5 items\n- Status: Complete\n- Processing time: 3.2s';
}
