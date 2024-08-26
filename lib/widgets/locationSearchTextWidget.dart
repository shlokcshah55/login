// import 'package:flutter/material.dart';

// class SearchWidget extends StatefulWidget {
//   @override
//   _SearchWidgetState createState() => _SearchWidgetState();
// }

// class _SearchWidgetState extends State<SearchWidget> {
//   final TextEditingController _searchController = TextEditingController();


//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   void _getSearchInput() {
//     String searchInput = _searchController.text;
//     print("User input: $searchInput");
//     // Now you can use `searchInput` in your code
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Other widgets...
//         Positioned(
//           top: MediaQuery.of(context).padding.top + 50,
//           left: 16.0,
//           right: 16.0,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(8.0),
//               boxShadow: const [
//                 BoxShadow(
//                   color: Colors.black26,
//                   blurRadius: 4.0,
//                 ),
//               ],
//             ),
//             child: TextField(
//               controller: _searchController, // Attach the controller
//               decoration: const InputDecoration(
//                 hintText: 'Your next adventure...',
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
//               ),
//             ),
//           ),
//         ),
//         ElevatedButton(
//           onPressed: _getSearchInput, // Retrieve input when button is pressed
//           child: Icon(Icons.search, color: Colors.black),
//         ),
//         // Other widgets...
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {
  final Function(String) onSearch; // Callback to pass the search input

  const SearchWidget({required this.onSearch, Key? key}) : super(key: key);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    String searchInput = _searchController.text;
    widget.onSearch(searchInput); // Pass the search input to the parent widget
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4.0,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Your next adventure...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.0), // Space between TextField and Button
        ElevatedButton(
          onPressed: _handleSearch,
          child: Icon(Icons.search, color: Colors.black),
        ),
      ],
    );
  }
}
