class RewardVoucher {
  final String id;
  final String userId;
  final String? sourceReferralId;
  final String title;
  final String description;
  final String campaignKey;
  final String merchantName;
  final int discountPercent;
  final String status;
  final DateTime issuedAt;
  final DateTime? redeemedAt;
  final DateTime? expiresAt;
  final String termsText;
  final String sourceType;
  final String redemptionToken;
  final Map<String, dynamic> metadata;

  const RewardVoucher({
    required this.id,
    required this.userId,
    required this.sourceReferralId,
    required this.title,
    required this.description,
    required this.campaignKey,
    required this.merchantName,
    required this.discountPercent,
    required this.status,
    required this.issuedAt,
    required this.redeemedAt,
    required this.expiresAt,
    required this.termsText,
    required this.sourceType,
    required this.redemptionToken,
    required this.metadata,
  });

  bool get isAvailable => status == 'available';

  factory RewardVoucher.fromJson(Map<String, dynamic> json) {
    final issuedAt = DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return RewardVoucher(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      sourceReferralId: json['source_referral_id']?.toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      campaignKey: json['campaign_key'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'available',
      issuedAt: issuedAt,
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.tryParse(json['redeemed_at'].toString())
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      termsText: json['terms_text'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
      redemptionToken: json['redemption_token']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }
}
