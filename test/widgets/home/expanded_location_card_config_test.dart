import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';

void main() {
  test('resolves shared video urls on open by default', () {
    final card = ExpandedLocationCard(
      location: LocationModel(
        locationId: 42,
        name: 'Noodle Yard',
        createdAt: DateTime.utc(2026, 5, 29),
      ),
      onClose: _noop,
    );

    expect(card.resolveSharedVideoUrlOnOpen, isTrue);
  });
}

void _noop() {}
