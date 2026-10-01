enum OpenState { open, closingSoon, closed, unknown }

class OpeningStatus {
  const OpeningStatus(this.state, {this.closesAt});

  final OpenState state;

  /// When the current open period ends. Null if unknown or always open.
  final DateTime? closesAt;
}

const int _minutesPerDay = 24 * 60;
const int _minutesPerWeek = 7 * _minutesPerDay;

/// Works out whether a place is open at [now] from Google-style
/// `opening_hours_periods`, falling back to [openNow] when periods are
/// missing. Unknown hours return [OpenState.unknown] so callers can choose to
/// allow rather than suppress.
///
/// [now] is device-local time, which is the place's local time for any place
/// the user is physically near.
OpeningStatus evaluateOpeningStatus({
  required DateTime now,
  List<dynamic>? periods,
  bool? openNow,
  Duration closingSoonWindow = const Duration(minutes: 30),
}) {
  final parsed = _parsePeriods(periods);
  if (parsed == null) {
    if (openNow == null) return const OpeningStatus(OpenState.unknown);
    return OpeningStatus(openNow ? OpenState.open : OpenState.closed);
  }
  if (parsed.isEmpty) return const OpeningStatus(OpenState.open);

  // Google weekday: Sunday = 0. Dart: Monday = 1 .. Sunday = 7.
  final nowMinute =
      (now.weekday % 7) * _minutesPerDay + now.hour * 60 + now.minute;

  for (final p in parsed) {
    // Check the period as-is and shifted a week back, so periods that wrap
    // past Saturday night still match early-Sunday times.
    for (final shift in const [0, _minutesPerWeek]) {
      final at = nowMinute + shift;
      if (at >= p.open && at < p.close) {
        final remaining = p.close - at;
        final closesAt = now.add(Duration(minutes: remaining));
        final soon = remaining <= closingSoonWindow.inMinutes;
        return OpeningStatus(
          soon ? OpenState.closingSoon : OpenState.open,
          closesAt: closesAt,
        );
      }
    }
  }
  return const OpeningStatus(OpenState.closed);
}

class _Period {
  const _Period(this.open, this.close);
  final int open;
  final int close;
}

/// Null when there is no usable data. An empty list means "always open"
/// (Google's 24/7 shape: a single open period with no close).
List<_Period>? _parsePeriods(List<dynamic>? periods) {
  if (periods == null || periods.isEmpty) return null;

  final result = <_Period>[];
  for (final raw in periods) {
    if (raw is! Map) continue;
    final open = _toMinuteOfWeek(raw['open']);
    if (open == null) continue;
    final closeRaw = raw['close'];
    if (closeRaw == null) return const <_Period>[];
    var close = _toMinuteOfWeek(closeRaw);
    if (close == null) continue;
    if (close <= open) close += _minutesPerWeek;
    result.add(_Period(open, close));
  }
  return result.isEmpty ? null : result;
}

int? _toMinuteOfWeek(dynamic point) {
  if (point is! Map) return null;
  final day = point['day'];
  final time = point['time']?.toString();
  if (day is! int || time == null || time.length != 4) return null;
  final hour = int.tryParse(time.substring(0, 2));
  final minute = int.tryParse(time.substring(2, 4));
  if (hour == null || minute == null || day < 0 || day > 6) return null;
  return day * _minutesPerDay + hour * 60 + minute;
}
