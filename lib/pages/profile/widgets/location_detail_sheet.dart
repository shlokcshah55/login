import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/utils/geo_types.dart';
import 'pinit_colors.dart';

class LocationDetailSheet extends StatefulWidget {
  final LocationModel location;

  const LocationDetailSheet({Key? key, required this.location})
      : super(key: key);

  @override
  State<LocationDetailSheet> createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  Map<String, dynamic>? _review;
  bool _reviewLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  Future<void> _loadReview() async {
    try {
      final review = await LocationReviewsHelper()
          .getLatestPublicReview(locationId: widget.location.locationId);
      if (mounted)
        setState(() {
          _review = review;
          _reviewLoaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _reviewLoaded = true);
    }
  }

  Future<void> _openGoogleMaps() async {
    final uri = widget.location.googleMapsUri;
    if (uri != null && uri.isNotEmpty) {
      final parsed = Uri.tryParse(uri);
      if (parsed != null && await canLaunchUrl(parsed)) {
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (widget.location.lat != null && widget.location.lng != null) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${widget.location.lat},${widget.location.lng}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebsite() async {
    final url = widget.location.website;
    if (url == null || url.isEmpty) return;
    final parsed = Uri.tryParse(url);
    if (parsed != null) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToHome() {
    Navigator.pop(context);
    context.read<NavigationProvider>().navigateToLocationOnMap(widget.location);
  }

  String? _getTodayHours() {
    final hours = widget.location.openingHoursText;
    if (hours == null || hours.isEmpty) return null;
    // Dart weekday: 1=Mon..7=Sun. Google hours: 0=Sun..6=Sat.
    final dayIndex = DateTime.now().weekday % 7;
    if (dayIndex < hours.length) return hours[dayIndex];
    return hours.first;
  }

  List<String> _getServes() {
    final loc = widget.location;
    final serves = <String>[];
    if (loc.displayCuisine != null) serves.add(loc.displayCuisine!);
    if (loc.servesBreakfast == true) serves.add('Breakfast');
    if (loc.servesBrunch == true) serves.add('Brunch');
    if (loc.servesLunch == true) serves.add('Lunch');
    if (loc.servesDinner == true) serves.add('Dinner');
    if (loc.servesCoffee == true) serves.add('Coffee');
    if (loc.servesCocktails == true) serves.add('Cocktails');
    if (loc.servesBeer == true) serves.add('Beer');
    if (loc.servesWine == true) serves.add('Wine');
    if (loc.servesVegetarianFood == true) serves.add('Vegetarian');
    return serves;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              _buildHandle(),
              _buildHeader(),
              const SizedBox(height: 12),
              _buildMiniMap(),
              const SizedBox(height: 20),
              _buildRatingRow(),
              const SizedBox(height: 16),
              _buildDivider(),
              _buildInfoRows(),
              _buildDivider(),
              _buildReviewSection(),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.location.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.location.vicinity != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.location.vicinity!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: PinitColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            color: PinitColors.primary,
            tooltip: 'View on map',
            onPressed: _navigateToHome,
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: PinitColors.textSecondary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap() {
    final lat = widget.location.lat;
    final lng = widget.location.lng;
    if (lat == null || lng == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 200,
          child: _LocationMiniMap(lat: lat, lng: lng),
        ),
      ),
    );
  }

  Widget _buildRatingRow() {
    final rating = widget.location.rating;
    final reviewCount = widget.location.userRatingsTotal;
    final priceLevel = widget.location.priceLevel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (rating != null) ...[
            ...List.generate(
                5,
                (i) => Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: i < rating.round()
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFE5E7EB),
                    )),
            const SizedBox(width: 6),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: PinitColors.textPrimary,
              ),
            ),
          ],
          if (reviewCount != null) ...[
            const SizedBox(width: 4),
            Text(
              '($reviewCount)',
              style: const TextStyle(
                fontSize: 13,
                color: PinitColors.textSecondary,
              ),
            ),
          ],
          const Spacer(),
          if (priceLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: PinitColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                List.filled(priceLevel, '\$').join(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Colors.grey[100]),
    );
  }

  Widget _buildInfoRows() {
    final todayHours = _getTodayHours();
    final serves = _getServes();
    final hasWebsite = widget.location.website?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.map_rounded,
            label: 'Google Maps',
            value: widget.location.vicinity ?? 'Open in Maps',
            onTap: _openGoogleMaps,
          ),
          if (hasWebsite)
            _InfoRow(
              icon: Icons.language_rounded,
              label: 'Website',
              value: widget.location.website!
                  .replaceFirst(RegExp(r'https?://'), '')
                  .split('/')
                  .first,
              onTap: _openWebsite,
            ),
          if (todayHours != null)
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Hours today',
              value: todayHours.contains(':')
                  ? todayHours.split(':').skip(1).join(':').trim()
                  : todayHours,
              trailing: widget.location.openNow != null
                  ? _OpenBadge(isOpen: widget.location.openNow!)
                  : null,
            ),
          if (serves.isNotEmpty)
            _InfoRow(
              icon: Icons.restaurant_rounded,
              label: 'Serves',
              value: serves.join(', '),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PinitColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (!_reviewLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_review == null)
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 14,
                color: PinitColors.textMuted,
              ),
            )
          else
            _buildReviewCard(_review!),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] as int?;
    final content = review['content'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rating != null)
            Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < rating
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFE5E7EB),
                      )),
            ),
          if (content != null && content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"$content"',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: PinitColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _timeAgo(createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: PinitColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }
}

// ── Mini Map ──────────────────────────────────────────────────────────────────

class _LocationMiniMap extends StatefulWidget {
  final double lat;
  final double lng;

  const _LocationMiniMap({required this.lat, required this.lng});

  @override
  State<_LocationMiniMap> createState() => _LocationMiniMapState();
}

class _LocationMiniMapState extends State<_LocationMiniMap> {
  mapbox.MapboxMap? _map;

  void _onMapCreated(mapbox.MapboxMap map) async {
    _map = map;
    await map.attribution.updateSettings(
      mapbox.AttributionSettings(enabled: false),
    );
    await map.setCamera(mapbox.CameraOptions(
      center: LatLng(widget.lat, widget.lng).toPoint(),
      zoom: 14.5,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        mapbox.MapWidget(
          cameraOptions: mapbox.CameraOptions(
            center: LatLng(widget.lat, widget.lng).toPoint(),
            zoom: 14.5,
          ),
          styleUri: 'mapbox://styles/srishlok/cmlpttggl000p01rz51whgzk9',
          onMapCreated: _onMapCreated,
          gestureRecognizers: const {},
        ),
        // Static pin overlay — no annotation manager needed
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded,
                  color: Color(0xFFEF4444), size: 36),
              SizedBox(height: 18), // visual offset so pin base hits center
            ],
          ),
        ),
      ],
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: PinitColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PinitColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: onTap != null
                          ? PinitColors.primary
                          : PinitColors.textPrimary,
                      fontWeight:
                          onTap != null ? FontWeight.w600 : FontWeight.w400,
                      decoration:
                          onTap != null ? TextDecoration.underline : null,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Open/Closed Badge ─────────────────────────────────────────────────────────

class _OpenBadge extends StatelessWidget {
  final bool isOpen;
  const _OpenBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOpen ? PinitColors.success : const Color(0xFFEF4444),
        ),
      ),
    );
  }
}
