import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/full_text_sheet.dart';

/// Displays reviews for a location.
///
/// Priority: if any public pinit reviews exist they are shown (all friend
/// reviews + up to 3 generic ones). Falls back to Google reviews (up to 3)
/// when no pinit reviews are available.
class ReviewSection extends StatelessWidget {
  const ReviewSection({
    super.key,
    required this.location,
    this.pinitReviews = const [],
    this.friendIds = const {},
  });

  final LocationModel location;
  final List<Map<String, dynamic>> pinitReviews;
  final Set<String> friendIds;

  @override
  Widget build(BuildContext context) {
    final hasPinit = pinitReviews.isNotEmpty;

    final friendReviews = hasPinit
        ? pinitReviews
            .where((r) => friendIds.contains(r['user_id'] as String?))
            .toList()
        : <Map<String, dynamic>>[];
    final genericReviews = hasPinit
        ? pinitReviews
            .where((r) => !friendIds.contains(r['user_id'] as String?))
            .take(3)
            .toList()
        : <Map<String, dynamic>>[];

    final hasFriendReviews = friendReviews.isNotEmpty;

    final String subtitle;
    if (hasPinit && hasFriendReviews) {
      subtitle = 'from your network';
    } else if (hasPinit) {
      subtitle = 'from pinit users';
    } else {
      subtitle = '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT PEOPLE SAY',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(
                fontFamily: 'Rova',
                fontFamilyFallback: ['Naria'],
                fontSize: 28,
                fontWeight: FontWeight.w100,
                color: PinitColors.aubergine,
                letterSpacing: 1.3,
                height: 1.05,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (hasPinit) ...[
          ...friendReviews.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PinitReviewCard(review: r, isFriend: true),
            ),
          ),
          ...genericReviews.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PinitReviewCard(review: r, isFriend: false),
            ),
          ),
        ] else ...[
          // Fall back to Google reviews
          if ((location.reviews ?? []).isNotEmpty)
            ...location.reviews!.take(3).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GoogleReviewCard(review: r),
                  ),
                )
          else
            Text(
              'No reviews available',
              style: GoogleFonts.dmSans(fontSize: 14, color: PinitColors.mute),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pinit review card
// ─────────────────────────────────────────────────────────────

class _PinitReviewCard extends StatelessWidget {
  const _PinitReviewCard({required this.review, required this.isFriend});

  final Map<String, dynamic> review;
  final bool isFriend;

  String _displayName() {
    final user = review['users'];
    if (user is Map) {
      final name = user['name']?.toString();
      final username = user['username']?.toString();
      if (name != null && name.isNotEmpty) return name;
      if (username != null && username.isNotEmpty) return '@$username';
    }
    return 'Pinit user';
  }

  String? _avatarUrl() {
    final user = review['users'];
    if (user is Map) return user['profile_image_url']?.toString();
    return null;
  }

  double? _rating() {
    final r = review['rating'];
    if (r is num) return r.toDouble();
    if (r is String) return double.tryParse(r);
    return null;
  }

  String _timeAgo() {
    final raw = review['created_at'];
    if (raw == null) return 'Recently';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isFriend ? PinitColors.aubergine : PinitColors.creamSunk;
    final textColor = isFriend ? PinitColors.cream : PinitColors.aubergine;
    final subColor =
        isFriend ? PinitColors.cream.withValues(alpha: 0.65) : PinitColors.mute;
    final border =
        isFriend ? null : Border.all(color: PinitColors.creamDeep, width: 1.5);
    final badgeLabel = isFriend ? 'FRIEND' : 'PINIT';
    final name = _displayName();
    final avatar = _avatarUrl();
    final rating = _rating();
    final content = review['content']?.toString() ?? '';

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              _Avatar(
                url: avatar,
                initials: _initials(name),
                isFriend: isFriend,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rating != null)
                      Text(
                        '${rating.toStringAsFixed(1)} / 10',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                  ],
                ),
              ),
              // Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PinitColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.cream,
                    letterSpacing: 0.15 * 9,
                  ),
                ),
              ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textColor,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _timeAgo(),
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (content.trim().isEmpty) return card;

    return Semantics(
      button: true,
      label: 'Read full review',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showExpandedCardTextSheet(
          context: context,
          title: 'Full review',
          eyebrow: name,
          meta: rating != null ? '${rating.toStringAsFixed(1)} / 10' : null,
          text: content,
        ),
        child: card,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.initials,
    required this.isFriend,
  });

  final String? url;
  final String initials;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final borderColor = isFriend
        ? PinitColors.cream.withValues(alpha: 0.3)
        : PinitColors.creamDeep;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _Initials(
                  initials: initials,
                  isFriend: isFriend,
                ),
              )
            : _Initials(initials: initials, isFriend: isFriend),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.isFriend});

  final String initials;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isFriend
          ? PinitColors.cream.withValues(alpha: 0.15)
          : PinitColors.creamDeep,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isFriend ? PinitColors.cream : PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Google review card (unchanged)
// ─────────────────────────────────────────────────────────────

class _GoogleReviewCard extends StatelessWidget {
  const _GoogleReviewCard({required this.review});

  final Map<String, dynamic> review;

  String _extractAuthor() => review['author_name']?.toString() ?? 'Anonymous';

  double _extractRating() {
    final rating = review['rating'];
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0;
    return 0;
  }

  String _extractText() => review['text']?.toString() ?? '';

  String _formatTimeAgo(int? timestamp) {
    if (timestamp == null) return 'Recently';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  @override
  Widget build(BuildContext context) {
    final author = _extractAuthor();
    final rating = _extractRating();
    final text = _extractText();
    final time = _formatTimeAgo(review['time'] as int?);

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergine,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: i < rating.toInt()
                                ? PinitColors.aubergine
                                : PinitColors.creamDeep,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: PinitColors.cream,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: Text(
                  'GOOGLE',
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.15 * 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: PinitColors.aubergine,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: PinitColors.mute,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (text.trim().isEmpty) return card;

    return Semantics(
      button: true,
      label: 'Read full review',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showExpandedCardTextSheet(
          context: context,
          title: 'Full review',
          eyebrow: author,
          meta: rating.toStringAsFixed(1),
          text: text,
        ),
        child: card,
      ),
    );
  }
}
