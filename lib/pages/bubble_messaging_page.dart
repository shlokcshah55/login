import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bubble.dart';
import '../models/message.dart';
import '../pages/profile/other_user_profile_page.dart';
import '../pages/profile/widgets/pinit_colors.dart';
import '../providers/messaging_provider.dart';
import '../supabase/service.dart';
import '../themes/app_typography.dart';
import '../utils/route_open_guard.dart';
import '../widgets/home/expanded_location_card.dart';
import '../widgets/chat/message_input.dart';
import '../widgets/chat/message_list.dart';
import '../supabase/helpers/notifications.dart';

class BubbleMessagingPage extends StatefulWidget {
  final Bubble bubble;
  final MessagingProvider? provider;
  final BubbleMessageView initialView;
  final Future<void> Function(String userId)? onOpenUserProfile;

  const BubbleMessagingPage({
    Key? key,
    required this.bubble,
    this.provider,
    this.initialView = BubbleMessageView.messages,
    this.onOpenUserProfile,
  }) : super(key: key);

  @override
  State<BubbleMessagingPage> createState() => _BubbleMessagingPageState();
}

class _BubbleMessagingPageState extends State<BubbleMessagingPage> {
  late MessagingProvider _provider;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  BubbleMessageView _activeView = BubbleMessageView.messages;

