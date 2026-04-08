import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Reviews" — featured review card + composer for restaurants. Owns
/// its own loading / submitting state since the review lifecycle is
/// self-contained and the parent doesn't need to react to it.
class ReviewSection extends StatefulWidget {
  const ReviewSection({super.key, required this.location});

  final LocationModel location;

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  final LocationReviewsHelper _reviewsHelper = LocationReviewsHelper();
  final TextEditingController _reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();

  bool _isLoadingReview = false;
  bool _isSubmittingReview = false;
  String? _reviewError;
  Map<String, dynamic>? _review;
  bool _reviewIsCurrentUser = false;
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _reviewFocusNode.dispose();
    super.dispose();
  }

  bool _isRestaurant() {
    final types = widget.location.types?.toLowerCase() ?? '';
    if (types.contains('restaurant')) return true;
    if ((widget.location.cuisine ?? '').trim().isNotEmpty) return true;
    return false;
  }

  Future<void> _loadReview() async {
    if (!_isRestaurant()) return;
    setState(() {
      _isLoadingReview = true;
      _reviewError = null;
    });
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      Map<String, dynamic>? userReview;
      if (userId != null) {
        userReview = await _reviewsHelper.getUserReview(
          locationId: widget.location.locationId,
          userId: userId,
        );
      }
      if (userReview != null) {
        _review = userReview;
        _reviewIsCurrentUser = true;
      } else {
        _review = await _reviewsHelper.getLatestPublicReview(
          locationId: widget.location.locationId,
        );
        _reviewIsCurrentUser = false;
      }
    } catch (_) {
      _reviewError = 'Could not load reviews.';
    } finally {
      if (mounted) setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0 || _reviewController.text.trim().isEmpty) {
      setState(() => _reviewError = 'Please add a rating and a short review.');
      return;
    }
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      setState(() => _reviewError = 'Sign in to leave a review.');
      return;
    }
    setState(() {
      _isSubmittingReview = true;
      _reviewError = null;
    });
    try {
      await _reviewsHelper.createReview(
        locationId: widget.location.locationId,
        userId: userId,
        content: _reviewController.text.trim(),
        rating: _selectedRating,
        isPrivate: false,
      );
      _reviewController.clear();
      _selectedRating = 0;
      _reviewFocusNode.unfocus();
      await _loadReview();
    } catch (e) {
      setState(() {
        _reviewError = 'Could not submit review: ${_formatError(e)}';
      });
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  String _formatError(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  String _formatTimeAgo(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Just now';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final reviewText = _review != null
        ? (_review![SupabaseConstants.columnContentReview]?.toString().trim() ?? '')
        : '';
    final rating = _review?[SupabaseConstants.columnRatingReview] as int?;
    final createdAt = _review?[SupabaseConstants.columnCreatedAt]?.toString();
    final sourceLabel = _reviewIsCurrentUser ? 'Your review' : 'Community';

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

        if (_isLoadingReview)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                ),
              ),
            ),
          )
        else if (reviewText.isNotEmpty) ...[
          _ReviewCard(
            reviewText: reviewText,
            rating: rating,
            sourceLabel: sourceLabel,
            createdAt: createdAt,
            formatTimeAgo: _formatTimeAgo,
          ),
        ] else
          Text(
            'No reviews yet — be the first!',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.mute,
            ),
          ),

        if (_isRestaurant()) ...[
          const SizedBox(height: 18),
          _ReviewComposer(
            controller: _reviewController,
            focusNode: _reviewFocusNode,
            selectedRating: _selectedRating,
            isSubmitting: _isSubmittingReview,
            onRatingChanged: (val) => setState(() => _selectedRating = val),
            onSubmit: _submitReview,
          ),
        ],

        if (_reviewError != null) ...[
          const SizedBox(height: 10),
          Text(
            _reviewError!,
            style: GoogleFonts.dmSans(
              color: PinitColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.reviewText,
    required this.rating,
    required this.sourceLabel,
    required this.createdAt,
    required this.formatTimeAgo,
  });

  final String reviewText;
  final int? rating;
  final String sourceLabel;
  final String? createdAt;
  final String Function(String) formatTimeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: (rating != null && i < rating!)
                      ? PinitColors.aubergine
                      : PinitColors.creamDeep,
                );
              }),
              const Spacer(),
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
                  sourceLabel.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.15 * 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$reviewText"',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: PinitColors.aubergine,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 10),
            Text(
              formatTimeAgo(createdAt!),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: PinitColors.mute,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewComposer extends StatelessWidget {
  const _ReviewComposer({
    required this.controller,
    required this.focusNode,
    required this.selectedRating,
    required this.isSubmitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int selectedRating;
  final bool isSubmitting;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LEAVE A REVIEW',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
              letterSpacing: 0.12 * 11,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (i) {
              final val = i + 1;
              return GestureDetector(
                onTap: () => onRatingChanged(val),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.star_rounded,
                    size: 30,
                    color: val <= selectedRating
                        ? PinitColors.aubergine
                        : PinitColors.creamDeep,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 2,
            maxLines: 4,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.aubergine,
            ),
            decoration: InputDecoration(
              hintText: 'What did you love?',
              hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
              filled: true,
              fillColor: PinitColors.cream,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PinitColors.creamDeep, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PinitColors.creamDeep, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: PinitColors.aubergine, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: PinitColors.aubergine,
                foregroundColor: PinitColors.cream,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: PinitColors.cream),
                    )
                  : Text(
                      'Post Review',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        color: PinitColors.cream,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
