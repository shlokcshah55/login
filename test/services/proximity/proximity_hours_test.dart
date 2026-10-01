import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/proximity/proximity_hours.dart';

Map<String, dynamic> _period(int od, String ot, int cd, String ct) => {
      'open': {'day': od, 'time': ot},
      'close': {'day': cd, 'time': ct},
    };

void main() {
  // 2026-10-05 is a Monday (Google day 1).
  DateTime monday(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

  final weekdayLunchToLate = [_period(1, '1200', 1, '2300')];

  test('open in the middle of a period', () {
    final s =
        evaluateOpeningStatus(now: monday(15), periods: weekdayLunchToLate);
    expect(s.state, OpenState.open);
    expect(s.closesAt, monday(23));
  });

  test('closed before opening and after closing', () {
    expect(
      evaluateOpeningStatus(now: monday(10), periods: weekdayLunchToLate).state,
      OpenState.closed,
    );
    expect(
      evaluateOpeningStatus(now: monday(23, 30), periods: weekdayLunchToLate)
          .state,
      OpenState.closed,
    );
  });

  test('closing soon inside the window', () {
    final s = evaluateOpeningStatus(
      now: monday(22, 45),
      periods: weekdayLunchToLate,
    );
    expect(s.state, OpenState.closingSoon);
  });

  test('period wrapping past midnight stays open on the next day', () {
    final friNight = [_period(5, '1200', 6, '0200')];
    // Saturday 00:30
    final sat = DateTime(2026, 10, 10, 0, 30);
    expect(evaluateOpeningStatus(now: sat, periods: friNight).state,
        OpenState.open);
  });

  test('Saturday night period wraps into early Sunday', () {
    final satNight = [_period(6, '1800', 0, '0200')];
    final sunday = DateTime(2026, 10, 11, 1, 0);
    expect(evaluateOpeningStatus(now: sunday, periods: satNight).state,
        OpenState.open);
  });

  test('24/7 place (open with no close) is always open', () {
    final s = evaluateOpeningStatus(now: monday(3), periods: [
      {
        'open': {'day': 0, 'time': '0000'}
      }
    ]);
    expect(s.state, OpenState.open);
  });

  test('falls back to openNow, then unknown', () {
    expect(evaluateOpeningStatus(now: monday(12), openNow: false).state,
        OpenState.closed);
    expect(evaluateOpeningStatus(now: monday(12), openNow: true).state,
        OpenState.open);
    expect(evaluateOpeningStatus(now: monday(12)).state, OpenState.unknown);
  });

  test('malformed periods are treated as no data', () {
    final s = evaluateOpeningStatus(now: monday(12), periods: [
      {'open': 'nonsense'},
      'also nonsense',
    ]);
    expect(s.state, OpenState.unknown);
  });
}
