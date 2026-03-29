import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/explore/explore_view_model.dart';
import 'package:login/pages/explore/widgets/explore_location_tile.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

/// Draggable bottom sheet that shows rich location tiles over the Explore map.
class ExploreTileSheet extends StatelessWidget {
  const ExploreTileSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.08,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.12, 0.45, 0.85],
      builder: (context, scrollController) {
        return _SheetBody(scrollController: scrollController);
      },
    );
  }
}

class _SheetBody extends StatelessWidget {
  final ScrollController scrollController;
  const _SheetBody({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewModel = context.watch<ExploreViewModel>();
    final locations = viewModel.locations;
    final isLoading = viewModel.isLoadingResults;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Drag handle ──
              _buildHandle(isDark),
              // ── Header ──
              _buildHeader(isDark, locations.length, isLoading),
              // ── Content ──
              Expanded(
                child: isLoading
                    ? _buildLoading(isDark)
                    : locations.isEmpty
                        ? _buildEmpty(isDark, viewModel.error)
                        : _buildList(context, scrollController, locations),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int count, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Text(
            isLoading
                ? 'Searching...'
                : count > 0
                    ? '$count spots found'
                    : 'Explore',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Finding the best spots...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark, String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              error ?? 'Search for a city or neighborhood to discover spots',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ScrollController scrollController,
    List<LocationModel> locations,
  ) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final location = locations[index];
        return ExploreLocationTile(
          location: location,
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => ExpandedLocationCard(
                location: location,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            );
          },
        );
      },
    );
  }
}
