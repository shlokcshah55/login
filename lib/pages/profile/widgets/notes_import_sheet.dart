import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/services/notes_import_submitted_service.dart';
import 'package:login/supabase/helpers/notes_import.dart';
import 'package:login/widgets/feedback/app_feedback.dart';

import 'pinit_colors.dart';

class NotesImportSheet extends StatefulWidget {
  final Future<NotesImportResult> Function(
      PlatformFile file, String? sourceName) onImportFile;

  const NotesImportSheet({
    super.key,
    required this.onImportFile,
  });

  @override
  State<NotesImportSheet> createState() => _NotesImportSheetState();
}

class _NotesImportSheetState extends State<NotesImportSheet> {
  final _sourceNameController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  NotesImportResult? _result;

  @override
  void dispose() {
    _sourceNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    HapticFeedback.selectionClick();
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      allowedExtensions: const [
        'txt',
        'md',
        'markdown',
        'html',
        'htm',
        'json',
        'rtf'
      ],
      type: FileType.custom,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _selectedFile = result.files.single;
      _result = null;
      if (_sourceNameController.text.trim().isEmpty) {
        _sourceNameController.text = _selectedFile!.name;
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      await AppFeedback.showError(
        context,
        title: 'No file selected',
        message: 'Choose a file to import first.',
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _result = null;
    });

    try {
      final sourceName = _sourceNameController.text.trim().isEmpty
          ? null
          : _sourceNameController.text.trim();

      final response = await widget.onImportFile(_selectedFile!, sourceName);
      unawaited(NotesImportSubmittedService().markSubmitted());

      if (!mounted) return;

      if (response.queued) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _result = response;
      });
    } on NotesImportException catch (error) {
      if (!mounted) return;
      await AppFeedback.showError(
        context,
        title: 'Couldn’t import',
        message: error.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        bottomPadding > 0 ? bottomPadding : 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
            boxShadow: PinitColors.elevatedShadow,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PinitColors.creamDeep,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildIntro(),
                  const SizedBox(height: 16),
                  _buildSourceNameField(),
                  const SizedBox(height: 14),
                  _buildUploadPanel(),
                  const SizedBox(height: 16),
                  _buildSubmitButton(),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _buildResultSummary(_result!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bring in a saved list',
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 26,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Import an Apple Notes or Notion export and Pinit will queue it in the background. We will send you a notification when your saves are ready.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.aubergineSoft,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceNameField() {
    return TextFormField(
      controller: _sourceNameController,
      textInputAction: TextInputAction.next,
      decoration: _inputDecoration(
        label: 'Label',
        hint: 'Weekend spots, NYC list, Notion export...',
      ),
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: PinitColors.aubergine,
      ),
    );
  }

  Widget _buildUploadPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _selectedFile == null
              ? PinitColors.creamDeep
              : PinitColors.aubergine,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload an export',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Supported: .txt, .md, .html, .json, .rtf',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _pickFile,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: PinitColors.creamDeep, width: 1.2),
              backgroundColor: PinitColors.cream,
              foregroundColor: PinitColors.aubergine,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              _selectedFile == null ? 'Choose file' : 'Replace file',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
          if (_selectedFile != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PinitColors.creamDeep, width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: PinitColors.creamDeep,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatSize(_selectedFile!.size),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: PinitColors.aubergineSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Pick a note export and Pinit will read the text inside it.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: PinitColors.aubergineSoft,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isDisabled = _isSubmitting || _selectedFile == null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isDisabled ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: PinitColors.aubergine,
          foregroundColor: PinitColors.cream,
          disabledBackgroundColor: PinitColors.creamDeep,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(PinitColors.cream),
                ),
              )
            : Text(
                'Import from file',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildResultSummary(NotesImportResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F4EA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PinitColors.creamDeep, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.queued ? 'Import queued' : 'Import summary',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.message.isNotEmpty
                ? result.message
                : 'We will let you know once we have finished importing your places.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: PinitColors.aubergineSoft,
              height: 1.4,
            ),
          ),
          if (!result.queued) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(label: '${result.extractedCount} found'),
                _SummaryChip(label: '${result.matchedCount} matched'),
                _SummaryChip(label: '${result.savedCount} saved'),
                if (result.alreadySavedCount > 0)
                  _SummaryChip(
                      label: '${result.alreadySavedCount} already saved'),
                if (result.unmatchedLocations.isNotEmpty)
                  _SummaryChip(
                      label: '${result.unmatchedLocations.length} unmatched'),
              ],
            ),
          ],
          if (result.truncatedInput) ...[
            const SizedBox(height: 12),
            Text(
              'Large note detected. Only the first section was imported this time.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: PinitColors.aubergineSoft,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(
        color: PinitColors.aubergineSoft.withValues(alpha: 0.75),
      ),
      labelStyle: GoogleFonts.dmSans(
        color: PinitColors.aubergineSoft,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: PinitColors.cream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PinitColors.creamDeep, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PinitColors.aubergine, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PinitColors.accent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PinitColors.accent, width: 1.4),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;

  const _SummaryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}
