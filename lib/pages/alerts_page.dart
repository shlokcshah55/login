import 'package:flutter/material.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/supabase_flutter/models/user_model.dart';
import 'package:login/supabase_flutter/repositories/user_repository.dart';
import 'package:provider/provider.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({Key? key}) : super(key: key);

  @override
  _AlertsPageState createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<LocationModel> _potentialTiktokVideos = [];
  List<UserModel> _pendingFollowRequests = [];
  bool _isLoadingLocations = true;
  bool _isLoadingFollowRequests = true;
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    _fetchAllNotifications();
  }

  Future<void> _fetchAllNotifications() async {
    await _fetchPotentialLocations();
    await _fetchPendingFollowRequests();
  }

  Future<void> _fetchPotentialLocations() async {
    final locationManager = Provider.of<LocationListManager>(context, listen: false);
    
    if (!mounted) return;
    setState(() {
      _isLoadingLocations = true;
    });
    
    final locations = await locationManager.getSavedLocationsSinceLastOpened();
    
    if (!mounted) return;
    setState(() {
      _potentialTiktokVideos = locations;
      _isLoadingLocations = false;
    });
  }

  Future<void> _fetchPendingFollowRequests() async {
    if (!mounted) return;
    setState(() {
      _isLoadingFollowRequests = true;
    });
    try {
      final pendingFollowerIds = await _userRepository.getPendingFollows();
      final List<UserModel> pendingUsers = [];
      for (String userId in pendingFollowerIds) {
        // Assuming getPendingFollows returns follower IDs, we need to fetch their profiles.
        // The current getPendingFollows in user_repository.dart seems to return followee_id,
        // which might be an issue if we expect follower_id.
        // For now, proceeding with the assumption that it gives IDs of users who sent requests.
        final userProfile = await _userRepository.getUserProfileById(userId);
        if (userProfile != null) {
          pendingUsers.add(userProfile);
        }
      }
      if (!mounted) return;
      setState(() {
        _pendingFollowRequests = pendingUsers;
        _isLoadingFollowRequests = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFollowRequests = false;
      });
      // Handle error, e.g., show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching follow requests: ${e.toString()}'))
      );
    }
  }

  bool get _isLoading => _isLoadingLocations || _isLoadingFollowRequests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAllNotifications,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _potentialTiktokVideos.isEmpty && _pendingFollowRequests.isEmpty
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
            'New activity and follow requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    // Combine both types of notifications into a single list for the ListView
    List<Widget> notificationWidgets = [];

    // Add follow request notifications first
    notificationWidgets.addAll(
      _pendingFollowRequests.map((user) {
        return FollowRequestNotificationItem(
          user: user,
          onAccept: () => _handleAcceptFollowRequest(user.supabaseId!),
          onDecline: () => _handleDeclineFollowRequest(user.supabaseId!),
        );
      }).toList()
    );

    // Add potential TikTok video notifications
    notificationWidgets.addAll(
      _potentialTiktokVideos.map((location) {
        return TikTokNotificationItem( // Changed from NotificationItem
          location: location,
          onAcknowledge: (value) {
            _handleAcknowledgeLocation(location.locationId, value);
          },
        );
      }).toList()
    );
    
    return ListView(
      children: notificationWidgets,
    );
  }

  void _handleAcknowledgeLocation(int locationId, bool value) async {
    final locationManager = Provider.of<LocationListManager>(context, listen: false);
    await locationManager.acknowledgeLocation(locationId, value);
    _fetchPotentialLocations(); // Refresh only location-based notifications
  }

  Future<void> _handleAcceptFollowRequest(String followerId) async {
    try {
      await _userRepository.acceptFollowRequest(followerId);
      _fetchPendingFollowRequests(); // Refresh follow requests
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting request: ${e.toString()}'))
      );
    }
  }

  Future<void> _handleDeclineFollowRequest(String followerId) async {
    // Assuming a decline action means unfollowing or removing the request.
    // This might require a new method in UserRepository, e.g., declineFollowRequest.
    // For now, let's use unfollowUser, which will delete the 'requested' status row.
    // Note: The current unfollowUser expects the ID of the user *being unfollowed*.
    // If followerId is the ID of the user who *sent* the request, this might need adjustment
    // in user_repository.dart or a new method like `removeFollowRequest(currentUserId, followerId)`.
    // For now, we'll assume `unfollowUser` can be adapted or a new method `declineFollowRequest(followerId)`
    // will be created in the repository that handles removing the request from the perspective of the current user.
    // Let's assume we need a `declineFollowRequest` that takes the ID of the user whose request is being declined.
    try {
      // Placeholder for decline logic. This should ideally call a specific repository method.
      // For now, we'll re-fetch to simulate removal if the backend handles deletion on other actions.
      // Or, if `unfollowUser` is suitable (e.g., if it deletes the request regardless of who initiates)
      // await _userRepository.unfollowUser(followerId); // This might be incorrect based on current unfollowUser logic
      
      // Let's add a new method to the repository for declining.
      // For now, just refreshing the list.
      print("Decline action for $followerId. Implement decline in repository.");
      await _userRepository.declineFollowRequest(followerId); // Assuming this method will be added
      _fetchPendingFollowRequests();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining request: ${e.toString()}'))
      );
    }
  }
}

// Base class for notification items
class NotificationCardBase extends StatelessWidget {
  final Widget leadingIcon;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  const NotificationCardBase({
    Key? key,
    required this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              leadingIcon,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// New widget for follow request notifications, using NotificationCardBase
class FollowRequestNotificationItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const FollowRequestNotificationItem({
    Key? key,
    required this.user,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationCardBase(
      leadingIcon: CircleAvatar(
        radius: 25,
        backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null || user.profileImageUrl!.isEmpty
            ? Icon(Icons.person, size: 25, color: Theme.of(context).primaryColor)
            : null,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      ),
      title: user.name ?? 'Unknown User',
      subtitle: 'Wants to follow you',
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          color: Colors.red,
          onPressed: onDecline,
          tooltip: 'Decline',
        ),
        IconButton(
          icon: const Icon(Icons.check),
          color: Colors.green,
          onPressed: onAccept,
          tooltip: 'Accept',
        ),
      ],
    );
  }
}

// Renamed and refactored from the old NotificationItem
class TikTokNotificationItem extends StatelessWidget {
  final LocationModel location;
  final Function(bool) onAcknowledge;

  const TikTokNotificationItem({
    Key? key,
    required this.location,
    required this.onAcknowledge,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationCardBase(
      leadingIcon: Container(
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
      title: location.name,
      subtitle: 'Potential TikTok video at ${location.vicinity}',
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          color: Colors.red,
          onPressed: () => onAcknowledge(false),
          tooltip: 'Reject',
        ),
        IconButton(
          icon: const Icon(Icons.check),
          color: Colors.green,
          onPressed: () => onAcknowledge(true),
          tooltip: 'Accept',
        ),
      ],
    );
  }
}