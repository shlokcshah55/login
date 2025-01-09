import 'package:flutter/material.dart';

class CarouselTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const CarouselTile({
    Key? key,
    required this.item,
    required this.onRemove,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item['title']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        onRemove();
      },
      background: Container(
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
