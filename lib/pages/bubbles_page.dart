import 'dart:async';

import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:provider/provider.dart';
import 'package:login/models/bubble.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/chat/expanded_bubble_view.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/providers/bubbles_provider.dart';
import 'package:login/widgets/profile/user_profile_dialog.dart';

class BubblesPage extends StatefulWidget {
  const BubblesPage({Key? key}) : super(key: key);

  @override
  _BubblesPageState createState() => _BubblesPageState();
}

class _BubblesPageState extends State<BubblesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late BubblesProvider _bubblesProvider;

  // Search related state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);

    // Initialize BubblesProvider
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    if (currentUser != null) {
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      _bubblesProvider = BubblesProvider(
        userId: currentUser.id,
        bubbleHelper: supabaseProvider.bubbles,
      );
      _bubblesProvider.initialize();
    }
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

  // Remove the _createMockLocations method as we're now using real data

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _bubblesProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showingSearch = _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;

    print('Building - showingSearch: $showingSearch, hasFocus: ${_searchFocusNode.hasFocus}, hasText: ${_searchController.text.isNotEmpty}, text: "${_searchController.text}"');

    return ChangeNotifierProvider.value(
      value: _bubblesProvider,
      child: Consumer<BubblesProvider>(
        builder: (context, bubblesProvider, child) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  _buildSearchField(theme),
                  if (!showingSearch) _buildHeader(theme),
                  Expanded(
                    child: showingSearch
                        ? _buildSearchResults(theme)
                        : bubblesProvider.isLoading
                            ? _buildLoadingState(theme)
                            : _buildChatsList(theme, bubblesProvider.bubbles),
                  ),
                ],
              ),
            ),
          );
        },
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
                onPressed: _showCreateBubbleDialog,
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

  void _showCreateBubbleDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Bubble'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter bubble name',
              labelText: 'Bubble Name',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
                final currentUser = SupabaseClientManager().client.auth.currentUser;
                
                if (currentUser == null) return;
                
                final bubbleId = await supabaseProvider.bubbles.createBubble(
                  name: nameController.text.trim(),
                  createdBy: currentUser.id,
                );
                
                Navigator.of(context).pop();

                if (bubbleId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bubble created successfully!')),
                  );
                  // Provider will automatically update via realtime subscription
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to create bubble')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
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

  Widget _buildChatsList(ThemeData theme, List<Bubble> chatGroups) {
    if (chatGroups.isEmpty) {
      return _buildEmptyState(theme);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            final provider = Provider.of<BubblesProvider>(context, listen: false);
            await provider.loadBubbles();
          },
          color: theme.primaryColor,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: chatGroups.length,
            itemBuilder: (context, index) {
              final chatGroup = chatGroups[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 100 * (index + 1)),
                child: ChatGroupTile(
                  bubble: chatGroup,
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
            onPressed: _showCreateBubbleDialog,
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

  void _openExpandedChatView(Bubble chatGroup) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExpandedChatView(
        bubble: chatGroup,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search users...',
          prefixIcon: Icon(Icons.search, color: theme.primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.primaryColor,
            child: Text(
              user.username![0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          title: Text(user.username!),
          subtitle: Text(user.email),
          onTap: () {
            _searchFocusNode.unfocus();
            _showUserProfileDialog(user);
          },
        );
      },
    );
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  void _onFocusChanged() {
    setState(() {});
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      final results = await supabaseProvider.searchUsers(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Error searching users: $e');
    }
  }

  void _showUserProfileDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(user: user),
    );
  }
}