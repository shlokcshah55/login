import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:provider/provider.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({Key? key}) : super(key: key);

  @override
  _AlertsPageState createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<LocationModel> _potentialTiktokVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPotentialLocations();
  }

  Future<void> _fetchPotentialLocations() async {
    final locationManager = Provider.of<LocationListManager>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    final locations = await locationManager.getSavedLocationsSinceLastOpened();
    
    setState(() {
      _potentialTiktokVideos = locations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPotentialLocations,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _potentialTiktokVideos.isEmpty 
            ? _buildEmptyState()
            : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'We\'ll notify you when we find potential TikTok videos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      itemCount: _potentialTiktokVideos.length,
      itemBuilder: (context, index) {
        final location = _potentialTiktokVideos[index];
        return NotificationItem(
          location: location,
          onAcknowledge: (value) {
            _handleAcknowledge(location.locationId, value);
          },
        );
      },
    );
  }

  void _handleAcknowledge(int locationId, bool value) async {
    final locationManager = Provider.of<LocationListManager>(context, listen: false);
    await locationManager.acknowledgeLocation(locationId, value);
    
    // Refresh the list after acknowledgment
    _fetchPotentialLocations();
  }
}

class NotificationItem extends StatelessWidget {
  final LocationModel location;
  final Function(bool) onAcknowledge;

  const NotificationItem({
    Key? key,
    required this.location,
    required this.onAcknowledge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Image circle
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
              child: Center(
                child: Icon(
                  Icons.location_on,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Potential TikTok video at ${location.vicinity}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons
            Row(
              children: [
                // Reject button
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.red,
                  onPressed: () => onAcknowledge(false),
                  tooltip: 'Reject',
                ),
                // Accept button
                IconButton(
                  icon: const Icon(Icons.check),
                  color: Colors.green,
                  onPressed: () => onAcknowledge(true),
                  tooltip: 'Accept',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}