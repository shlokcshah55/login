import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/route_open_guard.dart';
import 'package:login/widgets/profile/user_card.dart';
import 'package:provider/provider.dart';

typedef UserListLoader = Future<List<UserModel>> Function(
    SupabaseService service);

class UserListPage extends StatefulWidget {
  final String title;
  final UserListLoader loader;
  final String emptyMessage;

  const UserListPage({
    super.key,
    required this.title,
    required this.loader,
    this.emptyMessage = 'Nothing to show yet',
  });

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late Future<List<UserModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<UserModel>> _load() {
    final service = Provider.of<SupabaseService>(context, listen: false);
    return widget.loader(service);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FutureBuilder<List<UserModel>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: PinitColors.aubergine,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }
                    final users = snapshot.data ?? const <UserModel>[];
                    if (users.isEmpty) {
                      return _buildEmptyState();
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      color: PinitColors.aubergine,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return UserCard(
                            user: user,
                            onTap: (u) {
                              final userKey = u.supabaseId ?? u.email;
                              unawaited(
                                RouteOpenGuard.run<void>(
                                  'other-user-profile:$userKey',
                                  () => Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OtherUserProfilePage(user: u),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  shape: BoxShape.circle,
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'Rova',
                fontFamilyFallback: ['Naria'],
                fontSize: 22,
                fontWeight: FontWeight.w100,
                color: PinitColors.aubergine,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 30,
                color: PinitColors.aubergineSoft,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.aubergineSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: PinitColors.aubergineSoft,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn’t refresh this list',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: PinitColors.aubergine,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please try again in a moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.aubergineSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _future = _load();
                  });
                },
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.dmSans(
                      color: PinitColors.cream,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
