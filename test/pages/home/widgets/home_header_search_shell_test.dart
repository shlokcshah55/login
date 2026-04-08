import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/home/widgets/home_header_search_shell.dart';
import 'package:login/themes/pinit_theme.dart';

void main() {
  testWidgets('search opens as a full-screen surface without backdrop blur', (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness());

    expect(find.byKey(const Key('header_search_overlay')), findsNothing);

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('header_search_overlay')), findsOneWidget);
    expect(find.byKey(const Key('header_search_fullscreen_layer')),
        findsOneWidget);
    expect(
        find.byKey(const Key('header_search_mist_background')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    final fullscreenSize = tester.getSize(
      find.byKey(const Key('header_search_fullscreen_layer')),
    );
    final scaffoldSize = tester.getSize(find.byType(Scaffold));
    expect(fullscreenSize.height, greaterThanOrEqualTo(scaffoldSize.height));
  });

  testWidgets('footer content is not visible once full-screen search is active',
      (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness(showFooter: true));

    expect(find.text('Footer Chips'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Footer Chips'), findsNothing);
  });

  testWidgets('inline completion renders before full rows progressively fill', (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness());

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('header_search_text_field')), 'cof');
    await tester.pump();

    expect(find.byKey(const Key('header_search_inline_completion')),
        findsOneWidget);
    expect(find.text('coffee run'), findsOneWidget);
    expect(find.byKey(const Key('header_search_card_place-1')), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Coffee Run'), findsOneWidget);
    expect(find.byKey(const Key('header_search_card_place-1')), findsOneWidget);
  });

  testWidgets('row order changes for people intent', (tester) async {
    await tester.pumpWidget(const _HeaderSearchHarness());

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('header_search_text_field')),
      '@alex',
    );
    await tester.pump(const Duration(milliseconds: 20));

    final sectionLabels = tester
        .widgetList<Text>(find.byType(Text))
        .where((widget) => widget.key is ValueKey<String>)
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();

    expect(sectionLabels.take(3).toList(), ['People', 'Places', 'Recommended']);
  });

  testWidgets('long press previews a pin without dismissing search', (
    tester,
  ) async {
    final key = GlobalKey<_HeaderSearchHarnessState>();
    await tester.pumpWidget(_HeaderSearchHarness(key: key));

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.enterText(
      find.byKey(const Key('header_search_text_field')),
      'cof',
    );
    await tester.pump(const Duration(milliseconds: 20));

    await tester.longPress(find.byKey(const Key('header_search_card_place-1')));
    await tester.pump();

    expect(find.byKey(const Key('header_search_overlay')), findsOneWidget);
    expect(key.currentState!.previewStartCount, 1);
  });
}

class _HeaderSearchHarness extends StatefulWidget {
  final bool showFooter;

  const _HeaderSearchHarness({
    super.key,
    this.showFooter = false,
  });

  @override
  State<_HeaderSearchHarness> createState() => _HeaderSearchHarnessState();
}

