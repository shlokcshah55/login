import 'package:flutter/material.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/chat/expanded_chat_view.dart';
import 'package:login/supabase_flutter/models/location_model.dart';

class BubblesPage extends StatefulWidget {
  @override
  _BubblesPageState createState() => _BubblesPageState();
}

class _BubblesPageState extends State<BubblesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  List<ChatGroupModel> _chatGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadChatGroups();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  Future<void> _loadChatGroups() async {
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Create mock location data
    final mockLocations = _createMockLocations();
    
    // Create mock chat groups with locations
    final mockChatGroups = [
      ChatGroupModel(
        id: '1',
        name: 'SF Foodies 🍕',
        lastMessage: 'Found an amazing pizza place!',
        lastMessageTime: '2 min',
        memberCount: 8,
        memberAvatars: [
          'https://i.pravatar.cc/150?img=1',
          'https://i.pravatar.cc/150?img=2',
          'https://i.pravatar.cc/150?img=3',
          'https://i.pravatar.cc/150?img=4',
        ],
        groupAvatar: 'https://i.pravatar.cc/150?img=10',
        isOnline: true,
        unreadCount: 3,
        groupLocations: mockLocations.take(4).toList(),
        description: 'Discovering the best food spots in San Francisco together!',
        memberIds: ['user1', 'user2', 'user3', 'user4', 'user5', 'user6', 'user7', 'user8'],
      ),
      ChatGroupModel(
        id: '2',
        name: 'Beach Vibes 🌊',
        lastMessage: 'Perfect sunset at Ocean Beach!',
        lastMessageTime: '15 min',
        memberCount: 5,
        memberAvatars: [
          'https://i.pravatar.cc/150?img=5',
          'https://i.pravatar.cc/150?img=6',
          'https://i.pravatar.cc/150?img=7',
        ],
        groupAvatar: 'https://i.pravatar.cc/150?img=11',
        isOnline: false,
        unreadCount: 0,
        groupLocations: mockLocations.skip(4).take(3).toList(),
        description: 'Chasing waves and sunsets along the California coast',
        memberIds: ['user1', 'user9', 'user10', 'user11', 'user12'],
      ),
      ChatGroupModel(
        id: '3',
        name: 'Night Owls 🦉',
        lastMessage: 'Late night coffee run anyone?',
        lastMessageTime: '1 hr',
        memberCount: 12,
        memberAvatars: [
          'https://i.pravatar.cc/150?img=8',
          'https://i.pravatar.cc/150?img=9',
          'https://i.pravatar.cc/150?img=12',
          'https://i.pravatar.cc/150?img=13',
        ],
        groupAvatar: 'https://i.pravatar.cc/150?img=14',
        isOnline: true,
        unreadCount: 7,
        groupLocations: mockLocations.skip(7).take(5).toList(),
        description: 'For those who come alive when the sun goes down',
        memberIds: ['user1', 'user13', 'user14', 'user15', 'user16', 'user17', 'user18', 'user19', 'user20', 'user21', 'user22', 'user23'],
      ),
      ChatGroupModel(
        id: '4',
        name: 'Adventure Squad 🏔️',
        lastMessage: 'Who\'s ready for hiking this weekend?',
        lastMessageTime: '3 hr',
        memberCount: 6,
        memberAvatars: [
          'https://i.pravatar.cc/150?img=14',
          'https://i.pravatar.cc/150?img=15',
          'https://i.pravatar.cc/150?img=16',
        ],
        groupAvatar: 'https://i.pravatar.cc/150?img=17',
        isOnline: false,
        unreadCount: 1,
        groupLocations: mockLocations.skip(12).take(2).toList(),
        description: 'Exploring the great outdoors, one trail at a time',
        memberIds: ['user1', 'user24', 'user25', 'user26', 'user27', 'user28'],
      ),
      ChatGroupModel(
        id: '5',
        name: 'Study Buddies 📚',
        lastMessage: 'Group study session at the library tomorrow?',
        lastMessageTime: '5 hr',
        memberCount: 4,
        memberAvatars: [
          'https://i.pravatar.cc/150?img=17',
          'https://i.pravatar.cc/150?img=18',
        ],
        groupAvatar: 'https://i.pravatar.cc/150?img=19',
        isOnline: true,
        unreadCount: 0,
        groupLocations: [],
        description: 'Conquering exams together, one study session at a time',
        memberIds: ['user1', 'user29', 'user30', 'user31'],
      ),
    ];

