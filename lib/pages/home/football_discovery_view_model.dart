import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:login/models/football_fixture.dart';
import 'package:login/models/locations.dart';

typedef FootballFixtureLoader = Future<List<FootballFixture>> Function();
typedef FootballMagicSearcher = Future<List<LocationModel>> Function(
  String query,
);
typedef FootballClock = DateTime Function();

class FootballCuisineResultGroup {
  const FootballCuisineResultGroup({
    required this.country,
    required this.cuisine,
    required this.results,
    this.error,
  });

  final String country;
  final String cuisine;
  final List<LocationModel> results;
  final String? error;

  String get title => '$cuisine restaurants';
  bool get hasError => error != null && error!.isNotEmpty;
}

class FootballDiscoveryViewModel extends ChangeNotifier {
  FootballDiscoveryViewModel({
    required FootballFixtureLoader loadFixtures,
    required FootballMagicSearcher magicSearch,
    FootballClock? now,
    List<FootballFixture>? fallbackFixtures,
  })  : _loadFixtures = loadFixtures,
        _magicSearch = magicSearch,
        _now = now ?? (() => DateTime.now().toUtc()),
        _fallbackFixtures = fallbackFixtures ?? worldCupScheduleFixtures;

  static const String pubSearchQuery =
      'pubs or sports bars near me showing football';
  static const int maxVisibleFixtures = 12;

  final FootballFixtureLoader _loadFixtures;
  final FootballMagicSearcher _magicSearch;
  final FootballClock _now;
  final List<FootballFixture> _fallbackFixtures;

  bool _hasStarted = false;
  bool _isPubSearchLoading = false;
  bool _areFixturesLoading = false;
  bool _isCuisineSearchLoading = false;
  String? _pubSearchError;
  String? _fixturesError;
  String? _cuisineSearchError;
  List<LocationModel> _pubResults = const [];
  List<FootballFixture> _fixtures = const [];
  FootballFixture? _selectedFixture;
  List<FootballCuisineResultGroup> _cuisineGroups = const [];

  bool get isPubSearchLoading => _isPubSearchLoading;
  bool get areFixturesLoading => _areFixturesLoading;
  bool get isCuisineSearchLoading => _isCuisineSearchLoading;
  String? get pubSearchError => _pubSearchError;
  String? get fixturesError => _fixturesError;
  String? get cuisineSearchError => _cuisineSearchError;
  List<LocationModel> get pubResults => List.unmodifiable(_pubResults);
  List<FootballFixture> get fixtures => List.unmodifiable(_fixtures);
  FootballFixture? get selectedFixture => _selectedFixture;
  List<FootballCuisineResultGroup> get cuisineGroups =>
      List.unmodifiable(_cuisineGroups);

  Future<void> init() async {
    if (_hasStarted) return;
    _hasStarted = true;
    await Future.wait([
      loadPubSearch(),
      loadFixtures(),
    ]);
  }

