import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/football_fixture.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/football_discovery_view_model.dart';

void main() {
  LocationModel place(int id, String name) {
    return LocationModel(
      locationId: id,
      name: name,
      createdAt: DateTime(2026, 1, 1),
      preference: LocationPreference.search,
    );
  }

  test('init loads server fixtures and runs football pub magic search',
      () async {
    final queries = <String>[];
    final viewModel = FootballDiscoveryViewModel(
      now: () => DateTime.utc(2026, 6, 18, 11),
      loadFixtures: () async => [
        FootballFixture(
          id: 'fra-sen',
          teamA: 'France',
          teamB: 'Senegal',
          kickoffTime: DateTime.utc(2026, 6, 18, 16),
        ),
      ],
      magicSearch: (query) async {
        queries.add(query);
        return [place(1, 'The Sports Pub')];
      },
    );

    await viewModel.init();

    expect(queries, ['pubs or sports bars near me showing football']);
    expect(viewModel.fixtures, hasLength(1));
    expect(viewModel.pubResults.single.name, 'The Sports Pub');
    expect(viewModel.isPubSearchLoading, false);
    expect(viewModel.areFixturesLoading, false);
  });

  test('fallback schedule shows only fixtures on the current UK date',
      () async {
    final viewModel = FootballDiscoveryViewModel(
      now: () => DateTime.utc(2026, 6, 18, 11), // Thu 18 Jun, 12:00 BST.
      loadFixtures: () async => throw Exception('server unavailable'),
      magicSearch: (_) async => const [],
    );

    await viewModel.loadFixtures();

    expect(viewModel.fixtures.map((fixture) => fixture.displayTitle), [
      'Ghana vs Panama',
      'Uzbekistan vs Colombia',
      'Czechia vs South Africa',
      'Switzerland vs Bosnia and Herzegovina',
      'Canada vs Qatar',
    ]);
    expect(viewModel.fixtures.first.kickoffTime, DateTime.utc(2026, 6, 17, 23));
    expect(
      viewModel.fixtures.any(
        (fixture) => fixture.displayTitle == 'Mexico vs South Korea',
      ),
      false,
    );
  });

  test(
      'server fixtures are filtered to the current UK date when kickoff exists',
      () async {
    final viewModel = FootballDiscoveryViewModel(
      now: () => DateTime.utc(2026, 6, 18, 19, 30),
      loadFixtures: () async => [
        FootballFixture(
          id: 'past',
          teamA: 'Ghana',
          teamB: 'Panama',
          kickoffTime: DateTime.utc(2026, 6, 17, 23),
        ),
        FootballFixture(
          id: 'same-day-late',
          teamA: 'Canada',
          teamB: 'Qatar',
          kickoffTime: DateTime.utc(2026, 6, 18, 22),
        ),
        FootballFixture(
          id: 'tomorrow',
          teamA: 'Mexico',
          teamB: 'South Korea',
          kickoffTime: DateTime.utc(2026, 6, 19, 1),
        ),
      ],
      magicSearch: (_) async => const [],
    );

    await viewModel.loadFixtures();

    expect(
      viewModel.fixtures.map((fixture) => fixture.id),
      ['past', 'same-day-late'],
    );
  });

  test('selectFixture searches both cuisines and groups results', () async {
    final queries = <String>[];
    final viewModel = FootballDiscoveryViewModel(
      loadFixtures: () async => const [],
      magicSearch: (query) async {
        queries.add(query);
        if (query.startsWith('French')) {
          return [place(2, 'Le Bistro')];
        }
        return [place(3, 'Dakar Kitchen')];
      },
    );
    const fixture = FootballFixture(
      id: 'fra-sen',
      teamA: 'France',
      teamB: 'Senegal',
      countryA: 'France',
      countryB: 'Senegal',
    );

    await viewModel.selectFixture(fixture);

    expect(queries, [
      'French restaurants near me',
      'Senegalese restaurants near me',
    ]);
    expect(viewModel.selectedFixture?.id, 'fra-sen');
    expect(viewModel.cuisineGroups, hasLength(2));
    expect(viewModel.cuisineGroups[0].title, 'French restaurants');
    expect(viewModel.cuisineGroups[0].results.single.name, 'Le Bistro');
    expect(viewModel.cuisineGroups[1].title, 'Senegalese restaurants');
    expect(viewModel.cuisineGroups[1].results.single.name, 'Dakar Kitchen');
    expect(viewModel.isCuisineSearchLoading, false);
  });
}
