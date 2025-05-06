import 'package:flutter/material.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase_flutter/supabase_provider.dart';
import 'package:provider/provider.dart';
import 'package:login/assets/constants.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatelessWidget {
  late final UserDataProvider userDataProvider;
  late final LocationListManager locationListManager;
  late final SupabaseProvider supabaseProvider;
  @override
  Widget build(BuildContext context) {
    userDataProvider = Provider.of<UserDataProvider>(context);
    locationListManager = Provider.of<LocationListManager>(context);
    supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

    // Try to get user data from Supabase first
    String username, fullName, bio;

    if (userDataProvider.supabaseUserData != null) {
      // Use Supabase data
      username = userDataProvider.supabaseUserData!.name ?? "Pinit User";
      fullName = userDataProvider.supabaseUserData!.name ?? "No Name";
      bio = "Pinit User"; // Not directly available in Supabase model
    } else if (userDataProvider.userData != null) {
      // Fall back to Firebase data
      username = userDataProvider.userData!['username'] ?? "Trollmaster";
      bio = userDataProvider.userData!['bio'] ??
          "Tell us more about you! Tap the dot menu to edit your profile 😊";
      fullName = userDataProvider.userData!['fullname'] ?? "No Name";
    } else {
      // Default values if no data is available
      username = "Pinit User";
      bio = "Tell us more about you! Tap the dot menu to edit your profile 😊";
      fullName = "No Name";
    }

    // These could be fetched from Supabase in the future
    final tags = userDataProvider.userData?['tags'] ??
        ["Restaurant", "Sightseeing", "Café"];
    final locations = userDataProvider.userData?['locations'] ??
        [
          {"name": "London", "pins": 2, "image": "lib/assets/pinitLogo.png"},
          {"name": "Brighton", "pins": 1, "image": "lib/assets/pinitLogo.png"},
        ];

    // Get a recommended place for Pinit's Choice
    final recommendedPlace = userDataProvider.userData!['recommended'] ??
        {
          "name": "The Grove Restaurant",
          "address": "123 Main Street, London",
          "rating": 4.8,
          "image": "lib/assets/pinitLogo.png"
        };

    return Scaffold(
      backgroundColor: backgroundLinen,
      body: CustomScrollView(
        slivers: [
          // App Bar with Profile Pic and Username
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: primaryTeal,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return FlexibleSpaceBar(
                  title: Text(
                    username,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: constraints.maxHeight < 120 ? 16 : 20,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: primaryTeal,
                      ),
                      Positioned(
                        right: 20,
                        top: 80,
                        child: Hero(
                          tag: 'profilePic',
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.grey[300],
                              child: const Icon(Icons.person,
                                  size: 48, color: primaryTeal),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _showProfileOptionsMenu(context);
                },
              ),
            ],
          ),

          // Profile Info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDarkGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bio,
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statColumn(
                        locationListManager.savedLocations.length.toString(),
                        "Pins",
                        Icons.place,
                      ),
                      _verticalDivider(),
                      _statColumn(
                        userDataProvider.userData!["followers"].length
                            .toString(),
                        "Followers",
                        Icons.people,
                      ),
                      _verticalDivider(),
                      _statColumn(
                        userDataProvider.userData!["following"].length
                            .toString(),
                        "Following",
                        Icons.person_add,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Action Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton("Edit Profile", Icons.edit, primaryTeal),
                  _actionButton("Share Profile", Icons.share, accentCoral),
                ],
              ),
            ),
          ),

          // Pinit's Choice Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: accentCoral),
                      const SizedBox(width: 8),
                      Text(
                        "Pinit's Choice",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _pinitChoiceCard(recommendedPlace),
                ],
              ),
            ),
          ),

          // Shortlisted Places
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bookmark, color: primaryTeal),
                          const SizedBox(width: 8),
                          Text(
                            "Shortlisted Places",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textDarkGrey,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to full shortlist page
                        },
                        child: Text(
                          "See All",
                          style: GoogleFonts.poppins(color: accentCoral),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tags Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: tags.map<Widget>((tag) => _tagChip(tag)).toList(),
                ),
              ),
            ),
          ),

          // Location Grid
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index == locations.length) {
                    return _addCard();
                  }
                  final location = locations[index];
                  return _locationCard(
                      location["image"]!, location["name"]!, location["pins"]!);
                },
                childCount: locations.length + 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String count, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: primaryTeal),
        const SizedBox(height: 4),
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textDarkGrey,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return ElevatedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: primaryTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryTeal.withOpacity(0.3)),
      ),
      child: Text(
        tag,
        style: GoogleFonts.poppins(
          color: primaryTeal,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _pinitChoiceCard(Map<String, dynamic> place) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section with image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Stack(
              children: [
                Image.asset(
                  place["image"],
                  fit: BoxFit.cover,
                  height: 150,
                  width: double.infinity,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          place["rating"].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place["name"],
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDarkGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place["address"],
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.directions, size: 16),
                      label: const Text("Directions"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryTeal,
                        side: BorderSide(color: primaryTeal),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_location, size: 16),
                      label: const Text("Add to Pins"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentCoral,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(String image, String name, dynamic pins) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay for better text visibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.place, size: 16, color: accentCoral),
                    const SizedBox(width: 4),
                    Text(
                      "$pins pins",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 30, color: primaryTeal),
            ),
            const SizedBox(height: 10),
            Text(
              "Add New Location",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: primaryTeal,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              "Create a new collection",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: primaryTeal),
                title: Text(
                  'Edit Profile',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to edit profile page
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: primaryTeal),
                title: Text(
                  'Settings',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to settings
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  'Logout',
                  style: GoogleFonts.poppins(),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Logout",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to log out?",
            style: GoogleFonts.poppins(),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Log out the user
                supabaseProvider.signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text(
                "Logout",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
