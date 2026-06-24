import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final FocusNode? focusNode;
  final List<String> mentionMemberIds;
  final List<String> mentionMemberNames;
  final List<String> mentionMemberAvatarUrls;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.focusNode,
    this.mentionMemberIds = const [],
    this.mentionMemberNames = const [],
    this.mentionMemberAvatarUrls = const [],
  }) : super(key: key);

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  @override
  Widget build(BuildContext context) {
    final mentionState = _currentMentionState();
    final suggestions = _mentionSuggestions(mentionState?.query);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: PinitColors.cream.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: PinitColors.creamDeep,
            width: 1.5,
          ),
        ),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mentionState != null && suggestions.isNotEmpty) ...[
            _MentionSuggestions(
              suggestions: suggestions,
              onSelect: (member) => _insertMention(member, mentionState),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: PinitColors.creamDeep,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: AppTypography.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a message',
                      hintStyle: AppTypography.sans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: PinitColors.mute,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onTap: () => setState(() {}),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              widget.isSending
                  ? Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PinitColors.creamDeep,
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                PinitColors.aubergine),
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        color: PinitColors.aubergine,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _handleSend,
                        icon: const Icon(
                          FeatherIcons.arrowUp,
                          color: PinitColors.cream,
                          size: 18,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(52, 52),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  _MentionState? _currentMentionState() {
    final selection = widget.controller.selection;
    final cursor = selection.baseOffset;
    if (cursor < 0) return null;

    final text = widget.controller.text;
    final beforeCursor = text.substring(0, cursor);
    final atIndex = beforeCursor.lastIndexOf('@');
    if (atIndex == -1) return null;

    final query = beforeCursor.substring(atIndex + 1);
    if (query.contains(RegExp(r'\s'))) return null;

    return _MentionState(start: atIndex, end: cursor, query: query);
  }

  List<_MentionMember> _mentionSuggestions(String? query) {
    if (query == null) return const [];

    final normalizedQuery = query.toLowerCase();
    final members = <_MentionMember>[];
    for (var i = 0; i < widget.mentionMemberNames.length; i++) {
      final name = widget.mentionMemberNames[i].trim();
      if (name.isEmpty) continue;
      if (normalizedQuery.isNotEmpty &&
          !name.toLowerCase().contains(normalizedQuery)) {
        continue;
      }

      members.add(
        _MentionMember(
          id: i < widget.mentionMemberIds.length
              ? widget.mentionMemberIds[i]
              : 'member-$i',
          name: name,
          avatarUrl: i < widget.mentionMemberAvatarUrls.length
              ? widget.mentionMemberAvatarUrls[i]
              : '',
        ),
      );
    }

    return members.take(5).toList(growable: false);
  }

  void _insertMention(_MentionMember member, _MentionState mentionState) {
    final text = widget.controller.text;
    final replacement = '@${member.name} ';
    final nextText =
        text.replaceRange(mentionState.start, mentionState.end, replacement);
    final nextOffset = mentionState.start + replacement.length;

    widget.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    widget.focusNode?.requestFocus();
    setState(() {});
  }

  void _handleSend() {
    if (widget.controller.text.trim().isNotEmpty && !widget.isSending) {
      widget.onSend();
      setState(() {});
    }
  }
}

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({
    required this.suggestions,
    required this.onSelect,
  });

  final List<_MentionMember> suggestions;
  final ValueChanged<_MentionMember> onSelect;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 164),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions.map((member) {
              final initial = member.name[0].toUpperCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('mention_suggestion_${member.id}'),
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onSelect(member),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.creamDeep,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: PinitColors.aubergineSoft,
                            backgroundImage: member.avatarUrl.isNotEmpty
                                ? NetworkImage(member.avatarUrl)
                                : null,
                            child: member.avatarUrl.isEmpty
                                ? Text(
                                    initial,
                                    style: AppTypography.sans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: PinitColors.cream,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            member.name,
                            style: AppTypography.sans(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MentionState {
  const _MentionState({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

class _MentionMember {
  const _MentionMember({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String avatarUrl;
}
