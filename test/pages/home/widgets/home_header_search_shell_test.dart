import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/home/widgets/home_header_search_shell.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/themes/pinit_theme.dart';
import 'package:provider/provider.dart';

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

  testWidgets('predictive inline completion is hidden while rows load', (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness());

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const Key('header_search_text_field')), 'cof');
    await tester.pump();

    expect(
      find.byKey(const Key('header_search_inline_completion')),
      findsNothing,
    );
    expect(find.text('coffee run'), findsNothing);
    expect(
      find.byKey(const Key('header_search_list_item_place--1')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Coffee Run'), findsOneWidget);
    expect(
      find.byKey(const Key('header_search_list_item_place--1')),
      findsOneWidget,
    );
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

    await tester.longPress(
      find.byKey(const Key('header_search_list_item_place--1')),
    );
    await tester.pump();

    expect(find.byKey(const Key('header_search_overlay')), findsOneWidget);
    expect(key.currentState!.previewStartCount, 1);
  });

  testWidgets('place rows expose a compact bookmark save action', (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness());

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.enterText(
      find.byKey(const Key('header_search_text_field')),
      'cof',
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.byKey(const Key('header_search_save_tick_place--1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('header_search_save_tick_place--1')),
        matching: find.byIcon(Icons.bookmark_border_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('header_search_save_tick_place--1')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('Supabase search rows show compact local stats', (
    tester,
  ) async {
    await tester.pumpWidget(const _HeaderSearchHarness(
      searchLocation: _SearchLocationVariant.supabaseStats,
    ));

    await tester.tap(find.byKey(const Key('home_header_search_entry')));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.enterText(
      find.byKey(const Key('header_search_text_field')),
      'cof',
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('84% match'), findsOneWidget);
    expect(find.text('18 saves'), findsOneWidget);
    expect(find.text('Maya saved'), findsOneWidget);
  });
}

enum _SearchLocationVariant {
  plain,
  supabaseStats,
}

class _HeaderSearchHarness extends StatefulWidget {
  final bool showFooter;
  final _SearchLocationVariant searchLocation;

  const _HeaderSearchHarness({
    super.key,
    this.showFooter = false,
    this.searchLocation = _SearchLocationVariant.plain,
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
          query: query,
          inlineCompletion: normalized == 'cof' ? 'coffee run' : null,
          quickSuggestions: const [],
          placeItems: const [],
          isLoading: true,
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
            placeItems: [
              SearchSuggestionItem.place(
                _location(
                  -1,
                  'Coffee Run',
                  variant: widget.searchLocation,
                ),
              ),
            ],
            isLoading: false,
          ),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PinitTheme.dark(),
      home: ChangeNotifierProvider(
        create: (_) => BottomNavVisibilityProvider(),
        child: Scaffold(
          body: HomeHeaderSearchShell(
            state: _state,
            controller: _controller,
            focusNode: _focusNode,
            onEntryTap: () {
              setState(() {
                _state = _state.copyWith(isActive: true);
              });
            },
            showSuggestionsPanel: false,
            onToggleSuggestionsPanel: () {},
            onMagicSuggestionSelected: (_) {},
            onOpenBubbles: () {},
            isMagicSearchActive: false,
            onSubmitMagicSearch: () {},
            onDismissMagicResults: () {},
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
      ),
    );
  }
}

LocationModel _location(
  int id,
  String name, {
  _SearchLocationVariant variant = _SearchLocationVariant.plain,
}) {
  return LocationModel(
    locationId: id,
    name: name,
    lat: 51.5074,
    lng: -0.1278,
    rating: 4.7,
    savedCount: variant == _SearchLocationVariant.supabaseStats ? 18 : null,
    matchScore: variant == _SearchLocationVariant.supabaseStats ? 0.84 : null,
    friendSaves: variant == _SearchLocationVariant.supabaseStats
        ? const [
            FriendSave(
              friendId: 'friend-1',
              friendName: 'Maya',
              actionType: 'save',
              timestamp: '2026-04-29T10:00:00Z',
            ),
          ]
        : const [],
    createdAt: DateTime(2024),
  );
}
