import 'dart:async';

import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/bubbles/bubbles_search_state.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';
import 'package:login/widgets/chat/chat_group_tile.dart';
import 'package:login/widgets/profile/user_card.dart';

class BubblesPageView extends StatefulWidget {
  const BubblesPageView({
    super.key,
    required this.bubbles,
    required this.isLoading,
    required this.errorText,
    required this.onRefresh,
    required this.onCreateBubble,
    required this.onSearchPeople,
    required this.onBubbleTap,
    required this.onPersonTap,
    this.searchDebounce = const Duration(milliseconds: 280),
    this.suggestedUsers = const [],
    this.isLoadingSuggestedUsers = false,
    this.onRefreshSuggestedUsers,
  });

  final List<Bubble> bubbles;
  final bool isLoading;
  final String? errorText;
  final Future<void> Function() onRefresh;
  final VoidCallback onCreateBubble;
  final Future<List<UserModel>> Function(String query) onSearchPeople;
  final ValueChanged<Bubble> onBubbleTap;
  final ValueChanged<UserModel> onPersonTap;
  final Duration searchDebounce;
  final List<UserModel> suggestedUsers;
  final bool isLoadingSuggestedUsers;
  final Future<void> Function()? onRefreshSuggestedUsers;

  @override
  State<BubblesPageView> createState() => _BubblesPageViewState();
}

class _BubblesPageViewState extends State<BubblesPageView> {
  static const _pageBackground = Color(0xFFFFFBF8);
  static const _cardBorder = Color(0xFFF6DEE6);
  static const _roseAccent = Color(0xFFD95D85);
  static const _amberAccent = Color(0xFFFFC978);
  static const _mintAccent = Color(0xFF7CCCB4);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounceTimer;
  List<UserModel> _peopleResults = const [];
  bool _isSearchingPeople = false;
  String? _peopleErrorText;
  int _searchRequestId = 0;

  bool get _showingSearch =>
      _searchFocusNode.hasFocus || _searchController.text.trim().isNotEmpty;

