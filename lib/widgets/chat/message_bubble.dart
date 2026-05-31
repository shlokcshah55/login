import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

import '../../models/message.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isFromCurrentUser;
  final bool showSenderInfo;
  final ValueChanged<MessageModel>? onLocationTap;
  final ValueChanged<MessageModel>? onDoubleTap;
  final ValueChanged<MessageModel>? onAvatarTap;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isFromCurrentUser,
    this.showSenderInfo = true,
    this.onLocationTap,
    this.onDoubleTap,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timestampColor = isFromCurrentUser
        ? PinitColors.cream.withValues(alpha: 0.72)
        : PinitColors.mute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromCurrentUser) ...[
            IgnorePointer(
              ignoring: !showSenderInfo,
              child: Opacity(
                opacity: showSenderInfo ? 1 : 0,
                child: _Avatar(
                  message: message,
                  onTap:
                      onAvatarTap == null ? null : () => onAvatarTap!(message),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isFromCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isFromCurrentUser && showSenderInfo)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      message.senderName,
                      style: AppTypography.sans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: GestureDetector(
                    onDoubleTap: onDoubleTap == null
                        ? null
                        : () => onDoubleTap!(message),
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      decoration: BoxDecoration(
                          color: isFromCurrentUser
                              ? PinitColors.aubergine
                              : PinitColors.creamSunk,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft:
                                Radius.circular(isFromCurrentUser ? 20 : 8),
                            bottomRight:
                                Radius.circular(isFromCurrentUser ? 8 : 20),
                          ),
                          border: Border.all(
                            color: isFromCurrentUser
                                ? PinitColors.aubergine
                                : PinitColors.creamDeep,
                            width: 1.5,
                          ),
                          boxShadow: isFromCurrentUser
                              ? const [
                                  BoxShadow(
                                    color: PinitColors.black,
                                    blurRadius: 0,
                                    offset: Offset(5, 5),
                                  ),
                                ]
                              : const [
                                  BoxShadow(
                                    color: PinitColors.aubergine,
                                    blurRadius: 0,
                                    offset: Offset(5, 5),
                                  ),
                                ]),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.locationId != null) ...[
                                  _SharedLocationCard(
                                    message: message,
                                    isFromCurrentUser: isFromCurrentUser,
                                    onTap: onLocationTap == null
                                        ? null
                                        : () => onLocationTap!(message),
                                  ),
                                  if (message.content.trim().isNotEmpty)
                                    const SizedBox(height: 10),
                                ],
                                if (message.locationId == null ||
                                    message.content.trim().isNotEmpty)
                                  Text(
                                    message.content.trim().isEmpty &&
                                            message.locationId != null
                                        ? 'Shared a place'
                                        : message.content,
                                    style: AppTypography.sans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isFromCurrentUser
                                          ? PinitColors.cream
                                          : PinitColors.aubergine,
                                      height: 1.35,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(message.createdAt),
                                  style: AppTypography.sans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: timestampColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: -6,
                            bottom: -6,
                            child: IgnorePointer(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 140),
                                switchInCurve: Curves.easeOutBack,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                                child: message.liked
                                    ? Icon(
                                        Icons.favorite_rounded,
                                        key: const ValueKey('liked'),
                                        size: 18,
                                        color: PinitColors.accent,
                                      )
                                    : const SizedBox(
                                        key: ValueKey('unliked'),
                                        width: 0,
                                        height: 0,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final hour = localDateTime.hour % 12 == 0 ? 12 : localDateTime.hour % 12;
    final minute = localDateTime.minute.toString().padLeft(2, '0');
    final period = localDateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.message,
    this.onTap,
  });

  final MessageModel message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('message_avatar_${message.id}'),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: PinitColors.cream,
          shape: BoxShape.circle,
          border: Border.all(
            color: PinitColors.creamDeep,
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: PinitColors.creamDeep,
          backgroundImage: message.senderAvatarUrl.isNotEmpty
              ? NetworkImage(message.senderAvatarUrl)
              : null,
          child: message.senderAvatarUrl.isEmpty
              ? Text(
                  message.senderName.isNotEmpty
                      ? message.senderName[0].toUpperCase()
                      : '?',
                  style: AppTypography.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _SharedLocationCard extends StatelessWidget {
  const _SharedLocationCard({
    required this.message,
    required this.isFromCurrentUser,
    this.onTap,
  });

  final MessageModel message;
  final bool isFromCurrentUser;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final location = message.location;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PinitColors.creamDeep,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14.5),
              ),
              child: Ink(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14.5),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            height: 104,
                            width: double.infinity,
                            color: PinitColors.creamDeep,
                            child: location?.imageUrl != null &&
                                    location!.imageUrl!.isNotEmpty
                                ? Image.network(
                                    location.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _LocationFallback(
                                      title: location.name,
                                    ),
                                  )
                                : _LocationFallback(
                                    title: location?.name ?? 'Shared place',
                                  ),
                          ),
                          if (onTap != null)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      PinitColors.cream.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: PinitColors.creamDeep,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  'OPEN',
                                  style: AppTypography.sans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: PinitColors.aubergine,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHARED PLACE',
                            style: AppTypography.sans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergineSoft,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            location?.name ?? 'Place unavailable',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.aubergine,
                              letterSpacing: -0.8,
                              height: 1.15,
                            ),
                          ),
                          if ((location?.vicinity?.trim().isNotEmpty ??
                                  false) ||
                              location?.displayCuisine != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (location?.vicinity?.trim().isNotEmpty ??
                                    false)
                                  location!.vicinity!.trim(),
                                if (location?.displayCuisine != null)
                                  location!.displayCuisine!,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.sans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: PinitColors.mute,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationFallback extends StatelessWidget {
  const _LocationFallback({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinitColors.creamDeep,
      padding: const EdgeInsets.all(14),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.brand(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