class _HeaderSearchHarnessState extends State<_HeaderSearchHarness> {
  HeaderSearchState _state = HeaderSearchState.initial();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int previewStartCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String query) {
    final normalized = query.trim().toLowerCase();
    setState(() {
      _state = _state.copyWith(
        query: query,
        result: HeaderSearchResultModel(
          intent: normalized.startsWith('@')
              ? SearchIntentType.people
              : SearchIntentType.place,
          query: query,
          inlineCompletion: normalized == 'cof' ? 'coffee run' : null,
          quickSuggestions: const [],
          databaseMatches: const [],
          sections: _emptySections(
            normalized.startsWith('@')
                ? SearchIntentType.people
                : SearchIntentType.place,
          ),
          completedStages: const {WaterfallStage.inlineCompletion},
          isSearching: true,
        ),
      );
    });

    Future<void>.delayed(const Duration(milliseconds: 10), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _state = _state.copyWith(
          result: _state.result.copyWith(
            sections: normalized.startsWith('@')
                ? [
                    HeaderSearchSectionModel(
                      type: SearchSectionType.people,
                      title: 'People',
                      items: const [
                        SearchSuggestionItem(
                          id: 'person-1',
                          kind: SearchSuggestionKind.person,
                          title: 'Alex Morgan',
                        ),
                      ],
                    ),
                    HeaderSearchSectionModel(
                      type: SearchSectionType.places,
                      title: 'Places',
                      items: const [
                        SearchSuggestionItem(
                          id: 'place-2',
                          kind: SearchSuggestionKind.place,
                          title: 'Alex Cafe',
                        ),
                      ],
                    ),
                    HeaderSearchSectionModel(
                      type: SearchSectionType.naturalLanguage,
                      title: 'Recommended',
                      items: const [
                        SearchSuggestionItem(
                          id: 'natural-2',
                          kind: SearchSuggestionKind.naturalLanguage,
                          title: 'A social brunch spot',
                        ),
                      ],
                    ),
                  ]
                : [
                    HeaderSearchSectionModel(
                      type: SearchSectionType.places,
                      title: 'Places',
                      items: [
                        SearchSuggestionItem.place(
                          _location(1, 'Coffee Run'),
                        ),
                      ],
                    ),
                    HeaderSearchSectionModel(
                      type: SearchSectionType.naturalLanguage,
                      title: 'Recommended',
                      items: [
                        SearchSuggestionItem.naturalLanguageResult(
                          _location(2, 'Cozy Corner'),
                        ),
                      ],
                    ),
                    const HeaderSearchSectionModel(
                      type: SearchSectionType.people,
                      title: 'People',
                    ),
                  ],
            completedStages: const {
              WaterfallStage.inlineCompletion,
              WaterfallStage.fullResults,
            },
            isSearching: false,
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PinitTheme.dark(),
      home: Scaffold(
        body: HomeHeaderSearchShell(
          state: _state,
          controller: _controller,
          focusNode: _focusNode,
          onEntryTap: () {
            setState(() {
              _state = _state.copyWith(isActive: true);
            });
          },
          onMagicSearchTap: () {},
          onDismiss: () {
            setState(() {
              _state = _state.copyWith(isActive: false);
            });
          },
          onQueryChanged: _handleQueryChanged,
          onSuggestionSelected: (_) {},
          onPreviewStart: (location) {
            previewStartCount += 1;
            setState(() {
              _state = _state.copyWith(
                isPreviewingMap: true,
                previewedLocation: location,
              );
            });
          },
          onPreviewEnd: () {
            setState(() {
              _state = _state.copyWith(
                isPreviewingMap: false,
                clearPreviewedLocation: true,
              );
            });
          },
          footer: widget.showFooter
              ? const Center(child: Text('Footer Chips'))
              : null,
        ),
      ),
    );
  }

  List<HeaderSearchSectionModel> _emptySections(SearchIntentType intent) {
    switch (intent) {
      case SearchIntentType.people:
        return const [
          HeaderSearchSectionModel(
            type: SearchSectionType.people,
            title: 'People',
            isLoading: true,
          ),
          HeaderSearchSectionModel(
            type: SearchSectionType.places,
            title: 'Places',
            isLoading: true,
          ),
          HeaderSearchSectionModel(
            type: SearchSectionType.naturalLanguage,
            title: 'Recommended',
            isLoading: true,
          ),
        ];
      case SearchIntentType.place:
      case SearchIntentType.naturalLanguage:
      case SearchIntentType.mixed:
        return const [
          HeaderSearchSectionModel(
            type: SearchSectionType.places,
            title: 'Places',
            isLoading: true,
          ),
          HeaderSearchSectionModel(
            type: SearchSectionType.naturalLanguage,
            title: 'Recommended',
            isLoading: true,
          ),
          HeaderSearchSectionModel(
            type: SearchSectionType.people,
            title: 'People',
            isLoading: true,
          ),
        ];
    }
  }
}

LocationModel _location(int id, String name) {
  return LocationModel(
    locationId: id,
    name: name,
    lat: 51.5074,
    lng: -0.1278,
    createdAt: DateTime(2024),
  );
}