    setState(() {
      _chatGroups = mockChatGroups;
      _isLoading = false;
    });
  }

  List<LocationModel> _createMockLocations() {
    return [
      // SF Foodies locations
      LocationModel(
        locationId: 1,
        name: 'Tony\'s Little Star Pizza',
        vicinity: '846 Divisadero St, San Francisco',
        lat: 37.7749,
        lng: -122.4194,
        createdAt: DateTime.now(),
        cuisine: 'Italian',
        rating: 4.5,
        userRatingsTotal: 150,
        priceLevel: 2,
      ),
      LocationModel(
        locationId: 2,
        name: 'Tartine Bakery',
        vicinity: '600 Guerrero St, San Francisco',
        lat: 37.7599,
        lng: -122.4241,
        createdAt: DateTime.now(),
        cuisine: 'Bakery',
        rating: 4.8,
        userRatingsTotal: 320,
        priceLevel: 2,
      ),
      LocationModel(
        locationId: 3,
        name: 'Swan Oyster Depot',
        vicinity: '1517 Polk St, San Francisco',
        lat: 37.7917,
        lng: -122.4211,
        createdAt: DateTime.now(),
        cuisine: 'Seafood',
        rating: 4.7,
        userRatingsTotal: 980,
        priceLevel: 3,
      ),
      LocationModel(
        locationId: 4,
        name: 'Blue Bottle Coffee',
        vicinity: '66 Mint St, San Francisco',
        lat: 37.7857,
        lng: -122.4041,
        createdAt: DateTime.now(),
        cuisine: 'Coffee',
        rating: 4.3,
        userRatingsTotal: 245,
        priceLevel: 2,
      ),
      
      // Beach Vibes locations
      LocationModel(
        locationId: 5,
        name: 'Ocean Beach',
        vicinity: 'Great Hwy, San Francisco',
        lat: 37.7590,
        lng: -122.5107,
        createdAt: DateTime.now(),
        rating: 4.2,
        userRatingsTotal: 1250,
      ),
      LocationModel(
        locationId: 6,
        name: 'Baker Beach',
        vicinity: 'Golden Gate National Recreation Area',
        lat: 37.7937,
        lng: -122.4844,
        createdAt: DateTime.now(),
        rating: 4.6,
        userRatingsTotal: 890,
      ),
      LocationModel(
        locationId: 7,
        name: 'Crissy Field',
        vicinity: '603 Mason St, San Francisco',
        lat: 37.8021,
        lng: -122.4662,
        createdAt: DateTime.now(),
        rating: 4.5,
        userRatingsTotal: 567,
      ),
      
      // Night Owls locations
      LocationModel(
        locationId: 8,
        name: 'The Phoenix',
        vicinity: '811 Valencia St, San Francisco',
        lat: 37.7580,
        lng: -122.4213,
        createdAt: DateTime.now(),
        cuisine: 'Bar',
        rating: 4.4,
        userRatingsTotal: 423,
        priceLevel: 2,
      ),
      LocationModel(
        locationId: 9,
        name: 'DNA Lounge',
        vicinity: '375 11th St, San Francisco',
        lat: 37.7713,
        lng: -122.4123,
        createdAt: DateTime.now(),
        cuisine: 'Nightclub',
        rating: 4.1,
        userRatingsTotal: 234,
        priceLevel: 3,
      ),
      LocationModel(
        locationId: 10,
        name: 'Philz Coffee',
        vicinity: '3101 24th St, San Francisco',
        lat: 37.7529,
        lng: -122.4141,
        createdAt: DateTime.now(),
        cuisine: 'Coffee',
        rating: 4.6,
        userRatingsTotal: 678,
        priceLevel: 2,
      ),
      LocationModel(
        locationId: 11,
        name: 'The Chapel',
        vicinity: '777 Valencia St, San Francisco',
        lat: 37.7583,
        lng: -122.4210,
        createdAt: DateTime.now(),
        cuisine: 'Music Venue',
        rating: 4.3,
        userRatingsTotal: 345,
        priceLevel: 2,
      ),
      LocationModel(
        locationId: 12,
        name: 'Ritual Coffee Roasters',
        vicinity: '1026 Valencia St, San Francisco',
        lat: 37.7588,
        lng: -122.4207,
        createdAt: DateTime.now(),
        cuisine: 'Coffee',
        rating: 4.5,
        userRatingsTotal: 567,
        priceLevel: 2,
      ),
      
      // Adventure Squad locations
      LocationModel(
        locationId: 13,
        name: 'Lands End',
        vicinity: 'Lands End Lookout, San Francisco',
        lat: 37.7849,
        lng: -122.5052,
        createdAt: DateTime.now(),
        rating: 4.8,
        userRatingsTotal: 1234,
      ),
      LocationModel(
        locationId: 14,
        name: 'Twin Peaks',
        vicinity: '501 Twin Peaks Blvd, San Francisco',
        lat: 37.7544,
        lng: -122.4477,
        createdAt: DateTime.now(),
        rating: 4.7,
        userRatingsTotal: 2345,
      ),
    ];
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
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(theme)
                  : _buildChatsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            'Bubbles',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Implement create new group
                },
                icon: Icon(
                  Icons.add_circle,
                  color: theme.primaryColor,
                  size: 28,
                ),
              ),
            ],
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
            'Loading your bubbles...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList(ThemeData theme) {
    if (_chatGroups.isEmpty) {
      return _buildEmptyState(theme);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadChatGroups,
          color: theme.primaryColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _chatGroups.length,
            itemBuilder: (context, index) {
              final chatGroup = _chatGroups[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 100 * (index + 1)),
                child: ChatGroupTile(
                  chatGroup: chatGroup,
                  onTap: () => _openExpandedChatView(chatGroup),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No bubbles yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with your friends!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Implement create first group
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Bubble'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExpandedChatView(ChatGroupModel chatGroup) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExpandedChatView(
        chatGroup: chatGroup,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}