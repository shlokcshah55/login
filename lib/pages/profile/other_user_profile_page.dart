import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/home/carousel_list_page.dart';
import 'package:login/pages/profile/user_list_page.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/route_open_guard.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'widgets/pinit_colors.dart';
import 'widgets/been_to_rankings_section.dart';

class OtherUserProfilePage extends StatefulWidget {
  final UserModel user;
  final bool highlightPendingRequest;

  const OtherUserProfilePage({
    Key? key,
    required this.user,
    this.highlightPendingRequest = false,
  }) : super(key: key);

  @override
  State<OtherUserProfilePage> createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  bool _isLoading = true;
  List<CollectionItem> _publicCollections = [];
  String _followStatus = 'idle'; // idle, requested, accepted, blocked
  late UserModel _user;
  bool _pendingIncomingRequest = false;
  bool _processingRequestAction = false;
  bool _theyFollowMe = false;

  final CollectionsHelper _collectionsHelper = CollectionsHelper();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadUserData();
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);

      final results = await Future.wait([
        supabaseService.users.getFollowStatus(widget.user.supabaseId!),
        _collectionsHelper.getUserPublicCollections(widget.user.supabaseId!),
        supabaseService.users.getUserProfileById(widget.user.supabaseId!),
        supabaseService.users.getIncomingFollowRequests(),
        supabaseService.users.getFollowers(),
      ]);

      final incoming = (results[3] as List<UserModel>);
      final myFollowers = (results[4] as List<UserModel>);
      final hasPendingFromThisUser =
          incoming.any((u) => u.supabaseId == widget.user.supabaseId);
      final theyFollowMe =
          myFollowers.any((u) => u.supabaseId == widget.user.supabaseId);

      if (mounted) {
        setState(() {
          _followStatus = (results[0] as String?) ?? 'idle';
          _publicCollections = results[1] as List<CollectionItem>;
          final fullUser = results[2] as UserModel?;
          if (fullUser != null) _user = fullUser;
          _pendingIncomingRequest = hasPendingFromThisUser;
          _theyFollowMe = theyFollowMe;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptIncomingRequest() async {
    if (_processingRequestAction) return;
    HapticFeedback.selectionClick();
    setState(() => _processingRequestAction = true);
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);
      await supabaseService.users.acceptFollowRequest(widget.user.supabaseId!);
      await FCMService().markFollowRequestAsReadFrom(widget.user.supabaseId!);
      if (!mounted) return;
      setState(() {
        _pendingIncomingRequest = false;
        _processingRequestAction = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingRequestAction = false);
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t accept',
          message: 'Please try again in a moment.',
        ),
      );
    }
  }

  Future<void> _rejectIncomingRequest() async {
    if (_processingRequestAction) return;
    HapticFeedback.selectionClick();
    setState(() => _processingRequestAction = true);
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);
      await supabaseService.users.rejectFollowRequest(widget.user.supabaseId!);
      await FCMService().markFollowRequestAsReadFrom(widget.user.supabaseId!);
      if (!mounted) return;
      setState(() {
        _pendingIncomingRequest = false;
        _processingRequestAction = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _processingRequestAction = false);
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t decline',
          message: 'Please try again in a moment.',
        ),
      );
    }
  }

  Future<void> _handleFollowAction() async {
    if (_followStatus == 'blocked') return;
    HapticFeedback.selectionClick();
    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);

      if (_followStatus == 'idle') {
        await supabaseService.users.followUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = 'requested');
      } else if (_followStatus == 'requested' || _followStatus == 'accepted') {
        await supabaseService.users.unfollowUser(widget.user.supabaseId!);
        if (mounted) setState(() => _followStatus = 'idle');
      }
    } catch (e) {
      if (mounted) {
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t update follow',
            message: 'Please try again in a moment.',
          ),
        );
      }
    }
  }

  Future<void> _handleBlock() async {
    final supabaseService =
        Provider.of<SupabaseService>(context, listen: false);
    try {
      await supabaseService.users.blockUser(widget.user.supabaseId!);
      if (mounted) {
        setState(() => _followStatus = 'blocked');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t block user',
            message: 'Please try again in a moment.',
          ),
        );
      }
    }
  }

  Future<void> _handleUnblock() async {
    final supabaseService =
        Provider.of<SupabaseService>(context, listen: false);
    try {
      await supabaseService.users.unblockUser(widget.user.supabaseId!);
      if (mounted) {
        setState(() => _followStatus = 'idle');
      }
    } catch (e) {
      if (mounted) {
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t unblock user',
            message: 'Please try again in a moment.',
          ),
        );
      }
    }
  }

  void _showOverflowMenu() {
    HapticFeedback.selectionClick();
    final isBlocked = _followStatus == 'blocked';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: PinitColors.accent,
                ),
                title: Text(
                  isBlocked ? 'Unblock user' : 'Block user',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergine,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  if (isBlocked) {
                    _handleUnblock();
                  } else {
                    _confirmBlock();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
            boxShadow: PinitColors.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Block ${widget.user.name ?? "this user"}?',
                style: const TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 22,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'They will no longer be able to follow you or see your activity. Any pending request between you will be cleared.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: PinitColors.aubergineSoft,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: PinitColors.creamSunk,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: PinitColors.creamDeep, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: PinitColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Block',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.cream,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await _handleBlock();
  }

  @override
  Widget build(BuildContext context) {
    final collapsedHeader = _scrollOffset > 120;
    final currentUser = Provider.of<UserDataProvider>(context).supabaseUserData;
    final similarity = currentUser?.vibeSimilarityWith(_user);
    debugPrint('[OtherUserProfilePage] vibe match: '
        'me=${currentUser?.vibeTagAffinity ?? "null"} '
        'them=${_user.vibeTagAffinity ?? "null"} '
        'similarity=$similarity '
        'userId=${_user.supabaseId}');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: _isLoading
            ? _buildLoadingState()
            : Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _buildProfileHeader()),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: _VibeMatchCard(
                            otherUserName: _user.name ?? 'them',
                            similarity: similarity,
                          ),
                        ),
                      ),
                      if (_publicCollections
                          .any((c) => c.name.trim() == 'Been To'))
                        SliverToBoxAdapter(
                          child: BeenToRankingsSection(
                            userId: _user.supabaseId!,
                            showGateKeepToggle: false,
                            allowExpand: false,
                            maxPlaces: 5,
                          ),
                        ),
                      SliverToBoxAdapter(child: _buildEatListsSection()),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                  if (collapsedHeader)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildCollapsedHeader(),
                    ),
                  if (_pendingIncomingRequest)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildPendingRequestBar(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    final opacity = (1 - (_scrollOffset / 120)).clamp(0.0, 1.0);

    return Container(
      color: PinitColors.aubergine,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar: back + overflow
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _buildHeaderIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  _buildHeaderIconButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: _showOverflowMenu,
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(size: 72),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user.name ?? 'No Name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Rova',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w100,
                                  color: PinitColors.cream,
                                  letterSpacing: 1.7,
                                  height: 1.05,
                                ),
                              ),
                              if (_user.bio != null &&
                                  _user.bio!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _user.bio!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    color: PinitColors.cream
                                        .withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              _buildStatsRow(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildFollowButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar({required double size}) {
    final hasImage =
        _user.profileImageUrl != null && _user.profileImageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(
          image: hasImage
              ? NetworkImage(_user.profileImageUrl!)
              : const AssetImage('lib/assets/default_avatar.png')
                  as ImageProvider,
          fit: BoxFit.cover,
        ),
        border: Border.all(
          color: PinitColors.creamDeep.withValues(alpha: 0.5),
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final isMutual = _followStatus == 'accepted' && _theyFollowMe;
    return Row(
      children: [
        _buildStat(_publicCollections.length.toString(), 'Eat-Lists'),
        _buildStatDivider(),
        _buildStat(
          _user.followersCount.toString(),
          'Followers',
          onTap: isMutual ? _openFollowers : null,
        ),
        _buildStatDivider(),
        _buildStat(
          _user.followingCount.toString(),
          'Following',
          onTap: isMutual ? _openFollowing : null,
        ),
      ],
    );
  }

  void _openFollowers() {
    final userId = _user.supabaseId!;
    final name = _user.name ?? 'Their';
    unawaited(
      RouteOpenGuard.run<void>(
        'user-followers:$userId',
        () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => UserListPage(
              title: '$name\'s Followers',
              loader: (s) => s.users.getFollowers(userId: userId),
              emptyMessage: 'No followers yet',
            ),
          ),
        ),
      ),
    );
  }

  void _openFollowing() {
    final userId = _user.supabaseId!;
    final name = _user.name ?? 'Their';
    unawaited(
      RouteOpenGuard.run<void>(
        'user-following:$userId',
        () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => UserListPage(
              title: '$name\'s Following',
              loader: (s) => s.users.getFollowingList(userId: userId),
              emptyMessage: 'Not following anyone yet',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatDivider() => Container(
        width: 1,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: PinitColors.cream.withValues(alpha: 0.18),
      );

  Widget _buildStat(String value, String label, {VoidCallback? onTap}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Rova',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: PinitColors.cream,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: PinitColors.cream.withValues(alpha: 0.65),
                letterSpacing: 0.2,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.chevron_right_rounded,
                size: 13,
                color: PinitColors.cream.withValues(alpha: 0.5),
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: content,
    );
  }

  Widget _buildFollowButton() {
    late String label;
    late Color bg;
    late Color fg;
    late IconData icon;

    switch (_followStatus) {
      case 'requested':
        label = 'Requested';
        bg = PinitColors.cream.withValues(alpha: 0.12);
        fg = PinitColors.cream;
        icon = Icons.schedule_rounded;
        break;
      case 'accepted':
        label = 'Following';
        bg = PinitColors.cream.withValues(alpha: 0.12);
        fg = PinitColors.cream;
        icon = Icons.check_rounded;
        break;
      case 'blocked':
        label = 'Blocked';
        bg = PinitColors.cream.withValues(alpha: 0.08);
        fg = PinitColors.cream.withValues(alpha: 0.6);
        icon = Icons.block_rounded;
        break;
      case 'idle':
      default:
        label = 'Follow';
        bg = PinitColors.cream;
        fg = PinitColors.aubergine;
        icon = Icons.add_rounded;
    }

    return GestureDetector(
      onTap: _handleFollowAction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PinitColors.cream.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PinitColors.cream.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: PinitColors.cream.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 20, color: PinitColors.cream),
        ),
      ),
    );
  }

  Widget _buildEatListsSection() {
    final collections =
        _publicCollections.where((c) => c.name.trim() != 'Been To').toList();
    if (collections.isNotEmpty) {
      return _PublicCollectionsSection(collections: collections);
    }

    final name = (_user.name != null && _user.name!.trim().isNotEmpty)
        ? _user.name!.trim()
        : 'This user';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Eat-Lists',
            style: TextStyle(
              fontFamily: 'Rova',
              fontSize: 24,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              height: 160,
              child: SvgPicture.asset(
                'lib/assets/illustrations/Beep Beep - Campervan 2.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                "$name has no eat-lists for you to see, they are either gatekeeping or don't have any. Either way tell them",
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergineSoft,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, topPadding + 10, 14, 12),
        decoration: BoxDecoration(
          color: PinitColors.cream,
          border: const Border(
            bottom: BorderSide(color: PinitColors.aubergine, width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: PinitColors.aubergine.withValues(alpha: 0.18),
              blurRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: PinitColors.aubergine.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: PinitColors.aubergine, width: 1.4),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wants to follow you',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: PinitColors.aubergineSoft,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _user.name ?? _user.username ?? 'New follower',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildRequestActionButton(
              label: 'Decline',
              filled: false,
              onTap: _processingRequestAction ? null : _rejectIncomingRequest,
            ),
            const SizedBox(width: 8),
            _buildRequestActionButton(
              label: 'Accept',
              filled: true,
              onTap: _processingRequestAction ? null : _acceptIncomingRequest,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestActionButton({
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? PinitColors.aubergine : PinitColors.cream,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PinitColors.aubergine, width: 1.4),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: filled ? PinitColors.cream : PinitColors.aubergine,
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(color: PinitColors.aubergine),
      child: Row(
        children: [
          _buildHeaderIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          _buildAvatar(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _user.name ?? 'Profile',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 20,
                fontWeight: FontWeight.w100,
                color: PinitColors.cream,
                letterSpacing: 1.6,
              ),
            ),
          ),
          _buildHeaderIconButton(
            icon: Icons.more_horiz_rounded,
            onTap: _showOverflowMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(PinitColors.cream),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading profile...',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: PinitColors.aubergineSoft,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vibe Match Card — cosine similarity between current user and viewed user.
// ─────────────────────────────────────────────────────────────────────────────

class _VibeMatchCard extends StatelessWidget {
  final String otherUserName;
  final double? similarity;

  const _VibeMatchCard({
    required this.otherUserName,
    required this.similarity,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = similarity != null;
    final clamped = (similarity ?? 0).clamp(0.0, 1.0);
    final percentage = (clamped * 100).round();
    final indicatorColor =
        hasData ? PinitColors.matchIndicator(percentage) : PinitColors.mute;
    final label = hasData ? _label(percentage) : 'Not enough data';
    final subtitle = hasData
        ? _subtitle(percentage, otherUserName)
        : '$otherUserName needs a few more taps before we can compare vibes.';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        boxShadow: PinitColors.subtleShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: hasData ? clamped : 0,
                    strokeWidth: 6,
                    backgroundColor: PinitColors.creamDeep,
                    valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                  ),
                ),
                Text(
                  hasData ? '$percentage%' : '—',
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIBE MATCH',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: PinitColors.aubergineSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(int percentage) {
    if (percentage >= 85) return 'Twin Flames';
    if (percentage >= 70) return 'Kindred Palates';
    if (percentage >= 50) return 'Aligned Tastes';
    if (percentage >= 30) return 'Some Overlap';
    return 'Different Vibes';
  }

  String _subtitle(int percentage, String name) {
    if (percentage >= 90) {
      return 'Scarily accurate. Did $name steal your tastebuds?';
    }
    if (percentage >= 85) {
      return 'Basically the same person. Split the bill already.';
    }
    if (percentage >= 75) {
      return "You'd never fight over where to eat with $name.";
    }
    if (percentage >= 65) {
      return '$name is your people. Go get dinner.';
    }
    if (percentage >= 55) {
      return 'Plenty of common ground — trust their recs.';
    }
    if (percentage >= 45) {
      return 'Some sparks, some clashes. Keep it interesting.';
    }
    if (percentage >= 30) {
      return "$name will drag you somewhere new — in a good way.";
    }
    if (percentage >= 15) {
      return 'Different worlds. Might be worth a taste adventure.';
    }
    return "Opposites attract? $name eats on another planet.";
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public Collections — horizontal row of this user's public collections.
// ─────────────────────────────────────────────────────────────────────────────

class _PublicCollectionsSection extends StatelessWidget {
  final List<CollectionItem> collections;

  const _PublicCollectionsSection({required this.collections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Eat-Lists',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 24,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.2,
                    height: 1.05,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: Text(
                  '${collections.length} public',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            scrollDirection: Axis.horizontal,
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _PublicCollectionCard(
              collection: collections[index],
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicCollectionCard extends StatelessWidget {
  final CollectionItem collection;

  const _PublicCollectionCard({required this.collection});

  Future<void> _openDetails(BuildContext context) async {
    HapticFeedback.selectionClick();
    final helper = CollectionsHelper();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: PinitColors.aubergine,
        ),
      ),
    );
    final locations = await helper.getLocationsForCollection(collection.collectionId);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // loading dialog
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CarouselListPage(
          locations: locations,
          title: collection.name,
          listType: LocationListType.search,
          homeViewModel: null,
          collectionId: collection.collectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetails(context),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PinitColors.aubergine, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Container(
            color: PinitColors.creamSunk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildCover()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergine,
                          letterSpacing: 0.2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${collection.placeCount} place${collection.placeCount == 1 ? "" : "s"}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildCover() {
    final photoUrl = collection.photo ?? collection.coverColor;
    if (photoUrl != null && photoUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    return Container(
      color: PinitColors.creamDeep,
      child: const Center(
        child: Icon(FeatherIcons.bookmark, size: 28, color: PinitColors.mute),
      ),
    );
  }
}
