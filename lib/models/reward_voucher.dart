class RewardVoucher {
  final String id;
  final String title;
  final String description;
  final String merchantName;
  final int discountPercent;
  final String status;
  final DateTime issuedAt;
  final DateTime? redeemedAt;
  final String termsText;
  final String sourceType;

  const RewardVoucher({
    required this.id,
    required this.title,
    required this.description,
    required this.merchantName,
    required this.discountPercent,
    required this.status,
    required this.issuedAt,
    required this.redeemedAt,
    required this.termsText,
    required this.sourceType,
  });

  bool get isAvailable => status == 'available';

  factory RewardVoucher.fromJson(Map<String, dynamic> json) {
    final issuedAt = DateTime.tryParse(json['issued_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return RewardVoucher(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      discountPercent: (json['discount_percent'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'available',
      issuedAt: issuedAt,
      redeemedAt: json['redeemed_at'] != null
          ? DateTime.tryParse(json['redeemed_at'].toString())
          : null,
      termsText: json['terms_text'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? '',
    );
  }
}
