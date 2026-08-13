/// Why a session ended. Emitted with every sign-out so production logouts can
/// be attributed to a specific code path.
enum AuthSignOutReason {
  userInitiated('user_initiated'),
  startupSessionInvalid('startup_session_invalid'),
  authEventSessionInvalid('auth_event_session_invalid'),
  authStreamFatalError('auth_stream_fatal_error'),
  passwordRecoveryCompleted('password_recovery_completed'),
  accountDeleted('account_deleted');

  const AuthSignOutReason(this.wireName);

  final String wireName;
}
