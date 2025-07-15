import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

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
          child: Icon(FeatherIcons.search, color: Colors.black),
        ),
      ],
    );
  }
}