  @override
  void initState() {
    super.initState();
    _activeView = widget.initialView;
    _provider = widget.provider ??
        MessagingProvider(
          bubbleId: widget.bubble.id,
          messagingHelper: SupabaseService().messaging,
          notificationsHelper: NotificationsHelper(),
        );
    _provider.initialize();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        resizeToAvoidBottomInset: false,
        body: Consumer<MessagingProvider>(
          builder: (context, provider, child) {
            final visibleMessages = _activeView == BubbleMessageView.pins
                ? provider.messages
                    .where((message) => message.locationId != null)
                    .toList()
                : provider.messages;

            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    PinitColors.cream,
                    Color(0xFFF7EFE8),
                    PinitColors.cream,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _MessagingHeader(
                      bubble: widget.bubble,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: provider.isLoading && provider.messages.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  PinitColors.aubergine,
                                ),
                              ),
                            )
                          : provider.error != null && provider.messages.isEmpty
                              ? _ErrorState(
                                  error: provider.error ?? 'Unknown error',
                                  onRetry: provider.loadMessages,
                                )
                              : Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: Opacity(
                                          opacity: 0.5,
                                          child: Column(
                                            children: [
                                              const SizedBox(height: 24),
                                              _BackdropBlob(
                                                alignment: Alignment.topRight,
                                                color: PinitColors.creamDeep,
                                                size: 164,
                                              ),
                                              const Spacer(),
                                              _BackdropBlob(
                                                alignment: Alignment.bottomLeft,
                                                color: PinitColors.accent
                                                    .withValues(alpha: 0.08),
                                                size: 208,
                                              ),
                                              const SizedBox(height: 28),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        _ConversationMeta(
                                          pinCount: provider.messages
                                              .where(
                                                (message) =>
                                                    message.locationId != null,
                                              )
                                              .length,
                                          activeView: _activeView,
                                          onViewChanged: (view) {
                                            if (_activeView == view) return;
                                            setState(() {
                                              _activeView = view;
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Listener(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onPointerMove: (_) =>
                                                _dismissKeyboard(),
                                            child: MessageList(
                                              messages: visibleMessages,
                                              scrollController:
                                                  _scrollController,
                                              isLoadingMore:
                                                  provider.isLoadingMore,
                                              hasMore: provider.hasMore,
                                              currentUserId:
                                                  provider.currentUserId,
                                              onLoadMore: () =>
                                                  provider.loadMoreMessages(),
                                              emptyTitle: _activeView ==
                                                      BubbleMessageView.pins
                                                  ? 'No shared places yet'
                                                  : 'No messages yet',
                                              emptySubtitle: _activeView ==
                                                      BubbleMessageView.pins
                                                  ? 'When someone sends a place into this bubble, it will land here as a tappable pin.'
                                                  : 'Break the silence and drop the first plan, pin, or opinion.',
                                              onLocationTap: _handleLocationTap,
                                              onMessageAvatarTap:
                                                  _handleOpenUserProfile,
                                              onScrollStart: _dismissKeyboard,
                                              onMessageDoubleTap:
                                                  widget.bubble.memberCount == 2
                                                      ? (message) {
                                                          provider
                                                              .toggleMessageLiked(
                                                            message,
                                                          );
                                                        }
                                                      : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                    ),
                    AnimatedPadding(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(bottom: keyboardInset),
                      child: MessageInput(
                        controller: _messageController,
                        focusNode: _focusNode,
                        isSending: provider.isSending,
                        mentionMemberIds: widget.bubble.memberIds,
                        mentionMemberNames: widget.bubble.memberNames,
                        mentionMemberAvatarUrls: widget.bubble.memberAvatars,
                        onSend: _handleSendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleSendMessage() async {
    final content = _messageController.text;
    if (content.trim().isEmpty) return;

    _messageController.clear();

    final success = await _provider.sendMessage(content);

    if (success && _scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleLocationTap(MessageModel message) {
    final location = message.location;
    if (location == null) return;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  void _dismissKeyboard() {
    if (!_focusNode.hasFocus) return;
    _focusNode.unfocus();
  }

  Future<void> _handleOpenUserProfile(MessageModel message) async {
    final userId = message.senderId.trim();
    if (userId.isEmpty) return;

    if (widget.onOpenUserProfile != null) {
      await widget.onOpenUserProfile!(userId);
      return;
    }

    try {
      final user = await SupabaseService().users.getUserProfileById(userId);
      if (!mounted || user == null) return;

      final userKey = user.supabaseId ?? user.email;
      await RouteOpenGuard.run<void>(
        'other-user-profile:$userKey',
        () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => OtherUserProfilePage(user: user),
          ),
        ),
      );
    } catch (_) {}
  }
}

enum BubbleMessageView {
  pins,
  messages,
}

class _MessagingHeader extends StatelessWidget {
  const _MessagingHeader({
    required this.bubble,
    required this.onBack,
  });

  final Bubble bubble;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
                boxShadow: PinitColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: PinitColors.creamSunk,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PinitColors.creamDeep,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: PinitColors.creamDeep,
                      backgroundImage: bubble.groupAvatar.isNotEmpty
                          ? NetworkImage(bubble.groupAvatar)
                          : null,
                      child: bubble.groupAvatar.isEmpty
                          ? const Icon(
                              Icons.group_rounded,
                              color: PinitColors.aubergine,
                              size: 20,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BUBBLE CHAT',
                          style: AppTypography.sans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergineSoft,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bubble.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.brand(
                            fontSize: 24,
                            fontWeight: FontWeight.w100,
                            letterSpacing: 1.4,
                            color: PinitColors.aubergine,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${bubble.memberCount} member${bubble.memberCount == 1 ? '' : 's'}',
                          style: AppTypography.sans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationMeta extends StatelessWidget {
  const _ConversationMeta({
    required this.pinCount,
    required this.activeView,
    required this.onViewChanged,
  });

  final int pinCount;
  final BubbleMessageView activeView;
  final ValueChanged<BubbleMessageView> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _MetaPill(
            label: '$pinCount pins',
            filled: activeView == BubbleMessageView.pins,
            onTap: () => onViewChanged(BubbleMessageView.pins),
          ),
          const SizedBox(width: 8),
          _MetaPill(
            label: 'Messages',
            filled: activeView == BubbleMessageView.messages,
            onTap: () => onViewChanged(BubbleMessageView.messages),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      scale: filled ? 1 : 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: filled ? PinitColors.aubergine : PinitColors.creamSunk,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: filled ? PinitColors.aubergine : PinitColors.creamDeep,
                width: 1.2,
              ),
              boxShadow: filled ? PinitColors.cardShadow : null,
            ),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.sans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: filled ? PinitColors.cream : PinitColors.aubergine,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            shape: BoxShape.circle,
            border: Border.all(
              color: PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  const _BackdropBlob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: PinitColors.creamDeep,
            width: 1.5,
          ),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: PinitColors.aubergine,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load the chat',
              style: AppTypography.brand(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: PinitColors.aubergine,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.sans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PinitColors.aubergineSoft,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: PinitColors.aubergine,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'TRY AGAIN',
                    style: AppTypography.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.cream,
                      letterSpacing: 1.2,
                    ),
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
