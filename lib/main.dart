import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/firebase_options.dart';
import 'package:login/models/location_model.dart';
import 'package:login/notifications/notificationService.dart';
import 'package:login/notifications/backgroundTaskService.dart';
import 'package:login/pages/auth_handler.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/permissions/permissions.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:provider/provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestLocationPermission();
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
        primarySwatch: Colors.blue,
      ),
      home: const AuthHandler(),
    );
  }
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
        const Center(child: Text('Profile')),
      ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
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

