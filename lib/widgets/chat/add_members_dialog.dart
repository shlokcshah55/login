import 'package:flutter/material.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/models/users.dart';
import 'package:provider/provider.dart';
import '../../supabase/service.dart';

class AddMembersDialog extends StatefulWidget {
  final ChatGroupModel bubble;
  final VoidCallback onMembersAdded;

  const AddMembersDialog({
    Key? key,
    required this.bubble,
    required this.onMembersAdded,
  }) : super(key: key);

  @override
  State<AddMembersDialog> createState() => _AddMembersDialogState();
}

class _AddMembersDialogState extends State<AddMembersDialog> {
  List<UserModel> _allFriends = [];
  List<UserModel> _filteredFriends = [];
  final Set<String> _selectedUserIds = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredFriends = _allFriends;
      });
    } else {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      final results = await supabase.users.searchUsers(query);
      
      // Filter out current members
      final currentMemberIds = widget.bubble.memberIds.toSet();
      final filteredResults = results.where((user) => 
        !currentMemberIds.contains(user.supabaseId)
      ).toList();

      setState(() {
        _filteredFriends = filteredResults;
      });
    } catch (e) {
      print('Error searching users: $e');
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      final friends = await supabase.users.getFriends();
      
      // Filter out current members
      final currentMemberIds = widget.bubble.memberIds.toSet();
      final availableFriends = friends.where((friend) => 
        !currentMemberIds.contains(friend.supabaseId)
      ).toList();

      setState(() {
        _allFriends = availableFriends;
        _filteredFriends = availableFriends;
      });
    } catch (e) {
      print('Error loading friends: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      
      for (final userId in _selectedUserIds) {
        await supabase.bubbles.addMemberToBubble(
          bubbleId: widget.bubble.id,
          userId: userId,
        );
      }

      widget.onMembersAdded();
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_selectedUserIds.length} member(s) to ${widget.bubble.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding members: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Members',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 16),

            // Selected count
            if (_selectedUserIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedUserIds.length} selected',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Friends list
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                              ? 'No friends to add'
                              : 'No results found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = _filteredFriends[index];
                        final isSelected = _selectedUserIds.contains(friend.supabaseId);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true && friend.supabaseId != null) {
                                _selectedUserIds.add(friend.supabaseId!);
                              } else if (friend.supabaseId != null) {
                                _selectedUserIds.remove(friend.supabaseId!);
                              }
                            });
                          },
                          title: Text(
                            friend.name ?? friend.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: friend.name != null
                            ? Text(friend.email)
                            : null,
                          secondary: CircleAvatar(
                            backgroundImage: friend.profileImageUrl != null
                              ? NetworkImage(friend.profileImageUrl!)
                              : null,
                            child: friend.profileImageUrl == null
                              ? Text(
                                  (friend.name ?? friend.email).substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                          ),
                          activeColor: Theme.of(context).primaryColor,
                        );
                      },
                    ),
            ),

            // Add button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedUserIds.isEmpty || _isLoading
                  ? null
                  : _addSelectedMembers,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Add ${_selectedUserIds.length} Member${_selectedUserIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

