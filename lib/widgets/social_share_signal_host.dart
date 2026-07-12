import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/notifications/base_notification.dart';
import 'package:login/models/notifications/social_post_review_notification.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/services/notification_surface_visibility.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/social_share_presentation_store.dart';
import 'package:login/services/social_share_signal_controller.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/profile/notifications_popover.dart';

typedef NotificationSource = List<BaseNotification> Function();
typedef UserIdSource = String? Function();
typedef MarkNotificationRead = Future<void> Function(String id);
typedef RefreshNotifications = Future<void> Function();

/// Displays at most one non-blocking social-share result above app content.
class SocialShareSignalHost extends StatefulWidget {
  SocialShareSignalHost({
    super.key,
    required this.child,
    NotificationSource? notificationSource,
    Stream<BaseNotification>? notificationStream,
    UserIdSource? userIdSource,
    SocialSharePresentationStore? presentationStore,
    MarkNotificationRead? markRead,
    RefreshNotifications? refreshNotifications,
    ValueListenable<bool>? notificationsVisible,
    this.onOpenSignal,
    this.successDuration = const Duration(seconds: 6),
  })  : notificationSource =
            notificationSource ?? (() => FCMService().notifications),
        notificationStream =
            notificationStream ?? FCMService().notificationStream,
        userIdSource =
            userIdSource ?? (() => SupabaseClientManager().currentUser?.id),
        presentationStore = presentationStore ?? SocialSharePresentationStore(),
        markRead = markRead ?? FCMService().markAsRead,
        refreshNotifications =
            refreshNotifications ?? FCMService().refreshFromDB,
        notificationsVisible = notificationsVisible ??
            NotificationSurfaceVisibility.instance.visible;

  final Widget child;
  final NotificationSource notificationSource;
  final Stream<BaseNotification> notificationStream;
  final UserIdSource userIdSource;
  final SocialSharePresentationStore presentationStore;
  final MarkNotificationRead markRead;
  final RefreshNotifications refreshNotifications;
  final ValueListenable<bool> notificationsVisible;
  final ValueChanged<SocialShareSignal>? onOpenSignal;
  final Duration successDuration;

  @override
  State<SocialShareSignalHost> createState() => _SocialShareSignalHostState();
}

class _SocialShareSignalHostState extends State<SocialShareSignalHost>
    with WidgetsBindingObserver {
  StreamSubscription<BaseNotification>? _subscription;
  Timer? _dismissTimer;
  SocialShareSignal? _signal;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.notificationsVisible.addListener(_handleSurfaceVisibilityChanged);
    _subscription = widget.notificationStream.listen(
      (_) => unawaited(_scan(aggregate: false)),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_scan(aggregate: true)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshAndScan());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationsVisible.removeListener(_handleSurfaceVisibilityChanged);
    _subscription?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAndScan() async {
    await widget.refreshNotifications();
    await _scan(aggregate: true);
  }

  void _handleSurfaceVisibilityChanged() {
    if (!widget.notificationsVisible.value) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_signal != null && mounted) setState(() => _signal = null);
    unawaited(_markAllCurrentPresented());
  }

  Future<void> _markAllCurrentPresented() async {
    final userId = widget.userIdSource();
    if (userId == null || userId.isEmpty) return;
    final presented = await widget.presentationStore.presentedIds(userId);
    final pending = SocialShareSignalController.next(
      widget.notificationSource(),
      presentedIds: presented,
      aggregate: true,
    );
    if (pending == null) return;
    await widget.presentationStore.markPresented(
      userId,
      pending.notificationIds,
    );
  }

  Future<void> _scan({required bool aggregate}) async {
    if (_scanning || _signal != null) return;
    final userId = widget.userIdSource();
    if (userId == null || userId.isEmpty) return;
    _scanning = true;
    try {
      final presented = await widget.presentationStore.presentedIds(userId);
      final signal = SocialShareSignalController.next(
        widget.notificationSource(),
        presentedIds: presented,
        aggregate: aggregate,
      );
      if (signal == null || !mounted) return;
      await widget.presentationStore.markPresented(
        userId,
        signal.notificationIds,
      );
      if (!mounted) return;
      if (widget.notificationsVisible.value) return;
      setState(() => _signal = signal);
      _dismissTimer = Timer(widget.successDuration, () {
        unawaited(_dismiss(scanNext: true));
      });
    } finally {
      _scanning = false;
    }
  }

  Future<void> _dismiss({required bool scanNext}) async {
    final signal = _signal;
    if (signal == null) return;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (mounted) setState(() => _signal = null);
    if (scanNext) await _scan(aggregate: false);
  }

  Future<void> _open() async {
    final signal = _signal;
    if (signal == null) return;
    await _markAllCurrentPresented();
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (!mounted) return;
    setState(() => _signal = null);
    final override = widget.onOpenSignal;
    if (override != null) {
      override(signal);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const NotificationsPopover(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 16,
          right: 16,
          top: 10 + MediaQuery.paddingOf(context).top,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.16),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _signal == null
                ? const SizedBox.shrink(key: ValueKey('no-social-signal'))
                : _SignalCard(
                    key: ValueKey(_signal!.notificationIds.join(':')),
                    signal: _signal!,
                    onTap: () => unawaited(_open()),
                    onDismiss: () => unawaited(_dismiss(scanNext: true)),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    super.key,
    required this.signal,
    required this.onTap,
    required this.onDismiss,
  });

  final SocialShareSignal signal;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final saved = signal.outcome == SocialShareNotificationOutcome.saved;
    final failed = signal.outcome == SocialShareNotificationOutcome.failed;
    final accent = saved
        ? const Color(0xFF2F8F73)
        : failed
            ? const Color(0xFFE85D4C)
            : const Color(0xFFD18A2C);
    return Dismissible(
      key: ValueKey('dismiss:${signal.notificationIds.join(':')}'),
      direction: DismissDirection.up,
      onDismissed: (_) => onDismiss(),
      child: Material(
        key: const ValueKey('social-share-notification-banner'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: PinitColors.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PinitColors.aubergine, width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: PinitColors.aubergine,
                  blurRadius: 0,
                  offset: Offset(3, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(
                    saved
                        ? FeatherIcons.check
                        : failed
                            ? FeatherIcons.alertTriangle
                            : FeatherIcons.helpCircle,
                    size: 19,
                    color: PinitColors.cream,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        signal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: PinitColors.aubergine,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signal.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          height: 1.25,
                          color: PinitColors.aubergineSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Dismiss',
                  button: true,
                  child: IconButton(
                    key: const ValueKey('dismiss-social-share-signal'),
                    onPressed: onDismiss,
                    icon: const Icon(
                      FeatherIcons.x,
                      size: 17,
                      color: PinitColors.mute,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
