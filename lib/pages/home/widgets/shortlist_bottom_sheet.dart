import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:provider/provider.dart';

/// Bottom sheet listing shortlisted places with remove actions.
class ShortlistBottomSheet extends StatelessWidget {
  const ShortlistBottomSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ShortlistProvider>(),
        child: const ShortlistBottomSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Consumer<ShortlistProvider>(
      builder: (context, shortlist, _) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      Icons.playlist_add_check_rounded,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Shortlist (${shortlist.count})',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (shortlist.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          shortlist.clear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── List ──
              if (shortlist.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        size: 40,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No places shortlisted yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add places you\'re actively considering',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: shortlist.items.length,
                    itemBuilder: (context, index) {
                      final location = shortlist.items[index];
                      return _ShortlistItem(
                        location: location,
                        onRemove: () => shortlist.remove(location.locationId),
                      );
                    },
                  ),
                ),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
            ],
          ),
        );
      },
    );
  }
}

class _ShortlistItem extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onRemove;

  const _ShortlistItem({
    required this.location,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = location.imageUrl ?? location.photoReference;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark ? Colors.white12 : Colors.grey[200],
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? Colors.white12 : Colors.grey[200],
                        child: Icon(Icons.place,
                            color: isDark ? Colors.white24 : Colors.black26),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.white12 : Colors.grey[200],
                      alignment: Alignment.center,
                      child: Text(
                        location.emoji ?? '📍',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (location.cuisine != null)
                  Text(
                    location.cuisine!,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Rating
          if (location.rating != null) ...[
            const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
            const SizedBox(width: 2),
            Text(
              location.rating!.toStringAsFixed(1),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Remove
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
