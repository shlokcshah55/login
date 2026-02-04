import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:provider/provider.dart';
import 'package:login/models/bubble.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/chat/expanded_bubble_view.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/providers/bubbles_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/pages/bubble_messaging_page.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);

    // Initialize BubblesProvider
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    if (currentUser != null) {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
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
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
    final bool showingSearch =
        _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;

    return ChangeNotifierProvider.value(
      value: _bubblesProvider,
      child: Consumer<BubblesProvider>(
        builder: (context, bubblesProvider, child) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  if (!showingSearch) _buildModernHeader(theme),
                  _buildSearchField(theme),
                  Expanded(
                    child: showingSearch
                        ? _buildSearchResults(theme)
                        : bubblesProvider.isLoading
                            ? _buildLoadingState(theme)
                            : _buildBubblesList(theme, bubblesProvider.bubbles),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated bubble icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bubble_chart_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bubbles',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Your shared spaces',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Create bubble button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showCreateBubbleDialog,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateBubbleDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create New Bubble',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a shared space for your group',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Bubble name',
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.bubble_chart_rounded,
                        color: theme.primaryColor),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: theme.primaryColor, width: 2),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                // Description field
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'What\'s this bubble about?',
                    labelText: 'Description (optional)',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.description_outlined,
                          color: theme.primaryColor),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: theme.primaryColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) return;

                          final supabaseProvider = Provider.of<SupabaseService>(
                              context,
                              listen: false);
                          final currentUser =
                              SupabaseClientManager().client.auth.currentUser;

                          if (currentUser == null) return;

                          final bubbleId =
                              await supabaseProvider.bubbles.createBubble(
                            name: nameController.text.trim(),
                            createdBy: currentUser.id,
                          );

                          Navigator.of(context).pop();

                          if (bubbleId != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle,
                                        color: Colors.white),
                                    const SizedBox(width: 12),
                                    const Text('Bubble created successfully!'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Failed to create bubble'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Create Bubble',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your bubbles...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubblesList(ThemeData theme, List<Bubble> bubbles) {
    if (bubbles.isEmpty) {
      return _buildEmptyState(theme);
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async {
            final provider =
                Provider.of<BubblesProvider>(context, listen: false);
            await provider.loadBubbles();
          },
          color: theme.primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: bubbles.length,
            itemBuilder: (context, index) {
              final bubble = bubbles[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 100)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: ChatGroupTile(
                  bubble: bubble,
                  onTap: () => _openExpandedChatView(bubble),
                  onOpenChat: () => _openGroupChat(bubble),
                  onActivateBubble: () => _activateBubble(bubble),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor.withOpacity(0.1),
                    theme.primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bubble_chart_rounded,
                size: 60,
                color: theme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Bubbles Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first bubble to start sharing\nplaces with your friends!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _showCreateBubbleDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Create Your First Bubble',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openExpandedChatView(Bubble bubble) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExpandedChatView(
        bubble: bubble,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _openGroupChat(Bubble bubble) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BubbleMessagingPage(bubble: bubble),
      ),
    );
  }

  void _activateBubble(Bubble bubble) {
    final bubbleModeProvider =
        Provider.of<BubbleModeProvider>(context, listen: false);
    final navigationProvider =
        Provider.of<NavigationProvider>(context, listen: false);

    bubbleModeProvider.requestBubbleMode(bubble);
    navigationProvider.navigateToTab(0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bubble_chart_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Text('Activating ${bubble.name}...'),
          ],
        ),
        backgroundColor: theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData get theme => Theme.of(context);

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search users to add...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child:
                Icon(Icons.search_rounded, color: Colors.grey[400], size: 22),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.unfocus();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search_rounded,
                  size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              'No users found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  user.username![0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              user.username!,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              user.email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              _searchFocusNode.unfocus();
              _showUserProfileDialog(user);
            },
          ),
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
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
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
