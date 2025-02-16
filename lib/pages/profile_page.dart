import 'package:flutter/material.dart';
import 'package:login/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:login/providers/app_data_provider.dart'; // Import the AppStateProvider

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context);

    // Extract user data from AppStateProvider
    final username = appStateProvider.userData['username'] ?? "Trollmaster";
    final bio = appStateProvider.userData['bio'] ?? "Tell us more about you! Tap the dot menu to edit your profile 😊";
    final fullName = appStateProvider.userData['fullname'] ?? "No Name";
    final tags = appStateProvider.userData['tags'] ?? ["London", "Brighton"];
    final locations = appStateProvider.userData['locations'] ?? [
      {"name": "London", "pins": 2, "image": "assets/london.jpg"},
      {"name": "Brighton", "pins": 1, "image": "assets/brighton.jpg"},
    ];


    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16.0,
            bottom: 16.0,
            left: 16.0,
            right: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    username,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      _showLogoutDialog(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, size: 40),
                  ),
                  _statColumn(appStateProvider.savedLocations.length.toString(), "Pins"),
                  _statColumn(appStateProvider.userData["followers"].length.toString(), "Followers"),
                  _statColumn(appStateProvider.userData["following"].length.toString(), "Following"),
                ],
              ),
              const SizedBox(height: 20),
          
              Column(
                children: [
                  Row(
                    children: [
                      Text(
                        fullName,
                        textAlign: TextAlign.left,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        bio,
                        textAlign: TextAlign.left,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton("Share profile", Icons.share),
                  _actionButton("Add friends", Icons.person_add),
                ],
              ),

              const SizedBox(height: 20),

              // Tags Section
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: tags.map<Widget>((tag) => _tagChip(tag)).toList(),
                ),
              ),

              // Content Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3 / 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: locations.length + 1,
                itemBuilder: (context, index) {
                  if (index == locations.length) {
                    return _addCard();
                  }
                  final location = locations[index];
                  return _locationCard(
                      location["image"]!, location["name"]!, location["pins"]!);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(tag, style: TextStyle(color: Colors.black)),
    );
  }

  Widget _locationCard(String image, String name, String steps) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              child: Image.asset(image, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                Text(steps, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 40, color: Colors.grey),
            Text("Add more pins\nin another city\nto create a new guide!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Logout"),
          content: const Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                // Log out the user
                FirebaseService().signOut();
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }