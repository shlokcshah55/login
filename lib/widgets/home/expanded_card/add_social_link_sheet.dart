import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/utils/social_video_link.dart';

class AddSocialLinkSheet extends StatefulWidget {
  const AddSocialLinkSheet({
    super.key,
    required this.locationName,
    required this.onSave,
  });

  final String locationName;
  final Future<bool> Function(String normalizedUrl) onSave;

  @override
  State<AddSocialLinkSheet> createState() => _AddSocialLinkSheetState();
}

class _AddSocialLinkSheetState extends State<AddSocialLinkSheet> {
  final TextEditingController _controller = TextEditingController();
  SocialVideoLink? _link;
  bool _hasTyped = false;
  bool _isSaving = false;
  String? _saveError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    setState(() {
      _hasTyped = value.trim().isNotEmpty;
      _link = SocialVideoLink.parse(value);
      _saveError = null;
    });
  }

  Future<void> _save() async {
    final link = _link;
    if (link == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final ok = await widget.onSave(link.normalizedUrl);
    if (!mounted) return;

    if (ok) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(link);
        return;
      }
      setState(() => _isSaving = false);
      return;
    }

    setState(() {
      _isSaving = false;
      _saveError = "Couldn't save this link. Please try again.";
    });
  }

  String? get _validationText {
    if (!_hasTyped) return null;
    if (_link == null) return 'Paste a TikTok or Instagram Reel link.';
    return null;
  }

  String? get _platformLabel {
    switch (_link?.platform) {
      case SocialVideoPlatform.tiktok:
        return 'TikTok';
      case SocialVideoPlatform.instagram:
        return 'Instagram Reel';
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final platformLabel = _platformLabel;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: PinitColors.cream,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add social link',
                        style: GoogleFonts.dmSans(
                          color: PinitColors.aubergine,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.locationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: PinitColors.aubergineSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('social_link_input'),
              controller: _controller,
              onChanged: _handleChanged,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: 'Paste TikTok or Reel link',
                errorText: _validationText,
                prefixIcon: const Icon(Icons.ios_share_rounded),
                filled: true,
                fillColor: PinitColors.creamSunk,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: PinitColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            if (platformLabel != null) ...[
              const SizedBox(height: 10),
              _PlatformPreview(label: platformLabel),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Text(
                _saveError!,
                style: GoogleFonts.dmSans(
                  color: const Color(0xFFB4493E),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                key: const Key('social_link_save'),
                onPressed: _link == null || _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving' : 'Save link'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PinitColors.aubergine,
                  foregroundColor: PinitColors.cream,
                  disabledBackgroundColor: PinitColors.creamDeep,
                  disabledForegroundColor: PinitColors.aubergineSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _PlatformPreview extends StatelessWidget {
  const _PlatformPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PinitColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.play_circle_outline_rounded,
            size: 16,
            color: PinitColors.accent,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: PinitColors.aubergine,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
