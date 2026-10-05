import 'package:login/services/analytics_service.dart';

/// Onboarding step ids. These are stored server-side as the `step` property.
enum OnboardingStep {
  introVideo('intro_video'),
  account('account'),
  firstSave('first_save'),
  preferences('preferences'),
  bubble('bubble');

  const OnboardingStep(this.id);
  final String id;
}

/// Funnel events for the sign-up/onboarding flow. Event names must stay in
/// sync with the allowlist in `track_app_event` (see the
/// `onboarding_analytics_events` migration), otherwise the server drops them.
class OnboardingAnalytics {
  OnboardingAnalytics({required this.flow, AnalyticsService? analytics})
      : _analytics = analytics ?? AnalyticsService();

  /// How the user signed up: `email`, `google` or `apple`.
  final String flow;
  final AnalyticsService _analytics;

  final Map<OnboardingStep, DateTime> _viewedAt = {};
  DateTime? _accountCreatedAt;

  /// Call once the account exists; later `first_save` timing is measured
  /// from here (the 60 second goal).
  void markAccountCreated() => _accountCreatedAt ??= DateTime.now();

  void viewed(OnboardingStep step) {
    _viewedAt[step] = DateTime.now();
    _emit('onboarding_step_viewed', step);
  }

  void completed(OnboardingStep step, {String? method}) =>
      _emit('onboarding_step_completed', step,
          method: method, elapsedMs: _sinceViewed(step));

  void skipped(OnboardingStep step) =>
      _emit('onboarding_step_skipped', step, elapsedMs: _sinceViewed(step));

  /// First place saved. `elapsed_ms` is time since account creation.
  void firstSave({String? method}) => _emit(
        'onboarding_first_save',
        OnboardingStep.firstSave,
        method: method,
        elapsedMs: _accountCreatedAt == null
            ? null
            : DateTime.now().difference(_accountCreatedAt!).inMilliseconds,
      );

  void finished() => _emit(
        'onboarding_finished',
        OnboardingStep.bubble,
        elapsedMs: _accountCreatedAt == null
            ? null
            : DateTime.now().difference(_accountCreatedAt!).inMilliseconds,
      );

  int? _sinceViewed(OnboardingStep step) {
    final at = _viewedAt[step];
    return at == null ? null : DateTime.now().difference(at).inMilliseconds;
  }

  void _emit(
    String name,
    OnboardingStep step, {
    String? method,
    int? elapsedMs,
  }) {
    _analytics.track(
      eventName: name,
      eventCategory: 'onboarding',
      screenName: 'onboarding',
      properties: {
        'step': step.id,
        'flow': flow,
        if (method != null) 'method': method,
        if (elapsedMs != null) 'elapsed_ms': elapsedMs,
      },
    );
  }
}
