import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/actions.dart';
import 'package:login/pages/bubble_messaging_page.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/route_open_guard.dart';
import 'package:login/widgets/chat/add_members_dialog.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'dart:math' as math;

class ExpandedChatView extends StatefulWidget {
  final Bubble bubble;
  final VoidCallback onClose;
  final int? initialUnreadCount;
  final List<UserLocationActionModel>? initialActivities;
  final Future<void> Function()? onOpenChat;
  final Future<void> Function()? onOpenPinsChat;
  final VoidCallback? onShowActivity;
  final Future<void> Function(String userId)? onOpenUserProfile;
  final Future<void> Function(UserLocationActionModel activity)?
      onOpenActivityLocation;

  const ExpandedChatView({
    Key? key,
    required this.bubble,
    required this.onClose,
    this.initialUnreadCount,
    this.initialActivities,
    this.onOpenChat,
    this.onOpenPinsChat,
    this.onShowActivity,
    this.onOpenUserProfile,
    this.onOpenActivityLocation,
  }) : super(key: key);

  @override
  _ExpandedChatViewState createState() => _ExpandedChatViewState();
}

class _ExpandedChatViewState extends State<ExpandedChatView>
    with TickerProviderStateMixin {
  static const Color _unreadAccent = PinitColors.aubergineSoft;
  static const Color _unreadAccentPressed = PinitColors.aubergine;
  static const Color _unreadSurface = Color(0xFFF3EDF6);
  static const Color _unreadShadow = Color(0xFF8C6D91);

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _messageCount = 0;
  bool _isLoadingMessageCount = true;
  bool _showMembersList = false;
  List<UserLocationActionModel> _activities = [];
  bool _isLoadingActivities = true;

  late Bubble currentBubble;

  static const List<Color> _avatarColors = [
    Color(0xFFB39DDB),
    Color(0xFF80CBC4),
    Color(0xFFFFCC80),
    Color(0xFFF48FB1),
    Color(0xFF90CAF9),
    Color(0xFFA5D6A7),
  ];

  @override
  void initState() {
    super.initState();
    currentBubble = widget.bubble;
    _messageCount = widget.initialUnreadCount ?? 0;
    _isLoadingMessageCount = widget.initialUnreadCount == null;
    _activities = List<UserLocationActionModel>.from(
      widget.initialActivities ?? const <UserLocationActionModel>[],
    );
    _isLoadingActivities = widget.initialActivities == null;
    _initializeAnimations();
    if (widget.initialUnreadCount == null) {
      _loadMessageCount();
    }
    if (widget.initialActivities == null) {
      _loadBubbleActivity();
    }
  }

  Future<void> _loadMessageCount() async {
    try {
      final count =
          await SupabaseService().messaging.getUnreadCount(widget.bubble.id);
      if (mounted)
        setState(() {
          _messageCount = count;
          _isLoadingMessageCount = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMessageCount = false);
    }
  }

  Future<void> _loadBubbleActivity() async {
    try {
      final activities =
          await SupabaseService().bubbles.getBubbleActivity(widget.bubble.id);
      if (mounted)
        setState(() {
          _activities = activities;
          _isLoadingActivities = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingActivities = false);
    }
  }

  Future<void> _reloadBubbleData() async {
    try {
      final updated =
          await SupabaseService().bubbles.getBubbleById(widget.bubble.id);
      if (updated != null && mounted) setState(() => currentBubble = updated);
    } catch (_) {}
  }

  void _showAddMembersDialog() {
    showDialog(
      context: context,
      builder: (context) => AddMembersDialog(
        bubble: currentBubble,
        onMembersAdded: _reloadBubbleData,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) => widget.onClose());
  }

  Future<void> _navigateToGroupChat({
    BubbleMessageView initialView = BubbleMessageView.messages,
  }) async {
    if (_messageCount > 0 && mounted) {
      setState(() => _messageCount = 0);
    }

    final override = initialView == BubbleMessageView.pins
        ? widget.onOpenPinsChat
        : widget.onOpenChat;
    if (override != null) {
      await override();
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BubbleMessagingPage(
          bubble: currentBubble,
          initialView: initialView,
        ),
      ),
    );
  }

  void _showActivityNotifications() {
    if (widget.onShowActivity != null) {
      widget.onShowActivity!();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.42),
      builder: (context) => _ActivityNotificationsSheet(
        bubbleName: currentBubble.name,
        activities: _activities,
        timeAgoFor: _getTimeAgo,
        onOpenActivityLocation: _openActivityLocation,
      ),
    );
  }

  Future<void> _openActivityLocation(UserLocationActionModel activity) async {
    if (widget.onOpenActivityLocation != null) {
      await widget.onOpenActivityLocation!(activity);
      return;
    }

    try {
      final locations = await SupabaseService().locations.getLocationsByIds(
        [activity.locationId],
      );
      if (!mounted || locations.isEmpty) return;

      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, _, __) => ExpandedLocationCard(
          location: locations.first,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        transitionBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      );
    } catch (_) {}
  }

  Future<void> _openUserProfile(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    if (widget.onOpenUserProfile != null) {
      await widget.onOpenUserProfile!(normalizedUserId);
      return;
    }

    try {
      final user = await SupabaseService().users.getUserProfileById(
            normalizedUserId,
          );
      if (user == null) return;

      final navigator = Navigator.of(context);
      navigator.pop();
      final userKey = user.supabaseId ?? user.email;
      await RouteOpenGuard.run<void>(
        'other-user-profile:$userKey',
        () => navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => OtherUserProfilePage(user: user),
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: PinitColors.aubergine.withValues(alpha: 0.55),
      body: GestureDetector(
        onTap: _handleClose,
        child: SizedBox.expand(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: screenSize.width * 0.92,
                      constraints:
                          BoxConstraints(maxHeight: screenSize.height * 0.82),
                      decoration: const BoxDecoration(
                        color: PinitColors.cream,
                        border: Border.fromBorderSide(
                          BorderSide(color: PinitColors.aubergine, width: 1.5),
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        boxShadow: [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: Offset(6, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14.5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            Flexible(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 16),
                                    _buildTopPins(),
                                    const SizedBox(height: 12),
                                    _buildChatCard(),
                                    const SizedBox(height: 12),
                                    _buildRecentActivity(),
                                    const SizedBox(height: 12),
                                    _buildStatsRow(),
                                    if (_showMembersList) ...[
                                      const SizedBox(height: 12),
                                      _buildMembersList(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      decoration: const BoxDecoration(
        color: PinitColors.creamSunk,
        border:
            Border(bottom: BorderSide(color: PinitColors.creamDeep, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar stack
          _buildAvatarStack(
              currentBubble.memberAvatars, currentBubble.memberNames,
              size: 36),
          const SizedBox(width: 12),
          // Name + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentBubble.name,
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontFamilyFallback: ['Naria'],
                    fontSize: 22,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.4,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${currentBubble.memberCount} member${currentBubble.memberCount == 1 ? '' : 's'}'
                  ' · ${currentBubble.groupLocations.length} pin${currentBubble.groupLocations.length == 1 ? '' : 's'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: PinitColors.mute,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Score badge
          if (currentBubble.compatibilityScore != null) ...[
            const SizedBox(width: 8),
            _ScoreBadge(score: currentBubble.compatibilityScore!),
          ],
          const SizedBox(width: 6),
          // Add member
          _HeaderBtn(
            icon: Icons.person_add_outlined,
            onTap: _showAddMembersDialog,
          ),
          const SizedBox(width: 6),
          // Close
          _HeaderBtn(
            icon: Icons.close_rounded,
            onTap: _handleClose,
          ),
        ],
      ),
    );
  }

  // ── Top pins ─────────────────────────────────────────────────────────────────

  Widget _buildTopPins() {
    final locations = currentBubble.groupLocations.toList()
      ..shuffle(math.Random());
    final top3 = locations.take(3).toList();

    if (top3.isEmpty) {
      return GestureDetector(
        key: const Key('expanded_bubble_top_pins'),
        onTap: () => _navigateToGroupChat(initialView: BubbleMessageView.pins),
        child: _SectionCard(
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: PinitColors.mute, size: 20),
              const SizedBox(width: 10),
              Text(
                'No pins yet — add some places!',
                style:
                    GoogleFonts.dmSans(fontSize: 13, color: PinitColors.mute),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      key: const Key('expanded_bubble_top_pins'),
      onTap: () => _navigateToGroupChat(initialView: BubbleMessageView.pins),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(label: 'TOP PINS', icon: Icons.location_on_outlined),
            const SizedBox(height: 10),
            Row(
              children: top3.asMap().entries.map((e) {
                final rank = e.key;
                final loc = e.value;
                final medals = ['🥇', '🥈', '🥉'];
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: rank < top3.length - 1 ? 8 : 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk,
                        border: Border.all(color: PinitColors.creamDeep),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medals[rank],
                              style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(
                            loc.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergine,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat card ────────────────────────────────────────────────────────────────

  Widget _buildChatCard() {
    final isUnread = !_isLoadingMessageCount && _messageCount > 0;

    return GestureDetector(
      key: const Key('expanded_bubble_group_chat'),
      onTap: () => _navigateToGroupChat(),
      child: _SectionCard(
        backgroundColor: isUnread ? _unreadSurface : PinitColors.cream,
        borderColor: isUnread ? _unreadAccent : PinitColors.aubergine,
        shadowColor: isUnread ? _unreadShadow : PinitColors.aubergine,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isUnread ? _unreadAccent : PinitColors.aubergine,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isUnread
                    ? const [
                        BoxShadow(
                          color: Color(0x296B3866),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isUnread
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                color: PinitColors.cream,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Group Chat',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _isLoadingMessageCount
                      ? Text('Loading…',
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: PinitColors.mute))
                      : isUnread
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _unreadAccent,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1F6B3866),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                '$_messageCount new',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'No unread messages',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: PinitColors.mute),
                            ),
                ],
              ),
            ),
            _buildAvatarStack(
                currentBubble.memberAvatars, currentBubble.memberNames,
                size: 28),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isUnread ? _unreadAccentPressed : PinitColors.mute,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent activity ──────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return GestureDetector(
      onTap: _isLoadingActivities ? null : _showActivityNotifications,
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const Key('expanded_bubble_recent_activity'),
              behavior: HitTestBehavior.opaque,
              onTap: _isLoadingActivities ? null : _showActivityNotifications,
              child: _SectionLabel(
                label: 'RECENT ACTIVITY',
                icon: Icons.bolt_rounded,
              ),
            ),
            const SizedBox(height: 10),
            if (_isLoadingActivities)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PinitColors.aubergine,
                  ),
                ),
              )
            else if (_activities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No recent activity',
                  style:
                      GoogleFonts.dmSans(fontSize: 13, color: PinitColors.mute),
                ),
              )
            else
              Column(
                children: [
                  ..._activities.take(2).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ActivityRow(
                          activity: a,
                          timeAgo: _getTimeAgo(a.createdAt),
                          onTap: () => _openActivityLocation(a),
                        ),
                      )),
                  if (_activities.length > 2)
                    GestureDetector(
                      onTap: _showActivityNotifications,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              size: 14,
                              color: PinitColors.aubergineSoft,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'View all activity',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: PinitColors.aubergineSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('expanded_bubble_members_stat'),
            onTap: () => setState(() => _showMembersList = !_showMembersList),
            child: _StatCard(
              value: '${currentBubble.memberCount}',
              label: 'MEMBERS',
              icon: _showMembersList
                  ? Icons.people_rounded
                  : Icons.people_outline_rounded,
              active: _showMembersList,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            key: const Key('expanded_bubble_pins_stat'),
            onTap: () =>
                _navigateToGroupChat(initialView: BubbleMessageView.pins),
            child: _StatCard(
              value: '${currentBubble.groupLocations.length}',
              label: 'PINS',
              icon: Icons.location_on_outlined,
              active: false,
            ),
          ),
        ),
        if (currentBubble.compatibilityScore != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '${currentBubble.compatibilityScore}%',
              label: 'MATCH',
              icon: Icons.favorite_border_rounded,
              active: false,
            ),
          ),
        ],
      ],
    );
  }

  // ── Members list ─────────────────────────────────────────────────────────────

  Widget _buildMembersList() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'MEMBERS', icon: Icons.people_outline_rounded),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...List.generate(currentBubble.memberAvatars.length, (i) {
                final url = currentBubble.memberAvatars[i];
                final name = i < currentBubble.memberNames.length
                    ? currentBubble.memberNames[i]
                    : 'Member ${i + 1}';
                final userId = i < currentBubble.memberIds.length
                    ? currentBubble.memberIds[i]
                    : '';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                return GestureDetector(
                  key: Key(
                      'expanded_bubble_member_${userId.isNotEmpty ? userId : i}'),
                  onTap: userId.isEmpty ? null : () => _openUserProfile(userId),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PinitColors.creamSunk,
                      border: Border.all(color: PinitColors.creamDeep),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _avatarColors[i % _avatarColors.length],
                          ),
                          child: ClipOval(
                            child: url.isNotEmpty
                                ? Image.network(url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                          child: Text(initial,
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white)),
                                        ))
                                : Center(
                                    child: Text(initial,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          name,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Add members chip
              GestureDetector(
                onTap: _showAddMembersDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine.withValues(alpha: 0.07),
                    border: Border.all(
                        color: PinitColors.aubergine.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_outlined,
                          size: 14, color: PinitColors.aubergine),
                      const SizedBox(width: 6),
                      Text(
                        'Add',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _buildAvatarStack(List<String> avatars, List<String> names,
      {required double size}) {
    final items = avatars.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    const overlap = 0.38;
    final step = size * (1 - overlap);
    final totalWidth = size + step * (items.length - 1);
    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: List.generate(items.length, (i) {
          final url = items[i];
          final initial = i < names.length && names[i].isNotEmpty
              ? names[i][0].toUpperCase()
              : null;
          return Positioned(
            left: i * step,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PinitColors.creamSunk, width: 1.5),
                color: _avatarColors[i % _avatarColors.length],
              ),
              child: ClipOval(
                child: url.isNotEmpty
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _InitialCenter(initial: initial, size: size))
                    : _InitialCenter(initial: initial, size: size),
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  const _SectionCard({
    required this.child,
    this.backgroundColor = PinitColors.cream,
    this.borderColor = PinitColors.aubergine,
    this.shadowColor = PinitColors.aubergine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.fromBorderSide(
          BorderSide(color: borderColor, width: 1.5),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: PinitColors.aubergineSoft),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: PinitColors.aubergineSoft,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool active;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: active ? PinitColors.aubergine : PinitColors.cream,
        border: const Border.fromBorderSide(
          BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        boxShadow: const [
          BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: active ? PinitColors.cream : PinitColors.aubergineSoft),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: active ? PinitColors.cream : PinitColors.aubergine,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: active
                      ? PinitColors.cream.withValues(alpha: 0.7)
                      : PinitColors.mute,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = PinitColors.matchIndicator(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '$score%',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: PinitColors.creamDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: PinitColors.creamDeep),
        ),
        child: Icon(icon, size: 17, color: PinitColors.aubergine),
      ),
    );
  }
}

class _ActivityNotificationsSheet extends StatelessWidget {
  final String bubbleName;
  final List<UserLocationActionModel> activities;
  final String Function(DateTime?) timeAgoFor;
  final Future<void> Function(UserLocationActionModel activity)
      onOpenActivityLocation;

  const _ActivityNotificationsSheet({
    required this.bubbleName,
    required this.activities,
    required this.timeAgoFor,
    required this.onOpenActivityLocation,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: PinitColors.aubergine, width: 1.5),
              left: BorderSide(color: PinitColors.aubergine, width: 1.5),
              right: BorderSide(color: PinitColors.aubergine, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22.5)),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: PinitColors.creamDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: PinitColors.aubergine,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                color: PinitColors.cream,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent activity',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: PinitColors.aubergine,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bubbleName,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: PinitColors.mute,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: PinitColors.creamSunk,
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: PinitColors.creamDeep),
                              ),
                              child: Text(
                                '${activities.length}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.aubergineSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rawIndex) {
                      if (rawIndex.isOdd) {
                        return const SizedBox(height: 8);
                      }
                      final index = rawIndex ~/ 2;
                      final activity = activities[index];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          index == activities.length - 1 ? 24 : 0,
                        ),
                        child: _ActivityNotificationTile(
                          activity: activity,
                          timeAgo: timeAgoFor(activity.createdAt),
                          onTap: () => onOpenActivityLocation(activity),
                        ),
                      );
                    },
                    childCount:
                        activities.isEmpty ? 0 : activities.length * 2 - 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityNotificationTile extends StatelessWidget {
  final UserLocationActionModel activity;
  final String timeAgo;
  final VoidCallback? onTap;

  const _ActivityNotificationTile({
    required this.activity,
    required this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tone = _ActivityTone.forAction(activity.action);
    final avatarUrl = activity.user_avatar_url;
    final displayName = activity.name.isNotEmpty ? activity.name : 'Someone';
    final placeName =
        activity.locationName.isNotEmpty ? activity.locationName : 'a place';
    final initial = displayName[0].toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PinitColors.creamDeep),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tone.color.withValues(alpha: 0.18),
                      border: Border.all(color: PinitColors.cream, width: 2),
                    ),
                    child: ClipOval(
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _InitialCenter(
                                initial: initial,
                                size: 42,
                              ),
                            )
                          : _InitialCenter(initial: initial, size: 42),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tone.color,
                        border:
                            Border.all(color: PinitColors.creamSunk, width: 2),
                      ),
                      child:
                          Icon(tone.icon, color: PinitColors.cream, size: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                                TextSpan(text: ' ${tone.message} '),
                                TextSpan(
                                  text: placeName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: PinitColors.aubergine,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (timeAgo.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            timeAgo,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: PinitColors.mute,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tone.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tone.label,
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: tone.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityTone {
  final IconData icon;
  final Color color;
  final String label;
  final String message;

  const _ActivityTone({
    required this.icon,
    required this.color,
    required this.label,
    required this.message,
  });

  static _ActivityTone forAction(String action) {
    return switch (action) {
      'save' => const _ActivityTone(
          icon: Icons.bookmark_rounded,
          color: PinitColors.aubergineSoft,
          label: 'SAVED',
          message: 'saved',
        ),
      'shared_video' => const _ActivityTone(
          icon: Icons.play_arrow_rounded,
          color: PinitColors.accent,
          label: 'SHARED',
          message: 'shared',
        ),
      _ => const _ActivityTone(
          icon: Icons.location_on_rounded,
          color: PinitColors.warning,
          label: 'PINNED',
          message: 'pinned',
        ),
    };
  }
}

class _ActivityRow extends StatelessWidget {
  final UserLocationActionModel activity;
  final String timeAgo;
  final VoidCallback? onTap;

  const _ActivityRow({
    required this.activity,
    required this.timeAgo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final actionLabel = switch (activity.action) {
      'save' => 'SAVED',
      'shared_video' => 'SHARED',
      _ => 'PINNED',
    };
    const accentColor = PinitColors.aubergineSoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('expanded_bubble_activity_${activity.locationId}'),
        onTap: onTap,
        child: Ink(
          decoration: const BoxDecoration(
            color: PinitColors.creamSunk,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accentColor),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                actionLabel,
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activity.locationName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.aubergine,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                activity.name,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: PinitColors.mute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timeAgo.isNotEmpty)
                          Text(
                            timeAgo,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: PinitColors.mute),
                          ),
                      ],
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

class _InitialCenter extends StatelessWidget {
  final String? initial;
  final double size;
  const _InitialCenter({this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: initial != null
          ? Text(
              initial!,
              style: GoogleFonts.dmSans(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            )
          : Icon(Icons.person, size: size * 0.5, color: Colors.white),
    );
  }
}
