import 'package:flutter/material.dart';
import 'package:login/assets/constants.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _PinitProfileScreenState createState() => _PinitProfileScreenState();
}

class _PinitProfileScreenState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sample data - replace with your actual data models and sources
  final String userName = "Jamie Rivers";
  final String userHandle = "@jamierivers";
  final String profileImageUrl = "https://via.placeholder.com/150/A9A9A9/FFFFFF?Text=JR"; // Placeholder
  final int pinCount = 128;
  final int collectionCount = 12;
  final int guideCount = 5;

  final List<Map<String, String>> pins = List.generate(
    15,
    (index) => {
      "title": "Location ${index + 1}",
      "category": index % 3 == 0
          ? "Cafe"
          : index % 3 == 1
              ? "Park"
              : "Viewpoint",
      "imageUrl": "https://via.placeholder.com/300/C0C0C0/FFFFFF?Text=Pin${index + 1}", // Placeholder
    },
  );

  // For filter tabs
  final List<Map<String, dynamic>> _filterCategories = [
    {"icon": Icons.push_pin_outlined, "text": "All Pins"},
    {"icon": Icons.collections_bookmark_outlined, "text": "Collections"},
    {"icon": Icons.map_outlined, "text": "Guides"},
    {"icon": Icons.favorite_border, "text": "Favorites"},
  ];

  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // For Pins, Collections, Guides stats
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar (optional, can be customized or removed if top elements are part of body)
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFFF2EBF9), // Match scaffold background
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.grey[700]),
            onPressed: () {
              // Handle more options
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero, // Remove top padding from ListView
        children: <Widget>[
          _buildProfileHeader(context),
          _buildStatsSection(context),
          _buildFilterTabs(context),
          _buildPinsGrid(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Action to add a new Pin
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Color(0xFF008080), // Teal accent
        tooltip: 'Add Pin',
      ),
      // Placeholder for BottomNavigationBar if this screen is part of a larger app structure
      // bottomNavigationBar: BottomNavigationBar( ... ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              Container(
                margin: EdgeInsets.only(top: 50), // Space for profile picture to overlap
                padding: EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16), // Increased top padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: 10), // Adjust spacing if CircleAvatar size changes
                    Text(
                      userName,
                      style: GoogleFonts.montserrat(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      userHandle,
                      style: GoogleFonts.lato(
                        fontSize: 16.0,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(Icons.bookmark_border, color: Colors.grey[700], size: 28),
                          onPressed: () { /* Saved items */ },
                        ),
                        IconButton(
                          icon: Icon(Icons.grid_on_outlined, color: Colors.grey[700], size: 28),
                          onPressed: () { /* View toggle */ },
                        ),
                        IconButton(
                          icon: Icon(Icons.insights_outlined, color: Colors.grey[700], size: 28),
                          onPressed: () { /* User activity/stats */ },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Profile Picture
              Positioned(
                top: 0, // Position it at the very top of the Stack
                child: CircleAvatar(
                  radius: 55.0,
                  backgroundColor: Colors.white, // Border for the avatar
                  child: CircleAvatar(
                    radius: 50.0,
                    backgroundImage: NetworkImage(profileImageUrl),
                    backgroundColor: Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    // This section replaces the original TabBar for "Items", "Outfits", "Lookbooks"
    // with direct stat displays relevant to Pinit.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildStatItem("Pins", pinCount),
          _buildStatItem("Collections", collectionCount),
          _buildStatItem("Guides", guideCount),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          count.toString(),
          style: GoogleFonts.montserrat(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4.0),
        Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 14.0,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      height: 100, // Increased height for better touch targets and visual separation
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterCategories.length,
        itemBuilder: (context, index) {
          final category = _filterCategories[index];
          bool isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilterIndex = index;
                // Add logic to filter content based on selected tab
              });
            },
            child: Container(
              width: 90, // Fixed width for each tab item
              margin: EdgeInsets.only(left: index == 0 ? 16 : 8, right: index == _filterCategories.length -1 ? 16 : 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF008080).withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected ? Color(0xFF008080) : Colors.grey[300]!,
                  width: 1.5
                )
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    category['icon'],
                    color: isSelected ? Color(0xFF008080) : Colors.grey[600],
                    size: 28,
                  ),
                  SizedBox(height: 6),
                  Text(
                    category['text'],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Color(0xFF008080) : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  Widget _buildPinsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search your pins...',
                    hintStyle: GoogleFonts.lato(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: Colors.grey[300]!, width: 1.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: Color(0xFF008080), width: 1.5),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.favorite_border, color: Colors.grey[700]),
                onPressed: () { /* Filter by favorites */ },
                tooltip: "Favorites",
              ),
              IconButton(
                icon: Icon(Icons.filter_list, color: Colors.grey[700]),
                onPressed: () { /* Open sort/filter options */ },
                tooltip: "Filter",
              ),
            ],
          ),
          SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(), // To be used within ListView
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.0,
              mainAxisSpacing: 12.0,
              childAspectRatio: 0.8, // Adjust for desired item aspect ratio
            ),
            itemCount: pins.length,
            itemBuilder: (context, index) {
              final pin = pins[index];
              return Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                clipBehavior: Clip.antiAlias, // Important for rounded corners on Image
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Colors.grey[200], // Placeholder background for image
                        child: Image.network(
                          pin['imageUrl']!,
                          fit: BoxFit.cover,
                           errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.location_pin, color: Colors.grey, size: 40)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pin['title']!,
                            style: GoogleFonts.montserrat(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.0),
                          Text(
                            pin['category']!,
                            style: GoogleFonts.lato(
                              fontSize: 12.0,
                              color: Color(0xFF008080), // Accent color for category
                            ),
                             maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Example of "NEW" tag from reference image (conditional)
                    // if (index < 2) // Just for demo
                    //   Positioned(
                    //     top: 8,
                    //     left: 8,
                    //     child: Chip(
                    //       label: Text("NEW", style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    //       backgroundColor: Colors.greenAccent[700],
                    //       padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    //       labelPadding: EdgeInsets.symmetric(horizontal: 2.0),
                    //       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    //     ),
                    //   )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}