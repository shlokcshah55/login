import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class FriendSavesSection extends StatelessWidget {
  const FriendSavesSection({
    super.key,
    required this.friendSaves,
    required this.matchScore,
  });

  final List<FriendSave> friendSaves;
  final double? matchScore;

  @override
  Widget build(BuildContext context) {
    if (friendSaves.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'Friends who saved this location',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: PinitColors.aubergine,
              ),
              const SizedBox(width: 8),
              Text(
                'Saved by friends',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                ),
              ),
              const Spacer(),
              Text(
                _friendCountLabel(friendSaves.length),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.mute,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (final entry in friendSaves.take(4).toList().asMap().entries)
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        entry.key == friendSaves.take(4).length - 1 ? 0 : 10,
                  ),
                  child: _FriendSaveRow(
                    friendSave: entry.value,
                    matchScore: matchScore,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _friendCountLabel(int count) {
    if (count == 1) return '1 friend';
    return '$count friends';
  }
}

class _FriendSaveRow extends StatelessWidget {
  const _FriendSaveRow({
    required this.friendSave,
    required this.matchScore,
  });

  final FriendSave friendSave;
  final double? matchScore;

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName(friendSave.friendName);
    final username = friendSave.friendUsername?.trim();
    final hasUsername = username != null && username.isNotEmpty;
    final matchPercent = _matchPercent(matchScore);

    return Row(
      children: [
        _FriendAvatar(friendSave: friendSave),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _displayName(friendSave.friendName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                ),
              ),
              if (hasUsername) ...[
                const SizedBox(height: 1),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.mute,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _MatchChip(
          label: matchPercent == null
              ? '$firstName saved'
              : 'You + $firstName match $matchPercent% here',
          accentColor: matchPercent == null
              ? PinitColors.aubergineSoft
              : PinitColors.matchIndicator(matchPercent),
        ),
      ],
    );
  }

  int? _matchPercent(double? score) {
    if (score == null || score <= 0) return null;
    return (score.clamp(0.0, 1.0) * 100).round();
  }

  String _displayName(String rawName) {
    final name = rawName.trim();
    return name.isEmpty ? 'Friend' : name;
  }

  String _firstName(String rawName) {
    return _displayName(rawName).split(' ').first;
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friendSave});

  final FriendSave friendSave;

  @override
  Widget build(BuildContext context) {
    final imageUrl = friendSave.friendProfileImageUrl?.trim();
    final initials = _initials(friendSave.friendName);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PinitColors.creamSunk,
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl.isEmpty
          ? Center(
              child: Text(
                initials,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                  ),
                ),
              ),
            ),
    );
  }

  String _initials(String rawName) {
    final parts = rawName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _MatchChip extends StatelessWidget {
  const _MatchChip({
    required this.label,
    required this.accentColor,
  });

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.22),
            width: 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: accentColor,
          ),
        ),
      ),
    );
  }
}
