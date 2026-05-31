import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/collections_library_events.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/feedback/app_feedback.dart';

class CreateCollectionSheet extends StatefulWidget {
  final Future<void> Function(String collectionId, String name) onCreated;

  const CreateCollectionSheet({
    super.key,
    required this.onCreated,
  });

  @override
  State<CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<CreateCollectionSheet> {
  final TextEditingController _nameController = TextEditingController();
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isSaving = false;

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSaving;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final response = await SupabaseClientManager().client.rpc(
        'create_collection',
        params: {
          'p_name': name,
          'p_is_public': true,
        },
      );

      final collectionId = response is String ? response : response.toString();
      if (collectionId.trim().isEmpty) {
        throw Exception('Invalid create_collection response');
      }
      _analyticsService.trackFeature(
        'collection_created',
        featureName: 'collection',
        screenName: 'profile',
        properties: <String, dynamic>{
          'collection_id': collectionId,
          'name_length': name.length,
        },
        registerTap: true,
        interactionKey: 'collection_created',
      );
      CollectionsLibraryEvents.instance.notifyChanged();

      if (mounted) {
        Navigator.pop(context);
        await widget.onCreated(collectionId, name);
      }
    } catch (e) {
      debugPrint('[CreateCollectionSheet] error: $e');
      _analyticsService.recordError(
        key: 'collection_create_error',
        properties: <String, dynamic>{'name_length': name.length},
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      await AppFeedback.showError(
        context,
        title: 'Couldn’t create',
        message: 'Failed to create eat-list.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'New Eat-List',
              style: TextStyle(
                fontFamily: 'Rova',
                fontFamilyFallback: ['Naria'],
                fontSize: 28,
                fontWeight: FontWeight.w200,
                color: PinitColors.aubergine,
                letterSpacing: 1.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 16,
                color: PinitColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. First date spots',
                hintStyle: TextStyle(
                  color: PinitColors.textMuted.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: PinitColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: PinitColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _canCreate ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _canCreate
                        ? PinitColors.aubergine
                        : PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PinitColors.cream,
                            ),
                          )
                        : Text(
                            'Create Eat-List',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _canCreate
                                  ? PinitColors.cream
                                  : PinitColors.mute,
                            ),
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
