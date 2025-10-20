import 'package:flutter/material.dart';
import 'package:login/models/users.dart';

class ProfileStatsCard extends StatelessWidget {
  final UserModel user;
  final int savedPinsCount;
  final ThemeData theme;

  const ProfileStatsCard({
    Key? key,
    required this.user,
    required this.savedPinsCount,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 20),
          ],
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatCard(
                user.followersCount.toString(),
                'Followers',
                Icons.people_outline,
                theme.primaryColor,
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildStatCard(
                user.followingCount.toString(),
                'Following',
                Icons.person_add_outlined,
                Colors.blue,
              ),
              Container(
                height: 50,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildStatCard(
                savedPinsCount.toString(),
                'Saved',
                Icons.bookmark_outline,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
