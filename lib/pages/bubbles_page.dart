import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/bubbles/bubbles_page_view.dart';
import 'package:login/providers/bubbles_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/chat/expanded_bubble_view.dart';
import 'package:login/widgets/profile/user_profile_dialog.dart';
import 'package:provider/provider.dart';

class BubblesPage extends StatefulWidget {
  const BubblesPage({super.key});

  @override
  State<BubblesPage> createState() => _BubblesPageState();
}

class _BubblesPageState extends State<BubblesPage> {
  static const _roseAccent = Color(0xFFD95D85);

  BubblesProvider? _bubblesProvider;

  @override
  void initState() {
    super.initState();
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final supabaseService = context.read<SupabaseService>();
    _bubblesProvider = BubblesProvider(
      userId: currentUser.id,
      bubbleHelper: supabaseService.bubbles,
    );
    _bubblesProvider!.initialize();
  }

  @override
  void dispose() {
    _bubblesProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubblesProvider = _bubblesProvider;
    if (bubblesProvider == null) {
      return _buildSignedOutState(context);
    }

    return ChangeNotifierProvider.value(
      value: bubblesProvider,
      child: Consumer<BubblesProvider>(
        builder: (context, provider, _) {
          return BubblesPageView(
            bubbles: provider.bubbles,
            isLoading: provider.isLoading,
            errorText: provider.error,
            onRefresh: provider.loadBubbles,
            onCreateBubble: _showCreateBubbleDialog,
            onSearchPeople: _searchPeople,
            onBubbleTap: _openExpandedChatView,
            onPersonTap: _showUserProfileDialog,
          );
        },
      ),
    );
  }

  Widget _buildSignedOutState(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFE1E8),
                        Color(0xFFFFF0DB),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.bubble_chart_rounded,
                    size: 42,
                    color: _roseAccent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Sign in to view your bubbles',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5E3340),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<UserModel>> _searchPeople(String query) {
    return context.read<SupabaseService>().searchUsers(query);
  }

  void _openExpandedChatView(Bubble bubble) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ExpandedChatView(
        bubble: bubble,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showUserProfileDialog(UserModel user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => UserProfileDialog(user: user),
    );
  }

  void _showCreateBubbleDialog() {
    final nameController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBF8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD5DD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Create a bubble',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5C3340),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a playful shared space for plans, chats, and saved pins.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8C6C79),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: _inputDecoration(
                    label: 'Bubble name',
                    hint: 'Weekend brunch crew',
                    icon: Icons.bubble_chart_rounded,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8C6C79),
                          side: const BorderSide(color: Color(0xFFF3D7E0)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => _handleCreateBubble(
                          context: sheetContext,
                          name: nameController.text.trim(),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _roseAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Create Bubble'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      nameController.dispose();
    });
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _roseAccent),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFF2D9E2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFF2D9E2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _roseAccent, width: 1.5),
      ),
    );
  }

  Future<void> _handleCreateBubble({
    required BuildContext context,
    required String name,
  }) async {
    if (name.isEmpty) {
      return;
    }

    final supabaseService = this.context.read<SupabaseService>();
    final currentUser = SupabaseClientManager().client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final bubbleId = await supabaseService.bubbles.createBubble(
      name: name,
      createdBy: currentUser.id,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();

    final messenger = ScaffoldMessenger.of(this.context);
    if (bubbleId != null) {
      final provider = _bubblesProvider;
      if (provider != null) {
        await provider.loadBubbles();
      }
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Bubble created successfully'),
          backgroundColor: _roseAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Couldn\'t create that bubble'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }
  }
}
