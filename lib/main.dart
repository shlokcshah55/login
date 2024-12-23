import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:login/firebase_options.dart';
import 'package:login/pages/auth_handler.dart';
import 'pages/home_page.dart'; 
// import 'package:logging/logging.dart';

import 'firebase_utils/firebase_api.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // _setupLogging();
  runApp(const MyApp());
}

// void _setupLogging() {
//   Logger.root.level = Level.ALL; // Set the logging level
//   Logger.root.onRecord.listen((record) {
//     print('${record.level.name}: ${record.time}: ${record.message}');
//   });
// }

class MyApp extends StatelessWidget {
  // Logger logger = Logger('MyApp');

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthHandler(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    const Center(child: Text('Search')),
    const Center(child: Text('Notifications')),
    const Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    getUsers();

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

