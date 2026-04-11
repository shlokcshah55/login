import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/themes/app_typography.dart';

class AddToBubbleSheet extends StatefulWidget {
  const AddToBubbleSheet({
    super.key,
    required this.location,
  });

  final LocationModel location;

  @override
  State<AddToBubbleSheet> createState() => _AddToBubbleSheetState();
}

class _AddToBubbleSheetState extends State<AddToBubbleSheet> {
  final TextEditingController _noteController = TextEditingController();
  final Set<String> _selectedBubbleIds = <String>{};

  List<Bubble> _bubbles = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetchBubbles();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchBubbles() async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final bubbles = await SupabaseService().bubbles.getUserBubbles(user.id);
      bubbles
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) {
        setState(() {
          _bubbles = bubbles;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _selectedBubbleIds.isEmpty) return;

    final user = SupabaseClientManager().currentUser;
    if (user == null) return;

    setState(() => _sending = true);
    final note = _noteController.text.trim();
    var sentCount = 0;

    for (final bubbleId in _selectedBubbleIds) {
      try {
        final added = await SupabaseService().bubbles.addLocationToBubble(
              bubbleId: bubbleId,
              locationId: widget.location.locationId,
              addedBy: user.id,
              note: note.isEmpty ? null : note,
            );

        if (!added) {
          continue;
        }

        final messageId = await SupabaseService().messaging.sendMessage(
              bubbleId: bubbleId,
              content: note,
              messageType: 'location_share',
              metadata: {
                'location_name': widget.location.name,
              },
              locationId: widget.location.locationId,
            );

        if (messageId != null) {
          sentCount++;
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).pop(sentCount);
  }

  void _toggleBubble(String bubbleId) {
    setState(() {
      if (_selectedBubbleIds.contains(bubbleId)) {
        _selectedBubbleIds.remove(bubbleId);
      } else {
        _selectedBubbleIds.add(bubbleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: PinitColors.creamDeep,
          width: 1.5,
        ),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'SEND TO BUBBLES',
                style: AppTypography.sans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergineSoft,
                  letterSpacing: 1.32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Share this place.',
                style: AppTypography.brand(
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergineSoft,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: PinitColors.creamDeep,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _noteController,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergine,
                    height: 1.35,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Add a note for the bubble',
                    hintStyle: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PinitColors.mute,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                    ),
                  ),
                )
              else if (_bubbles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: PinitColors.creamDeep,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'You are not in any bubbles yet.',
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergineSoft,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.38,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _bubbles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final bubble = _bubbles[index];
                      final selected = _selectedBubbleIds.contains(bubble.id);
                      return _BubbleSelectionTile(
                        bubble: bubble,
                        selected: selected,
                        onTap: () => _toggleBubble(bubble.id),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap:
                        _sending || _selectedBubbleIds.isEmpty ? null : _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedBubbleIds.isEmpty
                            ? PinitColors.creamDeep
                            : PinitColors.aubergine,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _selectedBubbleIds.isEmpty
                              ? PinitColors.creamDeep
                              : PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: _selectedBubbleIds.isEmpty
                            ? null
                            : const [
                                BoxShadow(
                                  color: PinitColors.aubergine,
                                  blurRadius: 0,
                                  offset: Offset(3, 3),
                                ),
                              ],
                      ),
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PinitColors.cream,
                                  ),
                                ),
                              )
                            : Text(
                                _selectedBubbleIds.isEmpty
                                    ? 'SELECT A BUBBLE'
                                    : 'SEND TO ${_selectedBubbleIds.length} ${_selectedBubbleIds.length == 1 ? 'BUBBLE' : 'BUBBLES'}',
                                style: AppTypography.sans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w100,
                                  color: _selectedBubbleIds.isEmpty
                                      ? PinitColors.mute
                                      : PinitColors.cream,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomInset > 0 ? 6 : 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleSelectionTile extends StatelessWidget {
  const _BubbleSelectionTile({
    required this.bubble,
    required this.selected,
    required this.onTap,
  });

  final Bubble bubble;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? PinitColors.aubergine : PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: selected ? PinitColors.aubergine : PinitColors.creamDeep,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: selected ? PinitColors.black : PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(10, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bubble.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.brand(
                        fontSize: 20,
                        fontWeight: FontWeight.w100,
                        color: selected
                            ? PinitColors.cream
                            : PinitColors.aubergine,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${bubble.memberCount} member${bubble.memberCount == 1 ? '' : 's'} · ${bubble.groupLocations.length} pin${bubble.groupLocations.length == 1 ? '' : 's'}',
                      style: AppTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? PinitColors.cream.withValues(alpha: 0.84)
                            : PinitColors.aubergineSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selected ? PinitColors.cream : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? PinitColors.cream : PinitColors.aubergine,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: PinitColors.aubergine,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
