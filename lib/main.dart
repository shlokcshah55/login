import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/firebase_options.dart';
import 'package:login/models/location_model.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/notifications/backgroundTaskService.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile_page.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:provider/provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocationModel.initializeCustomMarker();
  await dotenv.load(); 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().initialize();
  await BackgroundTaskService().initialize();
  
  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => AppStateProvider()),
    ],
    child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Primary color swatch
        primarySwatch: createMaterialColor(Color(0xFFE09132)), // Using #E09132 as the primary color
        // Background color
        scaffoldBackgroundColor: Color(0xFFFFEFCD), // #FFEFCD as the background color
        // Text theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF424520)), // #424520 as the primary text color
          bodyMedium: TextStyle(color: Color(0xFF424520)),
          titleLarge: TextStyle(color: Color(0xFF424520)),
          titleMedium: TextStyle(color: Color(0xFF424520)),
        ),
        // Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFA58E74), // #A58E74 as the button background color
            foregroundColor: Color(0xFFFFEFCD), // #FFEFCD as the button text color
          ),
        ),
        // Floating action button theme
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFE09132), // #E09132 as the FAB background color
          foregroundColor: Color(0xFFFFEFCD), // #FFEFCD as the FAB icon color
        ),
        // Card theme
        cardTheme: CardTheme(
          color: Color.fromARGB(255, 241, 231, 219), // #A58E74 as the card background color
          elevation: 2,
          margin: EdgeInsets.all(8),
        ),

        bottomAppBarTheme: BottomAppBarTheme(
          color: Color(0xFFE09132), // #E09132 as the bottom app bar color
        ),
      ),
      home: const AuthHandler(),
    );
  }
}

// Helper function to create a MaterialColor from a single color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}


class MainScreen extends StatefulWidget {

  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
        const HomePage(),
        const Center(child: Text('Search')),
        const Center(child: Text('Notifications')),
        ProfilePage(),
      ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).bottomAppBarTheme.color,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person, color: Colors.black), label: ''),
        ],
      ),
    );
  }
}

