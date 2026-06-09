class LocationSocialLink {
  const LocationSocialLink({
    required this.id,
    required this.locationId,
    required this.sourceUrl,
    required this.normalizedUrl,
    required this.platform,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final int locationId;
  final String sourceUrl;
  final String normalizedUrl;
  final String platform;
  final String? createdBy;
  final DateTime? createdAt;

  factory LocationSocialLink.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'];
    return LocationSocialLink(
      id: json['id']?.toString() ?? '',
      locationId: (json['location_id'] as num?)?.toInt() ?? 0,
      sourceUrl: json['source_url']?.toString() ?? '',
      normalizedUrl: json['normalized_url']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      createdBy: json['created_by']?.toString(),
      createdAt:
          rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null,
    );
  }
}
