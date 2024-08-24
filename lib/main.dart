import 'package:flutter/material.dart';
import 'pages/home_page.dart'; 
// import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
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
    return Scaffold(
      body: _pages[_currentIndex],
      appBar: _currentIndex == 0
          ? AppBar(
        title: 
        // Column(
        //   mainAxisSize: MainAxisSize.min, // Shrinks the column to fit its children
          // children: [
          //   // Add your logo at the top
          //   Padding(
          //     padding: const EdgeInsets.only(bottom: 8.0), // Adjust the padding as needed
          //     child: Image.asset(
          //       'lib/assets/pinitLogo.png', // Make sure to replace with the correct path to your logo
          //       height: 40, // Adjust the size as needed
          //     ),
          //   ),
            // Row with buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      // Handle "Following" button press
                    },
                    child: const Text(
                      'Following',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        // Handle "For you" button press
                      },
                      child: const Text(
                        'For you',
                        style: TextStyle(color: Colors.black), // Black color to highlight as selected
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      // Handle "Your Pins" button press
                    },
                    child: const Text(
                      'Your Pins',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
        centerTitle: true, // Center the column (title) horizontally
        automaticallyImplyLeading: false,
      )
          : null,
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