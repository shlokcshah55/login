import 'package:flutter/material.dart';

class CarouselTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final VoidCallback onSecondaryAction; // Action for swiping start-to-end
  final VoidCallback onTap;

  const CarouselTile({
    Key? key,
    required this.item,
    required this.onRemove,
    required this.onSecondaryAction,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item['title']),
      direction: DismissDirection.horizontal, // Allow both directions
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onRemove();
        } else if (direction == DismissDirection.startToEnd) {
          onSecondaryAction();
        }
      },
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(item['title'][0]),
        ),
        title: Text(item['title']),
        subtitle: Text(item['subtitle']),
        onTap: onTap,
      ),
    );
  }
}
