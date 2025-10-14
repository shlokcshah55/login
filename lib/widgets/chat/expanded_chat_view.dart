import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/chat_group_model.dart';

class ExpandedChatView extends StatefulWidget {
  final ChatGroupModel chatGroup;
  final VoidCallback onClose;

  const ExpandedChatView({
    Key? key,
    required this.chatGroup,
    required this.onClose,
  }) : super(key: key);

  @override
  _ExpandedChatViewState createState() => _ExpandedChatViewState();
}

class _ExpandedChatViewState extends State<ExpandedChatView>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  GoogleMapController? mapController;
  Set<Marker> markers = {};
  bool isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _createMarkers();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  void _createMarkers() {
    markers = widget.chatGroup.groupLocations.map((location) {
      return Marker(
        markerId: MarkerId(location.locationId.toString()),
        position: LatLng(location.lat, location.lng),
        infoWindow: InfoWindow(
          title: location.name,
          snippet: location.vicinity,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }).toSet();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    setState(() {
      isMapReady = true;
    });

    if (widget.chatGroup.groupLocations.isNotEmpty) {
      _fitMarkersInView();
    }
  }

  void _fitMarkersInView() {
    if (mapController == null || widget.chatGroup.groupLocations.isEmpty) return;

    final locations = widget.chatGroup.groupLocations;
    double minLat = locations.first.lat;
    double maxLat = locations.first.lat;
    double minLng = locations.first.lng;
    double maxLng = locations.first.lng;

    for (final location in locations) {
      minLat = minLat < location.lat ? minLat : location.lat;
      maxLat = maxLat > location.lat ? maxLat : location.lat;
      minLng = minLng < location.lng ? minLng : location.lng;
      maxLng = maxLng > location.lng ? maxLng : location.lng;
    }

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: GestureDetector(
        onTap: _handleClose,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping on the card
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: screenSize.width * 0.9,
                      height: screenSize.height * 0.8,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHeader(theme),
                          _buildGroupInfo(theme),
                          Expanded(
                            child: _buildMapSection(theme),
                          ),
                          _buildMembersList(theme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(widget.chatGroup.groupAvatar),
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            child: widget.chatGroup.groupAvatar.isEmpty
                ? Icon(Icons.group, color: theme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatGroup.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.chatGroup.memberCount} members • ${widget.chatGroup.groupLocations.length} locations',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _handleClose,
            icon: Icon(Icons.close, color: theme.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfo(ThemeData theme) {
    if (widget.chatGroup.description.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Text(
        widget.chatGroup.description,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMapSection(ThemeData theme) {
    if (widget.chatGroup.groupLocations.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No locations shared yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start sharing locations with your group!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: widget.chatGroup.groupLocations.isNotEmpty
                ? LatLng(
                    widget.chatGroup.groupLocations.first.lat,
                    widget.chatGroup.groupLocations.first.lng,
                  )
                : const LatLng(37.7749, -122.4194), // San Francisco default
            zoom: 12,
          ),
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Widget _buildMembersList(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Group Members',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.chatGroup.memberAvatars.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.chatGroup.memberAvatars[index].isNotEmpty
                            ? NetworkImage(widget.chatGroup.memberAvatars[index])
                            : null,
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        child: widget.chatGroup.memberAvatars[index].isEmpty
                            ? Icon(Icons.person, color: theme.primaryColor, size: 20)
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'User ${index + 1}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }
}