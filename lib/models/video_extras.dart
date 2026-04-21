/// Per-user video extras stored on the `user_location_actions` row.
/// Contains special offers, codes, and dates extracted from the TikTok
/// that the user saved.
class VideoExtras {
  const VideoExtras({
    this.specialOffers,
    this.personalNotes,
  });

  final List<SpecialOffer>? specialOffers;
  final String? personalNotes;

  factory VideoExtras.fromJson(Map<String, dynamic> json) {
    List<SpecialOffer>? offers;
    final rawOffers = json['special_offers'];
    if (rawOffers is List && rawOffers.isNotEmpty) {
      offers = rawOffers
          .whereType<Map<String, dynamic>>()
          .map((o) => SpecialOffer.fromJson(o))
          .toList();
    }

    return VideoExtras(
      specialOffers: offers,
      personalNotes: json['personal_notes'] as String?,
    );
  }

  /// True when there's at least one offer or a personal note.
  bool get hasContent =>
      (specialOffers != null && specialOffers!.isNotEmpty) ||
      (personalNotes != null && personalNotes!.isNotEmpty);
}

/// A single special offer/deal extracted from the TikTok.
class SpecialOffer {
  const SpecialOffer({
    required this.offer,
    this.validUntil,
    this.code,
  });

  final String offer;
  final String? validUntil;
  final String? code;

  factory SpecialOffer.fromJson(Map<String, dynamic> json) {
    return SpecialOffer(
      offer: json['offer'] as String? ?? '',
      validUntil: json['valid_until'] as String?,
      code: json['code'] as String?,
    );
  }
}
