import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/services/google_place_service.dart';
import 'package:login/themes/app_typography.dart';

typedef SocialPlaceSearcher = Future<List<LocationModel>> Function(
    String query);

/// Reusable search block for selecting an existing Google/canonical place.
///
/// It is embedded directly in the social review screen and also powers the
/// backwards-compatible modal sheet.
class SocialPlaceSearchPanel extends StatefulWidget {
  const SocialPlaceSearchPanel({
    super.key,
    required this.onSelected,
    this.searcher,
    this.autofocus = false,
    this.debounceDuration = const Duration(milliseconds: 350),
    this.maxResults = 5,
  });

  final ValueChanged<LocationModel> onSelected;
  final SocialPlaceSearcher? searcher;
  final bool autofocus;
  final Duration debounceDuration;
  final int maxResults;

  @override
  State<SocialPlaceSearchPanel> createState() => _SocialPlaceSearchPanelState();
}

class _SocialPlaceSearchPanelState extends State<SocialPlaceSearchPanel> {
  final TextEditingController _controller = TextEditingController();
  GooglePlacesService? _placesService;

  Timer? _debounce;
  bool _isSearching = false;
  List<LocationModel> _results = const [];
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(widget.debounceDuration, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final searcher = widget.searcher ??
          (value) => (_placesService ??= GooglePlacesService())
              .searchPlaces(query: value);
      final results = await searcher(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results.take(widget.maxResults).toList(growable: false);
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _error = 'Search failed. Try again in a moment.');
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            _debounce?.cancel();
            final query = value.trim();
            if (query.length >= 2) unawaited(_search(query));
          },
          cursorColor: pinit.PinitColors.aubergine,
          style: AppTypography.sans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pinit.PinitColors.aubergine,
          ),
          decoration: InputDecoration(
            hintText: 'Search restaurants, cafés or bars',
            hintStyle: AppTypography.sans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: pinit.PinitColors.mute,
            ),
            prefixIcon: const Icon(
              FeatherIcons.search,
              size: 18,
              color: pinit.PinitColors.aubergineSoft,
            ),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                    icon: const Icon(
                      FeatherIcons.x,
                      size: 17,
                      color: pinit.PinitColors.aubergineSoft,
                    ),
                  ),
            filled: true,
            fillColor: pinit.PinitColors.creamSunk,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: pinit.PinitColors.creamDeep,
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: pinit.PinitColors.aubergine,
                width: 1.5,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildResults(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Padding(
        key: ValueKey('searching'),
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(
          color: pinit.PinitColors.aubergine,
          backgroundColor: pinit.PinitColors.creamDeep,
          borderRadius: BorderRadius.all(Radius.circular(999)),
          minHeight: 3,
        ),
      );
    }
    if (_error != null) {
      return Padding(
        key: const ValueKey('error'),
        padding: const EdgeInsets.only(top: 10),
        child: _SearchMessage(
          icon: FeatherIcons.alertCircle,
          message: _error!,
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        key: const ValueKey('guidance'),
        padding: const EdgeInsets.only(top: 10),
        child: _SearchMessage(
          icon: FeatherIcons.mapPin,
          message: _controller.text.trim().length < 2
              ? 'Search by the place name, neighbourhood or address'
              : 'No places found. Try a wider area or different spelling.',
        ),
      );
    }
    return Padding(
      key: const ValueKey('results'),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          for (var index = 0; index < _results.length; index++) ...[
            _SearchResultTile(
              place: _results[index],
              onTap: () => widget.onSelected(_results[index]),
            ),
            if (index != _results.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: pinit.PinitColors.mute),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.sans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: pinit.PinitColors.mute,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  const _SearchResultTile({required this.place, required this.onTap});

  final LocationModel place;
  final VoidCallback onTap;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pinit.PinitColors.creamDeep),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: pinit.PinitColors.creamSunk,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    FeatherIcons.mapPin,
                    size: 17,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: pinit.PinitColors.aubergine,
                        ),
                      ),
                      if (place.vicinity?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          place.vicinity!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pinit.PinitColors.mute,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (place.rating != null) ...[
                  const Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: Color(0xFFB57913),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    place.rating!.toStringAsFixed(1),
                    style: AppTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: pinit.PinitColors.aubergineSoft,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  FeatherIcons.chevronRight,
                  size: 16,
                  color: pinit.PinitColors.aubergineSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility wrapper for surfaces that still need a standalone picker.
class SocialPlaceSearchSheet extends StatelessWidget {
  const SocialPlaceSearchSheet({super.key, required this.title});

  final String title;

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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        decoration: const BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pinit.PinitColors.mute.withValues(alpha: .32),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.brand(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: pinit.PinitColors.aubergine,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      FeatherIcons.x,
                      color: pinit.PinitColors.aubergineSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SocialPlaceSearchPanel(
                autofocus: true,
                onSelected: (place) => Navigator.of(context).pop(place),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
