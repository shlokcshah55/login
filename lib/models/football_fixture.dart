class FootballFixture {
  const FootballFixture({
    required this.id,
    required this.teamA,
    required this.teamB,
    this.countryA,
    this.countryB,
    this.flagAUrl,
    this.flagBUrl,
    this.kickoffTime,
    this.competition,
  });

  final String id;
  final String teamA;
  final String teamB;
  final String? countryA;
  final String? countryB;
  final String? flagAUrl;
  final String? flagBUrl;
  final DateTime? kickoffTime;
  final String? competition;

  String get countryAForSearch => _clean(countryA) ?? teamA;
  String get countryBForSearch => _clean(countryB) ?? teamB;

  String get displayTitle => '$teamA vs $teamB';

  factory FootballFixture.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json['id'], 'id');
    final teamA = _requiredString(json['teamA'] ?? json['team_a'], 'teamA');
    final teamB = _requiredString(json['teamB'] ?? json['team_b'], 'teamB');
    final kickoffRaw = json['kickoffTime'] ?? json['kickoff_time'];

    return FootballFixture(
      id: id,
      teamA: teamA,
      teamB: teamB,
      countryA: _clean(json['countryA'] ?? json['country_a']),
      countryB: _clean(json['countryB'] ?? json['country_b']),
      flagAUrl: _clean(json['flagAUrl'] ?? json['flag_a_url']),
      flagBUrl: _clean(json['flagBUrl'] ?? json['flag_b_url']),
      kickoffTime:
          kickoffRaw == null ? null : DateTime.tryParse(kickoffRaw.toString()),
      competition: _clean(json['competition']),
    );
  }

  static String _requiredString(Object? value, String field) {
    final cleaned = _clean(value);
    if (cleaned == null) {
      throw FormatException('Missing football fixture field: $field');
    }
    return cleaned;
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