  Future<void> loadPubSearch() async {
    _isPubSearchLoading = true;
    _pubSearchError = null;
    notifyListeners();

    try {
      _pubResults = await _magicSearch(pubSearchQuery);
    } catch (_) {
      _pubResults = const [];
      _pubSearchError = 'Could not find football pubs just now.';
    } finally {
      _isPubSearchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFixtures() async {
    _areFixturesLoading = true;
    _fixturesError = null;
    notifyListeners();

    try {
      final loaded = await _loadFixtures();
      _fixtures = _visibleFixtures(loaded);
      if (_fixtures.isEmpty) {
        _fixtures = _visibleFixtures(_fallbackFixtures);
      }
    } catch (_) {
      _fixtures = _visibleFixtures(_fallbackFixtures);
      _fixturesError = _fixtures.isEmpty
          ? 'Could not load fixtures just now.'
          : 'Showing a temporary fixture set.';
    } finally {
      _areFixturesLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectFixture(FootballFixture fixture) async {
    _selectedFixture = fixture;
    _isCuisineSearchLoading = true;
    _cuisineSearchError = null;
    _cuisineGroups = [
      FootballCuisineResultGroup(
        country: fixture.countryAForSearch,
        cuisine: cuisineForCountry(fixture.countryAForSearch),
        results: const [],
      ),
      FootballCuisineResultGroup(
        country: fixture.countryBForSearch,
        cuisine: cuisineForCountry(fixture.countryBForSearch),
        results: const [],
      ),
    ];
    notifyListeners();

    final searches = _cuisineGroups.map((group) async {
      try {
        final results =
            await _magicSearch('${group.cuisine} restaurants near me');
        return FootballCuisineResultGroup(
          country: group.country,
          cuisine: group.cuisine,
          results: results,
        );
      } catch (_) {
        return FootballCuisineResultGroup(
          country: group.country,
          cuisine: group.cuisine,
          results: const [],
          error: 'Could not load ${group.cuisine} picks.',
        );
      }
    });

    _cuisineGroups = await Future.wait(searches);
    _isCuisineSearchLoading = false;
    if (_cuisineGroups.every((group) => group.hasError)) {
      _cuisineSearchError = 'Could not load food picks for this fixture.';
    }
    notifyListeners();
  }

  List<FootballFixture> _visibleFixtures(List<FootballFixture> fixtures) {
    final today = _ukDate(_now());
    final upcoming = fixtures.where((fixture) {
      final kickoff = fixture.kickoffTime;
      return kickoff != null && _ukDate(kickoff) == today;
    }).toList()
      ..sort((a, b) {
        return a.kickoffTime!.toUtc().compareTo(b.kickoffTime!.toUtc());
      });

    return upcoming.take(maxVisibleFixtures).toList(growable: false);
  }
}

DateTime _ukDate(DateTime value) {
  final ukTime = value.toUtc().add(const Duration(hours: 1));
  return DateTime.utc(ukTime.year, ukTime.month, ukTime.day);
}

String cuisineForCountry(String country) {
  final normalized = country.trim().toLowerCase();
  const cuisines = {
    'argentina': 'Argentinian',
    'australia': 'Australian',
    'belgium': 'Belgian',
    'brazil': 'Brazilian',
    'canada': 'Canadian',
    'china': 'Chinese',
    'croatia': 'Croatian',
    'england': 'British',
    'france': 'French',
    'germany': 'German',
    'ghana': 'Ghanaian',
    'india': 'Indian',
    'italy': 'Italian',
    'japan': 'Japanese',
    'korea': 'Korean',
    'mexico': 'Mexican',
    'morocco': 'Moroccan',
    'netherlands': 'Dutch',
    'nigeria': 'Nigerian',
    'portugal': 'Portuguese',
    'senegal': 'Senegalese',
    'spain': 'Spanish',
    'thailand': 'Thai',
    'turkey': 'Turkish',
    'turkiye': 'Turkish',
    'türkiye': 'Turkish',
    'usa': 'American',
    'united states': 'American',
    'united states of america': 'American',
  };

  return cuisines[normalized] ?? country.trim();
}

List<FootballFixture> get worldCupScheduleFixtures => _worldCupSchedule
    .map(
      (fixture) => FootballFixture(
        id: fixture.id,
        teamA: fixture.teamA,
        teamB: fixture.teamB,
        countryA: fixture.teamA,
        countryB: fixture.teamB,
        kickoffTime: fixture.kickoffUtc,
        competition: 'Group ${fixture.group}',
      ),
    )
    .toList(growable: false);

class _WorldCupScheduleFixture {
  const _WorldCupScheduleFixture({
    required this.day,
    required this.hour,
    required this.minute,
    required this.group,
    required this.teamA,
    required this.teamB,
  });

  final int day;
  final int hour;
  final int minute;
  final String group;
  final String teamA;
  final String teamB;

  String get id => 'wc-2026-06-${day.toString().padLeft(2, '0')}-'
      '${hour.toString().padLeft(2, '0')}${minute.toString().padLeft(2, '0')}-'
      '${_slug(teamA)}-${_slug(teamB)}';

  DateTime get kickoffUtc => DateTime.utc(2026, 6, day, hour, minute).subtract(
        const Duration(hours: 1),
      );
}

String _slug(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

const List<_WorldCupScheduleFixture> _worldCupSchedule = [
  _WorldCupScheduleFixture(
      day: 11,
      hour: 20,
      minute: 0,
      group: 'A',
      teamA: 'Mexico',
      teamB: 'South Africa'),
  _WorldCupScheduleFixture(
      day: 12,
      hour: 3,
      minute: 0,
      group: 'A',
      teamA: 'South Korea',
      teamB: 'Czechia'),
  _WorldCupScheduleFixture(
      day: 12,
      hour: 20,
      minute: 0,
      group: 'B',
      teamA: 'Canada',
      teamB: 'Bosnia and Herzegovina'),
  _WorldCupScheduleFixture(
      day: 13, hour: 2, minute: 0, group: 'D', teamA: 'USA', teamB: 'Paraguay'),
  _WorldCupScheduleFixture(
      day: 13,
      hour: 20,
      minute: 0,
      group: 'B',
      teamA: 'Qatar',
      teamB: 'Switzerland'),
  _WorldCupScheduleFixture(
      day: 13,
      hour: 23,
      minute: 0,
      group: 'C',
      teamA: 'Brazil',
      teamB: 'Morocco'),
  _WorldCupScheduleFixture(
      day: 14,
      hour: 2,
      minute: 0,
      group: 'C',
      teamA: 'Haiti',
      teamB: 'Scotland'),
  _WorldCupScheduleFixture(
      day: 14,
      hour: 5,
      minute: 0,
      group: 'D',
      teamA: 'Australia',
      teamB: 'Türkiye'),
  _WorldCupScheduleFixture(
      day: 14,
      hour: 18,
      minute: 0,
      group: 'E',
      teamA: 'Germany',
      teamB: 'Curaçao'),
  _WorldCupScheduleFixture(
      day: 14,
      hour: 21,
      minute: 0,
      group: 'F',
      teamA: 'Netherlands',
      teamB: 'Japan'),
  _WorldCupScheduleFixture(
      day: 15,
      hour: 0,
      minute: 0,
      group: 'E',
      teamA: 'Ivory Coast',
      teamB: 'Ecuador'),
  _WorldCupScheduleFixture(
      day: 15,
      hour: 3,
      minute: 0,
      group: 'F',
      teamA: 'Sweden',
      teamB: 'Tunisia'),
  _WorldCupScheduleFixture(
      day: 15,
      hour: 17,
      minute: 0,
      group: 'H',
      teamA: 'Spain',
      teamB: 'Cape Verde'),
  _WorldCupScheduleFixture(
      day: 15,
      hour: 20,
      minute: 0,
      group: 'G',
      teamA: 'Belgium',
      teamB: 'Egypt'),
  _WorldCupScheduleFixture(
      day: 15,
      hour: 23,
      minute: 0,
      group: 'H',
      teamA: 'Saudi Arabia',
      teamB: 'Uruguay'),
  _WorldCupScheduleFixture(
      day: 16,
      hour: 2,
      minute: 0,
      group: 'G',
      teamA: 'Iran',
      teamB: 'New Zealand'),
  _WorldCupScheduleFixture(
      day: 16,
      hour: 20,
      minute: 0,
      group: 'I',
      teamA: 'France',
      teamB: 'Senegal'),
  _WorldCupScheduleFixture(
      day: 16, hour: 23, minute: 0, group: 'I', teamA: 'Iraq', teamB: 'Norway'),
  _WorldCupScheduleFixture(
      day: 17,
      hour: 2,
      minute: 0,
      group: 'J',
      teamA: 'Argentina',
      teamB: 'Algeria'),
  _WorldCupScheduleFixture(
      day: 17,
      hour: 5,
      minute: 0,
      group: 'J',
      teamA: 'Austria',
      teamB: 'Jordan'),
  _WorldCupScheduleFixture(
      day: 17,
      hour: 18,
      minute: 0,
      group: 'K',
      teamA: 'Portugal',
      teamB: 'DR Congo'),
  _WorldCupScheduleFixture(
      day: 17,
      hour: 21,
      minute: 0,
      group: 'L',
      teamA: 'England',
      teamB: 'Croatia'),
  _WorldCupScheduleFixture(
      day: 18, hour: 0, minute: 0, group: 'L', teamA: 'Ghana', teamB: 'Panama'),
  _WorldCupScheduleFixture(
      day: 18,
      hour: 3,
      minute: 0,
      group: 'K',
      teamA: 'Uzbekistan',
      teamB: 'Colombia'),
  _WorldCupScheduleFixture(
      day: 18,
      hour: 17,
      minute: 0,
      group: 'A',
      teamA: 'Czechia',
      teamB: 'South Africa'),
  _WorldCupScheduleFixture(
      day: 18,
      hour: 20,
      minute: 0,
      group: 'B',
      teamA: 'Switzerland',
      teamB: 'Bosnia and Herzegovina'),
  _WorldCupScheduleFixture(
      day: 18,
      hour: 23,
      minute: 0,
      group: 'B',
      teamA: 'Canada',
      teamB: 'Qatar'),
  _WorldCupScheduleFixture(
      day: 19,
      hour: 2,
      minute: 0,
      group: 'A',
      teamA: 'Mexico',
      teamB: 'South Korea'),
  _WorldCupScheduleFixture(
      day: 19,
      hour: 20,
      minute: 0,
      group: 'D',
      teamA: 'USA',
      teamB: 'Australia'),
  _WorldCupScheduleFixture(
      day: 19,
      hour: 23,
      minute: 0,
      group: 'C',
      teamA: 'Scotland',
      teamB: 'Morocco'),
  _WorldCupScheduleFixture(
      day: 20,
      hour: 1,
      minute: 30,
      group: 'C',
      teamA: 'Brazil',
      teamB: 'Haiti'),
  _WorldCupScheduleFixture(
      day: 20,
      hour: 4,
      minute: 0,
      group: 'D',
      teamA: 'Türkiye',
      teamB: 'Paraguay'),
  _WorldCupScheduleFixture(
      day: 20,
      hour: 18,
      minute: 0,
      group: 'F',
      teamA: 'Netherlands',
      teamB: 'Sweden'),
  _WorldCupScheduleFixture(
      day: 20,
      hour: 21,
      minute: 0,
      group: 'E',
      teamA: 'Germany',
      teamB: 'Ivory Coast'),
  _WorldCupScheduleFixture(
      day: 21,
      hour: 1,
      minute: 0,
      group: 'E',
      teamA: 'Ecuador',
      teamB: 'Curaçao'),
  _WorldCupScheduleFixture(
      day: 21,
      hour: 5,
      minute: 0,
      group: 'F',
      teamA: 'Tunisia',
      teamB: 'Japan'),
  _WorldCupScheduleFixture(
      day: 21,
      hour: 17,
      minute: 0,
      group: 'H',
      teamA: 'Spain',
      teamB: 'Saudi Arabia'),
  _WorldCupScheduleFixture(
      day: 21,
      hour: 20,
      minute: 0,
      group: 'G',
      teamA: 'Belgium',
      teamB: 'Iran'),
  _WorldCupScheduleFixture(
      day: 21,
      hour: 23,
      minute: 0,
      group: 'H',
      teamA: 'Uruguay',
      teamB: 'Cape Verde'),
  _WorldCupScheduleFixture(
      day: 22,
      hour: 2,
      minute: 0,
      group: 'G',
      teamA: 'New Zealand',
      teamB: 'Egypt'),
  _WorldCupScheduleFixture(
      day: 22,
      hour: 18,
      minute: 0,
      group: 'J',
      teamA: 'Argentina',
      teamB: 'Austria'),
  _WorldCupScheduleFixture(
      day: 22, hour: 22, minute: 0, group: 'I', teamA: 'France', teamB: 'Iraq'),
  _WorldCupScheduleFixture(
      day: 23,
      hour: 1,
      minute: 0,
      group: 'I',
      teamA: 'Norway',
      teamB: 'Senegal'),
  _WorldCupScheduleFixture(
      day: 23,
      hour: 4,
      minute: 0,
      group: 'J',
      teamA: 'Jordan',
      teamB: 'Algeria'),
  _WorldCupScheduleFixture(
      day: 23,
      hour: 18,
      minute: 0,
      group: 'K',
      teamA: 'Portugal',
      teamB: 'Uzbekistan'),
  _WorldCupScheduleFixture(
      day: 23,
      hour: 21,
      minute: 0,
      group: 'L',
      teamA: 'England',
      teamB: 'Ghana'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 0,
      minute: 0,
      group: 'L',
      teamA: 'Panama',
      teamB: 'Croatia'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 3,
      minute: 0,
      group: 'K',
      teamA: 'Colombia',
      teamB: 'DR Congo'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 20,
      minute: 0,
      group: 'B',
      teamA: 'Switzerland',
      teamB: 'Canada'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 20,
      minute: 0,
      group: 'B',
      teamA: 'Bosnia and Herzegovina',
      teamB: 'Qatar'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 23,
      minute: 0,
      group: 'C',
      teamA: 'Scotland',
      teamB: 'Brazil'),
  _WorldCupScheduleFixture(
      day: 24,
      hour: 23,
      minute: 0,
      group: 'C',
      teamA: 'Morocco',
      teamB: 'Haiti'),
  _WorldCupScheduleFixture(
      day: 25,
      hour: 2,
      minute: 0,
      group: 'A',
      teamA: 'Czechia',
      teamB: 'Mexico'),
  _WorldCupScheduleFixture(
      day: 25,
      hour: 2,
      minute: 0,
      group: 'A',
      teamA: 'South Africa',
      teamB: 'South Korea'),
  _WorldCupScheduleFixture(
      day: 25,
      hour: 21,
      minute: 0,
      group: 'E',
      teamA: 'Ecuador',
      teamB: 'Germany'),
  _WorldCupScheduleFixture(
      day: 25,
      hour: 21,
      minute: 0,
      group: 'E',
      teamA: 'Curaçao',
      teamB: 'Ivory Coast'),
  _WorldCupScheduleFixture(
      day: 26,
      hour: 0,
      minute: 0,
      group: 'F',
      teamA: 'Tunisia',
      teamB: 'Netherlands'),
  _WorldCupScheduleFixture(
      day: 26, hour: 0, minute: 0, group: 'F', teamA: 'Japan', teamB: 'Sweden'),
  _WorldCupScheduleFixture(
      day: 26, hour: 3, minute: 0, group: 'D', teamA: 'Türkiye', teamB: 'USA'),
  _WorldCupScheduleFixture(
      day: 26,
      hour: 3,
      minute: 0,
      group: 'D',
      teamA: 'Paraguay',
      teamB: 'Australia'),
  _WorldCupScheduleFixture(
      day: 26,
      hour: 20,
      minute: 0,
      group: 'I',
      teamA: 'Norway',
      teamB: 'France'),
  _WorldCupScheduleFixture(
      day: 26,
      hour: 20,
      minute: 0,
      group: 'I',
      teamA: 'Senegal',
      teamB: 'Iraq'),
  _WorldCupScheduleFixture(
      day: 27,
      hour: 1,
      minute: 0,
      group: 'H',
      teamA: 'Uruguay',
      teamB: 'Spain'),
  _WorldCupScheduleFixture(
      day: 27,
      hour: 1,
      minute: 0,
      group: 'H',
      teamA: 'Cape Verde',
      teamB: 'Saudi Arabia'),
  _WorldCupScheduleFixture(
      day: 27,
      hour: 4,
      minute: 0,
      group: 'G',
      teamA: 'New Zealand',
      teamB: 'Belgium'),
  _WorldCupScheduleFixture(
      day: 27, hour: 4, minute: 0, group: 'G', teamA: 'Egypt', teamB: 'Iran'),
  _WorldCupScheduleFixture(
      day: 27,
      hour: 22,
      minute: 0,
      group: 'L',
      teamA: 'Panama',
      teamB: 'England'),
  _WorldCupScheduleFixture(
      day: 27,
      hour: 22,
      minute: 0,
      group: 'L',
      teamA: 'Croatia',
      teamB: 'Ghana'),
  _WorldCupScheduleFixture(
      day: 28,
      hour: 0,
      minute: 30,
      group: 'K',
      teamA: 'Colombia',
      teamB: 'Portugal'),
  _WorldCupScheduleFixture(
      day: 28,
      hour: 0,
      minute: 30,
      group: 'K',
      teamA: 'DR Congo',
      teamB: 'Uzbekistan'),
  _WorldCupScheduleFixture(
      day: 28,
      hour: 3,
      minute: 0,
      group: 'J',
      teamA: 'Jordan',
      teamB: 'Argentina'),
  _WorldCupScheduleFixture(
      day: 28,
      hour: 3,
      minute: 0,
      group: 'J',
      teamA: 'Algeria',
      teamB: 'Austria'),
];
