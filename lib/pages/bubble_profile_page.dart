import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/chat/add_members_dialog.dart';

class BubbleProfilePage extends StatefulWidget {
  final Bubble chatGroup;

  const BubbleProfilePage({
    Key? key,
    required this.chatGroup,
  }) : super(key: key);

  @override
  _BubbleProfilePageState createState() => _BubbleProfilePageState();
}

class _BubbleProfilePageState extends State<BubbleProfilePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  mapbox.MapboxMap? mapController;
  mapbox.PointAnnotationManager? _annotationManager;
  List<MapMarkerData> _markerData = [];
  List<LocationModel> allMemberLocations = [];
  bool isLoading = true;
  
  // Local state for bubble data that can be updated
  late Bubble currentBubble;

  @override
  void initState() {
    super.initState();
    currentBubble = widget.chatGroup;
    _initializeAnimations();
    _loadAllMemberLocations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animationController.forward();
  }

  Future<void> _reloadBubbleData() async {
    try {
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      final updatedBubble = await supabaseProvider.bubbles
          .getBubbleById(widget.chatGroup.id);

      if (updatedBubble != null) {
        setState(() {
          currentBubble = updatedBubble;
        });
      }
    } catch (e) {
      print('Error reloading bubble data: $e');
    }
  }

  Future<void> _loadAllMemberLocations() async {
    setState(() => isLoading = true);

    try {
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      final locations = await supabaseProvider.bubbles
          .getAllMemberLocations(widget.chatGroup.id);

      setState(() {
        allMemberLocations = locations;
        isLoading = false;
        _createMarkers();
      });
    } catch (e) {
      print('Error loading member locations: $e');
      setState(() => isLoading = false);
    }
  }

  void _createMarkers() {
    _markerData = allMemberLocations.map((location) {
      return MapMarkerData(
        id: location.locationId.toString(),
        position: LatLng(location.lat!, location.lng!),
        imageBytes: const [], // default pin
        title: location.name,
        snippet: location.vicinity,
      );
    }).toList();
    _syncAnnotations();
  }

  Future<void> _syncAnnotations() async {
    final manager = _annotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    for (final m in _markerData) {
      await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: m.position.toPoint(),
          iconSize: 1.5,
          iconImage: 'marker-15', // built-in Mapbox marker icon
        ),
      );
    }
  }

  void _showLocationDetails(LocationModel location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLocationDetailsSheet(location),
    );
  }

  Widget _buildLocationDetailsSheet(LocationModel location) {
    final theme = Theme.of(context);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, 
                        size: 16, 
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location.vicinity!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (location.rating != null)
                    Row(
                      children: [
                        Icon(Icons.star, 
                          size: 20, 
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${location.rating}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (location.userRatingsTotal != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${location.userRatingsTotal} reviews)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (location.cuisine != null)
                    Chip(
                      label: Text(location.cuisine!),
                      backgroundColor: theme.primaryColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: theme.primaryColor),
                    ),
                  if (location.priceLevel != null)
                    Row(
                      children: [
                        Text(
                          'Price: ',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '\$' * location.priceLevel!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMapCreated(mapbox.MapboxMap controller) async {
    mapController = controller;
    _annotationManager = await controller.annotations.createPointAnnotationManager();
    if (allMemberLocations.isNotEmpty) {
      _syncAnnotations();
      _fitMarkersInView();
    }
  }

  Future<void> _fitMarkersInView() async {
    if (mapController == null || allMemberLocations.isEmpty) return;

    final locations = allMemberLocations;
    double minLat = locations.first.lat!;
    double maxLat = locations.first.lat!;
    double minLng = locations.first.lng!;
    double maxLng = locations.first.lng!;

    for (final location in locations) {
      minLat = minLat < location.lat! ? minLat : location.lat!;
      maxLat = maxLat > location.lat! ? maxLat : location.lat!;
      minLng = minLng < location.lng! ? minLng : location.lng!;
      maxLng = maxLng > location.lng! ? maxLng : location.lng!;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    final camera = await mapController!.cameraForCoordinateBounds(
      bounds.toCoordinateBounds(),
      mapbox.MbxEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
      null, null, null, null,
    );
    await mapController!.flyTo(camera, mapbox.MapAnimationOptions(duration: 500));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildStats(theme),
            Expanded(
              child: isLoading
                  ? _buildLoadingState(theme)
                  : _buildMapSection(theme),
            ),
            _buildMembersList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: theme.primaryColor),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 24,
            backgroundImage: currentBubble.groupAvatar.isNotEmpty
                ? NetworkImage(currentBubble.groupAvatar)
                : null,
            backgroundColor: theme.primaryColor.withOpacity(0.2),
            child: currentBubble.groupAvatar.isEmpty
                ? Icon(Icons.group, color: theme.primaryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentBubble.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentBubble.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _showAddMembersDialog();
            },
            icon: Icon(Icons.person_add, color: theme.primaryColor),
            tooltip: 'Add Members',
          ),
          IconButton(
            onPressed: () {
              // TODO: Show bubble options menu
            },
            icon: Icon(Icons.more_vert, color: theme.primaryColor),
          ),
        ],
      ),
    );
  }

  void _showAddMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMembersDialog(
        bubble: currentBubble,
        onMembersAdded: () async {
          // Reload the bubble data after members are added
          await _reloadBubbleData();
          await _loadAllMemberLocations();
        },
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            theme,
            icon: Icons.people,
            label: 'Members',
            value: currentBubble.memberCount.toString(),
            color: Colors.blue,
          ),
          _buildStatCard(
            theme,
            icon: Icons.location_on,
            label: 'Shared Pins',
            value: currentBubble.groupLocations.length.toString(),
            color: Colors.green,
          ),
          _buildStatCard(
            theme,
            icon: Icons.map,
            label: 'All Saved',
            value: allMemberLocations.length.toString(),
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading member locations...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(ThemeData theme) {
    if (allMemberLocations.isEmpty) {
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
                'No saved locations yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Members haven\'t saved any locations',
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
        child: mapbox.MapWidget(
          onMapCreated: _onMapCreated,
          cameraOptions: mapbox.CameraOptions(
            center: (allMemberLocations.isNotEmpty
                    ? LatLng(
                        allMemberLocations.first.lat!,
                        allMemberLocations.first.lng!,
                      )
                    : const LatLng(37.7749, -122.4194))
                .toPoint(),
            zoom: 12,
          ),
          styleUri: mapbox.MapboxStyles.LIGHT,
        ),
      ),
    );
  }

  Widget _buildMembersList(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Group Members',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  // TODO: Add member functionality
                },
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: currentBubble.memberAvatars.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: currentBubble.memberAvatars[index].isNotEmpty
                            ? NetworkImage(currentBubble.memberAvatars[index])
                            : null,
                        backgroundColor: theme.primaryColor.withOpacity(0.2),
                        child: currentBubble.memberAvatars[index].isEmpty
                            ? Icon(Icons.person, color: theme.primaryColor, size: 28)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Member ${index + 1}',
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
}