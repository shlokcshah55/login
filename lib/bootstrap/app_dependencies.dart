import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/service.dart';

class AppDependencies {
  final SupabaseService supabaseService;
  final GooglePlacesService googlePlacesService;

  AppDependencies({
    required this.supabaseService,
    required this.googlePlacesService,
  });
}
