import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/api/models/locations.dart';
import 'package:login/services/google_place_service.dart';

class CarouselTile extends StatelessWidget {
  final LocationModel item;
  final LocationPreference preference;
  final VoidCallback onRemove;
  final VoidCallback onSave;
  final VoidCallback onTap;
  
  static final GooglePlacesService _googlePlacesService = GooglePlacesService();

  const CarouselTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onSave,
    required this.onTap,
    required this.preference,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.locationId.toString()),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onRemove();
        } else if (direction == DismissDirection.startToEnd) {
          onSave();
        }
      },
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(FeatherIcons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(FeatherIcons.trash2, color: Colors.white),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent), // Invisible border
          ),
          margin: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 12), // Adds spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image at the top
              item.photoReference != null
                  ? Image.network(
                      _googlePlacesService.getPhotoUrl(item.photoReference) ?? '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200, // Adjust to your desired height
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          height: 200,
                          width: double.infinity,
                          child: const Icon(FeatherIcons.image,
                              size: 50, color: Colors.grey),
                        );
                      },
                    )
                  : Container(
                      height: 200,
                      width: double.infinity,
                      color: preference == LocationPreference.saved
                          ? Colors.green
                          : Colors.blue,
                      child: Center(
                        child: Text(
                          item.name[0],
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
              // Text information below the image
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (item.vicinity != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.vicinity!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.rating != null)
                          Row(
                            children: [
                              const Icon(FeatherIcons.star,
                                  size: 16, color: Colors.amber),
                              Text(
                                item.rating.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        if (item.priceLevel != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              '\$' * item.priceLevel!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
