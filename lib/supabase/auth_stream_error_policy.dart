import 'package:login/supabase/helpers/auth_failure.dart';

/// Whether an error delivered on `onAuthStateChange`'s error channel should end
/// the session.
///
/// gotrue removes the session and emits `AuthChangeEvent.signedOut` itself for
/// fatal refresh failures, so in practice only transient errors arrive here.
/// The fatal branch exists as a safety net, not as the expected path.
bool shouldEndSessionForAuthStreamError(Object error) =>
    classifyAuthFailure(error) == AuthFailureKind.fatal;
