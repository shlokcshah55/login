class BubbleSummary {
  const BubbleSummary({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.isPrivate,
    this.memberCount = 0,
    this.memberAvatars = const [],
    this.memberNames = const [],
  });

  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final bool isPrivate;
  final int memberCount;
  final List<String> memberAvatars;
  final List<String> memberNames;

  BubbleSummary copyWith({
    int? memberCount,
    List<String>? memberAvatars,
    List<String>? memberNames,
  }) {
    return BubbleSummary(
      id: id,
      name: name,
      createdBy: createdBy,
      createdAt: createdAt,
      isPrivate: isPrivate,
      memberCount: memberCount ?? this.memberCount,
      memberAvatars: memberAvatars ?? this.memberAvatars,
      memberNames: memberNames ?? this.memberNames,
    );
  }
}
