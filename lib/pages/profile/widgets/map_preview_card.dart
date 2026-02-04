import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'pinit_colors.dart';

/// Non-interactive map snapshot showing their most-saved pins
/// Tapping opens full map filtered to this user
class MapPreviewCard extends StatelessWidget {
  final List<LocationModel> savedPins;
  final bool isFullView;

  const MapPreviewCard({
    Key? key,
    required this.savedPins,
    this.isFullView = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(20, 16, 20, isFullView ? 0 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map container
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(20),
              bottom: isFullView ? Radius.zero : const Radius.circular(20),
            ),
            child: Stack(
              children: [
                // Placeholder map (replace with actual map widget)
                Container(
                  height: isFullView ? 400 : 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF5F3EF),
                        const Color(0xFFEDE9E3),
                      ],
                    ),
                  ),
                  child: CustomPaint(
                    painter: _MapPatternPainter(),
                    child: Stack(
                      children: [
                        // Sample pin markers
                        ..._buildSamplePins(),
                      ],
                    ),
                  ),
                ),

                // Gradient overlay (only for preview)
                if (!isFullView)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: const BoxDecoration(
                        gradient: PinitColors.mapOverlayGradient,
                      ),
                    ),
                  ),

                // Tap indicator
                if (!isFullView)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: PinitColors.elevatedShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 16,
                              color: PinitColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View ${savedPins.length} pins on map',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PinitColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: PinitColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Full view info
          if (isFullView)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${savedPins.length} places saved',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mostly in East London • Coffee & Wine focused',
                    style: const TextStyle(
                      fontSize: 14,
                      color: PinitColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSamplePins() {
    // Sample pin positions (would be real coordinates in production)
    final pinData = [
      {'left': 0.25, 'top': 0.3, 'type': 'coffee'},
      {'left': 0.55, 'top': 0.45, 'type': 'wine'},
      {'left': 0.35, 'top': 0.6, 'type': 'restaurant'},
      {'left': 0.7, 'top': 0.25, 'type': 'coffee'},
      {'left': 0.45, 'top': 0.75, 'type': 'burger'},
      {'left': 0.8, 'top': 0.55, 'type': 'restaurant'},
    ];

    return pinData.asMap().entries.map((entry) {
      final pin = entry.value;
      return Positioned(
        left: (pin['left'] as double) * 300,
        top: (pin['top'] as double) * 150,
        child: _PinMarker(type: pin['type'] as String),
      );
    }).toList();
  }
}

class _PinMarker extends StatelessWidget {
  final String type;

  const _PinMarker({required this.type});

  @override
  Widget build(BuildContext context) {
    final emoji = _getEmoji(type);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: PinitColors.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  String _getEmoji(String type) {
    switch (type) {
      case 'coffee':
        return '☕';
      case 'wine':
        return '🍷';
      case 'burger':
        return '🍔';
      case 'restaurant':
        return '🍽️';
      default:
        return '📍';
    }
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw subtle grid pattern for map feel
    const spacing = 40.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }

    // Draw some "roads"
    final roadPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.5),
      roadPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.4, size.height),
      roadPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.8, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
