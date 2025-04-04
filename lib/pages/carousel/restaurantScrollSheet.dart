import 'package:flutter/material.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class RestaurantScrollSheet extends StatefulWidget {
  final LocationListManager locationListManager;
  final Function(LocationModel) onRouteRequested;

  const RestaurantScrollSheet({
    super.key,
    required this.locationListManager,
    required this.onRouteRequested,
  });

  @override
  State<RestaurantScrollSheet> createState() => _RestaurantScrollSheetState();
}

class _RestaurantScrollSheetState extends State<RestaurantScrollSheet> {
  final _pageController = PageController(viewportFraction: 0.92);
  final List<LocationModel> _locations = [];

  @override
  void initState() {
    super.initState();
    _locations.addAll(widget.locationListManager.currentItems.keys);
  }

  void _removeCard(int index) {
    setState(() {
      _locations.removeAt(index);
    });
    // Optional: Update provider if needed
    // widget.locationListManager.removeLocation(_locations[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _locations.length,
              itemBuilder: (context, index) {
                final location = _locations[index];
                return RestaurantCard(
                  location: location,
                  onNavigate: () => widget.onRouteRequested(location),
                  onRemove: () => _removeCard(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(
      width: 48,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[400],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class RestaurantCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onNavigate;
  final VoidCallback onRemove;

  const RestaurantCard({
    super.key,
    required this.location,
    required this.onNavigate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onNavigate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Material(
          borderRadius: BorderRadius.circular(24),
          elevation: 4,
          child: Stack(
            children: [
              _buildImage(),
              _buildGradientOverlay(),
              _buildContent(),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        color: Colors.grey[200],
        child: location.photoReference != null
            ? Image.network(
                'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=1000&photoreference=${location.photoReference}'
                '&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(child: CircularProgressIndicator(
                    value: progress.cumulativeBytesLoaded / 
                      (progress.expectedTotalBytes ?? 1),
                  ));
                },
              )
            : Center(child: Icon(Icons.restaurant, size: 60, color: Colors.grey[400])),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.4, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoPill(
                icon: Icons.star_rounded,
                value: location.rating?.toStringAsFixed(1) ?? '--',
                color: Colors.amber[400]!,
              ),
              const SizedBox(width: 12),
              _buildInfoPill(
                icon: Icons.favorite_rounded,
                value: '${location.savedCount}',
                color: Colors.red[400]!,
              ),
              if (location.priceLevel != null) ...[
                const SizedBox(width: 12),
                _buildInfoPill(
                  icon: Icons.attach_money_rounded,
                  value: List.generate(location.priceLevel!, (i) => '')
                      .join('\$'),
                  color: Colors.green[400]!,
                ),
              ],
            ],
          ),
          if (location.cuisine != null) ...[
            const SizedBox(height: 16),
            Text(
              location.cuisine!.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        children: [
          // Like button
          _buildActionButton(
            icon: Icons.favorite_rounded,
            color: Colors.red[400]!,
            onPressed: onRemove, // Assuming like action removes
          ),
          const SizedBox(height: 12),
          // Bin button
          _buildActionButton(
            icon: Icons.delete_rounded,
            color: Colors.grey[400]!,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}