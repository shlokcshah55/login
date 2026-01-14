import 'package:flutter/material.dart';
import 'package:login/bootstrap/app_dependencies.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/dynamic_nav_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:provider/provider.dart';

class AppProviders extends StatelessWidget {
  final AppDependencies dependencies;
  final Widget child;

  const AppProviders({
    Key? key,
    required this.dependencies,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: dependencies.supabaseService),
        ChangeNotifierProvider(create: (_) => UserDataProvider()),
        ChangeNotifierProvider(
          create: (_) => LocationListManager(dependencies.googlePlacesService),
        ),
        ChangeNotifierProvider(create: (_) => MapStateProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavVisibilityProvider()),
        ChangeNotifierProvider(create: (_) => DynamicNavProvider()),
      ],
      child: child,
    );
  }
}
