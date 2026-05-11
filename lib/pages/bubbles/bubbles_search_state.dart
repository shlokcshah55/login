import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';

enum BubblesSearchSectionType {
  bubbles,
  people,
}

class BubblesSearchItem {
  const BubblesSearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.bubble,
    this.user,
    this.badgeText,
    this.trailingText,
  });

  final String id;
  final String title;
  final String subtitle;
  final BubblesSearchSectionType type;
  final Bubble? bubble;
  final UserModel? user;
  final String? badgeText;
  final String? trailingText;
}

class BubblesSearchSection {
  const BubblesSearchSection({
    required this.type,
    required this.title,
    required this.items,
    this.isLoading = false,
    this.errorText,
  });

  final BubblesSearchSectionType type;
  final String title;
  final List<BubblesSearchItem> items;
  final bool isLoading;
  final String? errorText;
}

List<BubblesSearchSection> buildBubblesSearchSections({
  required String query,
  required List<Bubble> bubbles,
  required List<UserModel> people,
  bool isPeopleLoading = false,
  String? peopleErrorText,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  final bubbleItems = bubbles
      .where((bubble) => _bubbleMatchesQuery(bubble, normalizedQuery))
      .map(
        (bubble) => BubblesSearchItem(
          id: bubble.id,
          title: bubble.name,
          subtitle: bubble.lastMessage.isEmpty
              ? '${bubble.memberCount} members'
              : bubble.lastMessage,
          type: BubblesSearchSectionType.bubbles,
          bubble: bubble,
          badgeText:
              bubble.unreadCount > 0 ? '${bubble.unreadCount} unread' : null,
          trailingText: bubble.lastMessageTime,
        ),
      )
      .toList();

  final peopleItems = people
      .map(
        (user) => BubblesSearchItem(
          id: user.supabaseId ?? user.email,
          title: user.username ?? user.name ?? user.email,
          subtitle: user.username?.trim().isNotEmpty == true
              ? '@${user.username}'
              : (user.name?.trim().isNotEmpty == true ? user.name! : ''),
          type: BubblesSearchSectionType.people,
          user: user,
        ),
      )
      .toList();

  return [
    BubblesSearchSection(
      type: BubblesSearchSectionType.bubbles,
      title: 'Bubbles',
      items: bubbleItems,
    ),
    BubblesSearchSection(
      type: BubblesSearchSectionType.people,
      title: 'People',
      items: peopleItems,
      isLoading: isPeopleLoading,
      errorText: peopleErrorText,
    ),
  ];
}

bool _bubbleMatchesQuery(Bubble bubble, String query) {
  if (query.isEmpty) {
    return true;
  }

  final haystacks = [
    bubble.name,
    bubble.description,
    bubble.lastMessage,
  ].map((value) => value.toLowerCase());

  return haystacks.any((value) => value.contains(query));
}