  List<BubblesSearchSection> get _searchSections => buildBubblesSearchSections(
        query: _searchController.text,
        bubbles: widget.bubbles,
        people: _peopleResults,
        isPeopleLoading: _isSearchingPeople,
        peopleErrorText: _peopleErrorText,
      );

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchFocusNode.removeListener(_handleSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinitColors = theme.extension<PinitColors>() ?? PinitColors.light;

    return Scaffold(
      backgroundColor: _pageBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF5EF),
              _pageBackground,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (!_showingSearch) _buildHeader(theme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: _buildSearchField(theme, pinitColors),
              ),
              if (!_showingSearch && widget.bubbles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _buildQuickStats(theme),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: PinitMotion.standard,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildBody(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      key: const Key('bubbles_compact_header'),
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bubbles',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF70364E),
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shared plans and chats',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8F6171),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCreateBubble,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: _roseAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme, PinitColors pinitColors) {
    return Container(
      key: const Key('bubbles_search_shell'),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        key: const Key('bubbles_universal_search_field'),
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _handleSearchChanged,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: pinitColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search bubbles and people',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: pinitColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _roseAccent,
          ),
          suffixIcon: _showingSearch
              ? IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded),
                  color: pinitColors.textSecondary,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme) {
    final unreadTotal = widget.bubbles.fold<int>(
      0,
      (sum, bubble) => sum + bubble.unreadCount,
    );
    final pinTotal = widget.bubbles.fold<int>(
      0,
      (sum, bubble) => sum + bubble.groupLocations.length,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatChip(
            icon: Icons.chat_bubble_outline_rounded,
            label: '${widget.bubbles.length} circles',
            color: _roseAccent,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.mark_chat_unread_outlined,
            label: unreadTotal == 0 ? 'All caught up' : '$unreadTotal unread',
            color: _amberAccent,
          ),
          const SizedBox(width: 10),
          _StatChip(
            icon: Icons.location_on_outlined,
            label: '$pinTotal shared pins',
            color: _mintAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (widget.isLoading && widget.bubbles.isEmpty && !_showingSearch) {
      return _buildLoadingState(theme);
    }

    if (_showingSearch) {
      return _buildSearchResults(theme);
    }

    if (widget.errorText != null && widget.bubbles.isEmpty) {
      return _buildFeedError(theme);
    }

    if (widget.bubbles.isEmpty) {
      return _buildEmptyState(theme);
    }

    return _buildBubbleFeed(theme);
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      key: const ValueKey('bubbles_loading_state'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(_roseAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Loading your circles...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF7A5661),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedError(ThemeData theme) {
    return Center(
      key: const ValueKey('bubbles_feed_error_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _roseAccent,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Couldn\'t load your bubbles',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.errorText ?? 'Pull to retry or try again in a moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8D7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonal(
              onPressed: widget.onRefresh,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFE4EA),
                foregroundColor: _roseAccent,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return RefreshIndicator(
      key: const ValueKey('bubbles_empty_state'),
      color: _roseAccent,
      onRefresh: () async {
        await widget.onRefresh();
        await widget.onRefreshSuggestedUsers?.call();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 14, 28, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFE6EC),
                      Color(0xFFFFF2DB),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.bubble_chart_rounded,
                  size: 46,
                  color: _roseAccent,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No bubbles yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w100,
                  color: const Color(0xFF5E3340),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Create your first bubble to start sharing plans, chats, and pins with friends.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8A6975),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onCreateBubble,
                style: FilledButton.styleFrom(
                  backgroundColor: _roseAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: const Text('Create a Bubble'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildRecommendedPeopleSection(theme),
        ],
      ),
    );
  }

  Widget _buildRecommendedPeopleSection(ThemeData theme) {
    if (widget.isLoadingSuggestedUsers && widget.suggestedUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_roseAccent),
          ),
        ),
      );
    }

    if (widget.suggestedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended people',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF5E3340),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.suggestedUsers.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: UserCard(
              user: user,
              onTap: widget.onPersonTap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubbleFeed(ThemeData theme) {
    return RefreshIndicator(
      key: const ValueKey('bubbles_feed_state'),
      color: _roseAccent,
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.bubbles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final bubble = widget.bubbles[index];
          return ChatGroupTile(
            key: ValueKey(bubble.id),
            bubble: bubble,
            onTap: () => widget.onBubbleTap(bubble),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    return ListView(
      key: const ValueKey('bubbles_search_state'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        for (final section in _searchSections) ...[
          Padding(
            key: Key('bubbles_${section.type.name}_section'),
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(
              section.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF66424F),
              ),
            ),
          ),
          if (section.errorText != null)
            _buildSectionBanner(
              theme,
              text: section.errorText!,
              color: const Color(0xFFFFE5EA),
              foreground: _roseAccent,
            )
          else if (section.isLoading && section.items.isEmpty)
            _buildSectionBanner(
              theme,
              text: 'Searching ${section.title.toLowerCase()}...',
              color: const Color(0xFFFFF1E0),
              foreground: const Color(0xFFB8792E),
            )
          else if (section.items.isEmpty)
            _buildSectionBanner(
              theme,
              text: section.type == BubblesSearchSectionType.bubbles
                  ? 'No matching bubbles yet'
                  : 'No people found',
              color: Colors.white,
              foreground: const Color(0xFF8C7380),
            )
          else
            ...section.items.map((item) => _buildSearchResultTile(theme, item)),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildSectionBanner(
    ThemeData theme, {
    required String text,
    required Color color,
    required Color foreground,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(ThemeData theme, BubblesSearchItem item) {
    final isBubble = item.type == BubblesSearchSectionType.bubbles;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isBubble && item.bubble != null) {
              widget.onBubbleTap(item.bubble!);
              return;
            }
            if (item.user != null) {
              widget.onPersonTap(item.user!);
            }
          },
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBubble
                            ? const [Color(0xFFFFD5E0), Color(0xFFFFEDDA)]
                            : const [Color(0xFFFFE8EF), Color(0xFFFFF6E7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isBubble
                          ? Icons.bubble_chart_rounded
                          : Icons.person_rounded,
                      color: _roseAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF57333E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8D7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if ((item.badgeText ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.badgeText!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFB8782F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFFB997A6),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _peopleErrorText = null;
    _searchRequestId++;
    final requestId = _searchRequestId;
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      setState(() {
        _peopleResults = const [];
        _isSearchingPeople = false;
      });
      return;
    }

    setState(() {
      _peopleResults = const [];
      _isSearchingPeople = true;
    });

    if (widget.searchDebounce == Duration.zero) {
      unawaited(_runPeopleSearch(trimmedQuery, requestId));
      return;
    }

    _searchDebounceTimer = Timer(widget.searchDebounce, () {
      unawaited(_runPeopleSearch(trimmedQuery, requestId));
    });
  }

  Future<void> _runPeopleSearch(String query, int requestId) async {
    try {
      final results = await widget.onSearchPeople(query);
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _peopleResults = results;
        _isSearchingPeople = false;
        _peopleErrorText = null;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      setState(() {
        _peopleResults = const [];
        _isSearchingPeople = false;
        _peopleErrorText = 'Couldn\'t load people right now';
      });
    }
  }

  void _handleSearchFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchRequestId++;
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _peopleResults = const [];
      _isSearchingPeople = false;
      _peopleErrorText = null;
    });
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4DDE5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFF7A5E6A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
