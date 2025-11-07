import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/profile/user_card.dart';
import 'package:provider/provider.dart';

class FindFriendsSection extends StatefulWidget {
  final ThemeData theme;

  const FindFriendsSection({
    Key? key,
    required this.theme,
  }) : super(key: key);

  @override
  State<FindFriendsSection> createState() => _FindFriendsSectionState();
}

class _FindFriendsSectionState extends State<FindFriendsSection> {
  List<UserModel> _suggestedUsers = [];
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchSuggestedUsers();
  }

  Future<void> _fetchSuggestedUsers() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService = Provider.of<SupabaseService>(context, listen: false);
      final users = await supabaseService.users.getSuggestedUsers();
      if (mounted) {
        setState(() {
          _suggestedUsers = users;
        });
      }
    } catch (e) {
      print("Error fetching suggested users: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.person_add_outlined, color: widget.theme.primaryColor, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Find Friends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_suggestedUsers.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: widget.theme.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: widget.theme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Finding amazing people...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_suggestedUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No suggestions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for friend recommendations!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Show either 3 users or all based on expanded state
    final displayCount = _isExpanded ? _suggestedUsers.length : 3;
    final usersToShow = _suggestedUsers.take(displayCount).toList();

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: usersToShow.length,
          itemBuilder: (context, index) {
            return UserCard(user: usersToShow[index]);
          },
        ),
        if (_suggestedUsers.length > 3 && !_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _isExpanded = true;
                });
              },
              icon: const Icon(Icons.add_circle_outline),
              label: Text('View ${_suggestedUsers.length - 3} more'),
              style: TextButton.styleFrom(
                foregroundColor: widget.theme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}
