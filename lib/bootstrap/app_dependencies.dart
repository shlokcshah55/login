import 'package:login/services/google_place_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/supabase/service.dart';

class DeferredAppInitializer {
  DeferredAppInitializer({
    required Future<void> Function() initialize,
  }) : _initialize = initialize;

  final Future<void> Function() _initialize;
  Future<void>? _active;

  Future<void> start() => _active ??= _initialize();
}

class AppDependencies {
  final SupabaseService supabaseService;
  final GooglePlacesService googlePlacesService;
  final StartupCacheCoordinator startupCacheCoordinator;
  final DeferredAppInitializer deferredInitializer;

  AppDependencies({
    required this.supabaseService,
    required this.googlePlacesService,
    required this.startupCacheCoordinator,
    required this.deferredInitializer,
  });
}
