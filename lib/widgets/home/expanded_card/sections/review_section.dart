import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// "Reviews" — displays Google reviews from the location. Shows up to 3
/// reviews with Google badge styling to differentiate from user-generated content.
class ReviewSection extends StatelessWidget {
  const ReviewSection({super.key, required this.location});

  final LocationModel location;

  @override
  Widget build(BuildContext context) {
    final reviews = location.reviews ?? [];
    final hasReviews = reviews.isNotEmpty;

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
        const Text(
          'Reviews',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        if (hasReviews)
          Column(
            children: [
              ...reviews.take(3).map((review) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GoogleReviewCard(review: review),
                );
              }).toList(),
            ],
          )
        else
          Text(
            'No reviews available',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.mute,
            ),
          ),
      ],
    );
  }
}

class _GoogleReviewCard extends StatelessWidget {
  const _GoogleReviewCard({required this.review});

  final Map<String, dynamic> review;

  String _extractAuthor() {
    return review['author_name']?.toString() ?? 'Anonymous';
  }

  double _extractRating() {
    final rating = review['rating'];
    if (rating is num) return rating.toDouble();
    if (rating is String) return double.tryParse(rating) ?? 0;
    return 0;
  }

  String _extractText() {
    return review['text']?.toString() ?? '';
  }

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

    return Container(
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
                        ...List.generate(5, (i) {
                          return Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: (i < rating.toInt())
                                ? PinitColors.aubergine
                                : PinitColors.creamDeep,
                          );
                        }),
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
                  border:
                      Border.all(color: PinitColors.creamDeep, width: 1.5),
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
  }
}
