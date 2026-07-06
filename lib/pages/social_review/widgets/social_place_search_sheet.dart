import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/services/google_place_service.dart';
import 'package:login/themes/app_typography.dart';

/// Search-and-pick sheet for attaching the right place to a social post
/// (manual add on failed posts, or correcting a wrong match).
/// Pops with the picked [LocationModel], or null when cancelled.
class SocialPlaceSearchSheet extends StatefulWidget {
  final String title;

  const SocialPlaceSearchSheet({Key? key, required this.title})
      : super(key: key);

  static Future<LocationModel?> show(
    BuildContext context, {
    String title = 'Which place was it?',
  }) {
    return showModalBottomSheet<LocationModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SocialPlaceSearchSheet(title: title),
    );
  }

  @override
  State<SocialPlaceSearchSheet> createState() => _SocialPlaceSearchSheetState();
}

class _SocialPlaceSearchSheetState extends State<SocialPlaceSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final GooglePlacesService _placesService = GooglePlacesService();

  Timer? _debounce;
  bool _isSearching = false;
  List<LocationModel> _results = [];
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await _placesService.searchPlaces(query: query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Search failed — try again');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: pinit.PinitColors.mute.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.headingSmall
                          .copyWith(color: pinit.PinitColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: pinit.PinitColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _search(value.trim()),
                style: AppTypography.bodyLarge
                    .copyWith(color: pinit.PinitColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search restaurants, cafes, bars…',
                  hintStyle: AppTypography.bodyLarge
                      .copyWith(color: pinit.PinitColors.textMuted),
                  prefixIcon: const Icon(FeatherIcons.search,
                      size: 18, color: pinit.PinitColors.textSecondary),
                  filled: true,
                  fillColor: pinit.PinitColors.creamSunk,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: pinit.PinitColors.aubergine),
      );
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style:
              AppTypography.bodyMedium.copyWith(color: pinit.PinitColors.error),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _controller.text.trim().length < 2
              ? 'Type the place name from the post'
              : 'No places found',
          style: AppTypography.bodyMedium
              .copyWith(color: pinit.PinitColors.textMuted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final place = _results[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).pop(place),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(FeatherIcons.mapPin,
                      size: 18, color: pinit.PinitColors.aubergineSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: pinit.PinitColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if ((place.vicinity ?? '').isNotEmpty)
                          Text(
                            place.vicinity!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                                color: pinit.PinitColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (place.rating != null) ...[
                    const Icon(Icons.star_rounded,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      place.rating!.toStringAsFixed(1),
                      style: AppTypography.bodySmall.copyWith(
                        color: pinit.PinitColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
