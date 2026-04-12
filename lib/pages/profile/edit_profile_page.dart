import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/users.dart';
import '../../providers/user_data_provider.dart';
import '../../supabase/service.dart';
import 'user_list_page.dart';
import 'widgets/pinit_colors.dart';

/// Lets the user update their profile photo, display name, and bio.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  File? _pendingPhoto;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserDataProvider>().supabaseUserData;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked != null && mounted) {
        setState(() {
          _pendingPhoto = File(picked.path);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load image.');
    }
  }

  void _showPhotoSourceSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PhotoSourceSheet(
        onCamera: () {
          Navigator.pop(sheetContext);
          _pickFrom(ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(sheetContext);
          _pickFrom(ImageSource.gallery);
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();

    final provider = context.read<UserDataProvider>();
    final supabase = context.read<SupabaseService>();
    final user = provider.supabaseUserData;
    if (user == null || user.supabaseId == null) return;

    final newName = _nameController.text.trim();
    final newBio = _bioController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      String? uploadedUrl;
      if (_pendingPhoto != null) {
        uploadedUrl = await supabase.users.uploadImage(
          _pendingPhoto!,
          '${user.supabaseId}.jpg',
          user.supabaseId!,
        );
      }

      final ok = await provider.updateUserProfile(
        name: newName != (user.name ?? '') ? newName : null,
        bio: newBio != (user.bio ?? '') ? newBio : null,
        profileImageUrl: uploadedUrl,
      );

      if (!mounted) return;

      if (ok || (newName == (user.name ?? '') && newBio == (user.bio ?? '') && _pendingPhoto == null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Could not save changes.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save changes.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: Consumer<UserDataProvider>(
          builder: (context, provider, _) {
            final user = provider.supabaseUserData;
            if (user == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPhotoSection(user),
                          const SizedBox(height: 28),
                          _buildSectionLabel('NAME'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _nameController,
                            hint: 'Your name',
                            maxLength: 40,
                          ),
                          const SizedBox(height: 22),
                          _buildSectionLabel('BIO'),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _bioController,
                            hint: 'A line or two about your taste',
                            maxLength: 160,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 26),
                          _buildBlockedUsersTile(),
                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            _buildErrorBanner(_error!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildSaveBar(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── pieces ─────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Edit Profile',
              style: const TextStyle(
                fontFamily: 'Rova',
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

  Widget _buildPhotoSection(UserModel user) {
    final ImageProvider? preview = _pendingPhoto != null
        ? FileImage(_pendingPhoto!)
        : (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
            ? NetworkImage(user.profileImageUrl!) as ImageProvider
            : null);

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PinitColors.creamSunk,
                    border: Border.all(
                        color: PinitColors.creamDeep, width: 2),
                    boxShadow: PinitColors.subtleShadow,
                    image: preview != null
                        ? DecorationImage(image: preview, fit: BoxFit.cover)
                        : null,
                  ),
                  child: preview == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 56,
                          color: PinitColors.mute,
                        )
                      : null,
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: PinitColors.cream, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 18,
                    color: PinitColors.cream,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _showPhotoSourceSheet,
            child: Text(
              _pendingPhoto != null ? 'Photo ready to save' : 'Tap to change photo',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: PinitColors.aubergineSoft,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLength = 80,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        cursorColor: PinitColors.aubergine,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          color: PinitColors.aubergine,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          counterStyle: GoogleFonts.dmSans(
            fontSize: 11,
            color: PinitColors.mute,
          ),
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(
            fontSize: 15,
            color: PinitColors.mute,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedUsersTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserListPage(
                title: 'Blocked Users',
                loader: (s) => s.users.getBlockedUsers(),
                emptyMessage: "You haven't blocked anyone",
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.block_rounded,
                  size: 20,
                  color: PinitColors.aubergine,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blocked Users',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergine,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage who you have blocked',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: PinitColors.aubergineSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: PinitColors.aubergineSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: PinitColors.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: PinitColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: PinitColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        12 + MediaQuery.of(context).padding.bottom * 0.2,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _saving ? null : _save,
            child: Ink(
              decoration: BoxDecoration(
                color: PinitColors.aubergine,
                borderRadius: BorderRadius.circular(999),
                boxShadow: PinitColors.cardShadow,
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(PinitColors.cream),
                        ),
                      )
                    : Text(
                        'Save changes',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.cream,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable bits
// ─────────────────────────────────────────────────────────────────────────────

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            shape: BoxShape.circle,
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Icon(icon, size: 20, color: PinitColors.aubergine),
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoSourceSheet({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad > 0 ? bottomPad : 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
            boxShadow: PinitColors.elevatedShadow,
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: onCamera,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: onGallery,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          height: 110,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: PinitColors.aubergine),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
