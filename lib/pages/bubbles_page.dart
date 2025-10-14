import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/chat/expanded_chat_view.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:login/supabase_flutter/supabase_client.dart';

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
    setState(() => _isLoading = true);
    
    try {
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      final currentUser = SupabaseClientManager().client.auth.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _chatGroups = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch bubbles from Supabase
      final bubbles = await supabaseProvider.bubbleRepository.getUserBubbles(currentUser.id);
      
      setState(() {
        _chatGroups = bubbles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat groups: $e');
      setState(() {
        _chatGroups = [];
        _isLoading = false;
      });
    }
  }

  // Remove the _createMockLocations method as we're now using real data

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
                
                final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
                final currentUser = SupabaseClientManager().client.auth.currentUser;
                
                if (currentUser == null) return;
                
                final bubbleId = await supabaseProvider.bubbleRepository.createBubble(
                  name: nameController.text.trim(),
                  createdBy: currentUser.id,
                );
                
                Navigator.of(context).pop();
                
                if (bubbleId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bubble created successfully!')),
                  );
                  _loadChatGroups();
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