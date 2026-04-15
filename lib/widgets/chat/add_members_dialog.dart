import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:provider/provider.dart';

import '../../supabase/service.dart';

@visibleForTesting
List<UserModel> filterAddableBubbleFriends({
  required Iterable<UserModel> friends,
  required Set<String> existingMemberIds,
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return friends.where((friend) {
    final userId = friend.supabaseId;
    if (userId == null || existingMemberIds.contains(userId)) {
      return false;
    }

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableValues = [
      friend.name,
      friend.username,
      friend.email,
    ];

    return searchableValues.any(
      (value) => value != null && value.toLowerCase().contains(normalizedQuery),
    );
  }).toList();
}

class AddMembersDialog extends StatefulWidget {
  final Bubble bubble;
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
    setState(() {
      _filteredFriends = filterAddableBubbleFriends(
        friends: _allFriends,
        existingMemberIds: widget.bubble.memberIds.toSet(),
        query: _searchController.text,
      );
    });
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Provider.of<SupabaseService>(context, listen: false);
      final friends = await supabase.users.getFriends();
      final availableFriends = filterAddableBubbleFriends(
        friends: friends,
        existingMemberIds: widget.bubble.memberIds.toSet(),
      );

      if (!mounted) return;
      setState(() {
        _allFriends = availableFriends;
        _filteredFriends = availableFriends;
      });
    } catch (e) {
      print('Error loading friends: $e');
    } finally {
      if (!mounted) return;
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
          content: Text(
            'Added ${_selectedUserIds.length} member(s) to ${widget.bubble.name}',
          ),
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
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(UserModel friend, bool shouldSelect) {
    final userId = friend.supabaseId;
    if (userId == null) return;

    setState(() {
      if (shouldSelect) {
        _selectedUserIds.add(userId);
      } else {
        _selectedUserIds.remove(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.dmSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: PinitColors.aubergine,
    );
    final bodyStyle = GoogleFonts.dmSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: PinitColors.mute,
    );
    final selectedCount = _selectedUserIds.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.76,
        ),
        decoration: const BoxDecoration(
          color: PinitColors.cream,
          border: Border.fromBorderSide(
            BorderSide(color: PinitColors.aubergine, width: 1.5),
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(6, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                decoration: const BoxDecoration(
                  color: PinitColors.creamSunk,
                  border: Border(
                    bottom: BorderSide(color: PinitColors.creamDeep),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Friends', style: titleStyle),
                          const SizedBox(height: 4),
                          Text(
                            'Pull people into ${widget.bubble.name}',
                            style: bodyStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: PinitColors.aubergine,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                        cursorColor: PinitColors.aubergine,
                        decoration: InputDecoration(
                          hintText: 'Search by name or email',
                          hintStyle: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: PinitColors.mute,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: PinitColors.aubergineSoft,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: PinitColors.aubergineSoft,
                                  ),
                                  onPressed: _searchController.clear,
                                )
                              : null,
                          filled: true,
                          fillColor: PinitColors.creamSunk,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: PinitColors.creamDeep,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: PinitColors.aubergine,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: selectedCount == 0
                            ? Align(
                                key: const ValueKey('helper'),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Choose who to add',
                                  style: bodyStyle,
                                ),
                              )
                            : Align(
                                key: const ValueKey('selected'),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PinitColors.aubergine.withValues(
                                      alpha: 0.08,
                                    ),
                                    border: Border.all(
                                      color: PinitColors.aubergine.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$selectedCount selected',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: PinitColors.aubergine,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: PinitColors.aubergine,
                                ),
                              )
                            : _filteredFriends.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.person_search_rounded,
                                          size: 44,
                                          color: PinitColors.aubergineSoft,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          _searchController.text.isEmpty
                                              ? 'No friends to add'
                                              : 'No matches found',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: PinitColors.aubergine,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _searchController.text.isEmpty
                                              ? 'Your whole circle is already in here.'
                                              : 'Try a different name or email.',
                                          style: bodyStyle,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _filteredFriends.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final friend = _filteredFriends[index];
                                      final userId = friend.supabaseId;
                                      final isSelected = userId != null
                                          ? _selectedUserIds.contains(userId)
                                          : false;
                                      final displayName =
                                          friend.name ?? friend.email;
                                      final initial = displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?';

                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          onTap: userId == null
                                              ? null
                                              : () => _toggleSelection(
                                                    friend,
                                                    !isSelected,
                                                  ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? PinitColors.creamSunk
                                                  : PinitColors.cream,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: isSelected
                                                    ? PinitColors.aubergine
                                                    : PinitColors.creamDeep,
                                                width: isSelected ? 1.4 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 22,
                                                  backgroundColor:
                                                      PinitColors.aubergineSoft,
                                                  backgroundImage:
                                                      friend.profileImageUrl !=
                                                              null
                                                          ? NetworkImage(
                                                              friend
                                                                  .profileImageUrl!,
                                                            )
                                                          : null,
                                                  child:
                                                      friend.profileImageUrl ==
                                                              null
                                                          ? Text(
                                                              initial,
                                                              style: GoogleFonts
                                                                  .dmSans(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    PinitColors
                                                                        .cream,
                                                              ),
                                                            )
                                                          : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        displayName,
                                                        style:
                                                            GoogleFonts.dmSans(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: PinitColors
                                                              .aubergine,
                                                        ),
                                                      ),
                                                      if (friend.name != null)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 2),
                                                          child: Text(
                                                            friend.email,
                                                            style: bodyStyle,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: userId == null
                                                      ? null
                                                      : (value) =>
                                                          _toggleSelection(
                                                            friend,
                                                            value ?? false,
                                                          ),
                                                  activeColor:
                                                      PinitColors.aubergine,
                                                  checkColor: PinitColors.cream,
                                                  side: const BorderSide(
                                                    color: PinitColors
                                                        .aubergineSoft,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedCount == 0 || _isLoading
                              ? null
                              : _addSelectedMembers,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: PinitColors.aubergine,
                            foregroundColor: PinitColors.cream,
                            disabledBackgroundColor: PinitColors.creamDeep,
                            disabledForegroundColor: PinitColors.mute,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: PinitColors.cream,
                                  ),
                                )
                              : Text(
                                  'Add $selectedCount Member${selectedCount == 1 ? '' : 's'}',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
