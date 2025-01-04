import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/firebase_options.dart';
import 'package:login/pages/auth_handler.dart';
import 'pages/home_page.dart'; 



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
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
  final String userId; // Add user as a parameter

  const MainScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userData;

  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchUserData();
    setState(() {
      _pages = [
        HomePage(userData: _userData),
        const Center(child: Text('Search')),
        const Center(child: Text('Notifications')),
        const Center(child: Text('Profile')),
      ];
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(widget.userId)
              .get();
      print("Main: User snapshot: $userSnapshot");
      if (userSnapshot.exists) {
        setState(() {
          _userData = userSnapshot.data();
          print('Main: User data: $_userData');
        });
      } else {
        // Sign out - invalid user and return to login screen
        debugPrint('No user data found for ID: ${widget.userId}');
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      await FirebaseAuth.instance.signOut();
    }
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

