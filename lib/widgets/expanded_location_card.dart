import 'package:flutter/material.dart';
import 'package:login/models/location_model.dart';

class ExpandedLocationCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onClose;

  const ExpandedLocationCard({
    Key? key,
    required this.location,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return GestureDetector(
      onTap: onClose, // Close when tapping outside
      child: Container(
        width: size.width,
        height: size.height * 0.8,
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on the card
            child: Container(
              width: size.width * 0.9,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Expanded view for ${location.name}',
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}