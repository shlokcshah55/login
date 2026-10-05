import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/signup_wizard_state.dart';
import '../../supabase/service.dart';
import '../../widgets/auth/legal_consent_section.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/onboarding/onboarding_headline.dart';
import '../profile/widgets/pinit_colors.dart';

/// Account creation as a single form: name, username, email, password and the
/// legal consent, with an optional photo. Everything is validated inline (the
/// username live), then one tap creates the account.
class AccountStep extends StatefulWidget {
  final VoidCallback onNext;

  const AccountStep({super.key, required this.onNext});

  @override
  State<AccountStep> createState() => _AccountStepState();
}

enum _Field { name, username, email, password, consent, form }

enum _UsernameStatus { idle, checking, available, taken }

class _AccountStepState extends State<AccountStep>
    with SingleTickerProviderStateMixin {
  static final RegExp _emailPattern =
      RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
  static const Duration _usernameDebounce = Duration(milliseconds: 450);

  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late final AnimationController _entrance;
  Timer? _usernameTimer;

  final Map<_Field, String?> _errors = {};
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  // The suggestion follows the name until the user edits the username.
  bool _usernameEdited = false;
  bool _passwordVisible = false;
  bool _consent = false;
  bool _submitting = false;
  File? _photo;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _name.addListener(_suggestUsername);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _entrance.dispose();
    for (final c in [_name, _username, _email, _password]) {
      c.dispose();
    }
    for (final f in [_nameFocus, _usernameFocus, _emailFocus, _passwordFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── Validation ─────────────────────────

  void _setError(_Field field, String? message) {
    if (_errors[field] == message) return;
    setState(() => _errors[field] = message);
  }

  void _suggestUsername() {
    if (_usernameEdited) return;
    final slug = _name.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final suggestion = slug.length > 18 ? slug.substring(0, 18) : slug;
    if (_username.text != suggestion) {
      _username.text = suggestion;
      _queueUsernameCheck();
    }
  }

  void _queueUsernameCheck() {
    _usernameTimer?.cancel();
    final value = _username.text.trim();
    if (value.length < 3) {
      setState(() {
        _usernameStatus = _UsernameStatus.idle;
        _errors[_Field.username] = null;
      });
      return;
    }
    setState(() {
      _usernameStatus = _UsernameStatus.checking;
      _errors[_Field.username] = null;
    });
    _usernameTimer = Timer(_usernameDebounce, () async {
      final taken = await _usernameTaken(value);
      if (!mounted || _username.text.trim() != value) return;
      setState(() {
        _usernameStatus =
            taken ? _UsernameStatus.taken : _UsernameStatus.available;
        _errors[_Field.username] =
            taken ? 'That username is taken, try another' : null;
      });
    });
  }

  Future<bool> _usernameTaken(String value) async {
    try {
      final supabase = context.read<SupabaseService>();
      return await supabase.users.usernameExists(value) == true;
    } catch (_) {
      // A failed lookup must not block sign-up; the server enforces it.
      return false;
    }
  }

  Future<bool> _emailTaken(String value) async {
    try {
      final supabase = context.read<SupabaseService>();
      return await supabase.users.emailExists(value) == true;
    } catch (_) {
      return false;
    }
  }

  String? _nameError() {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Tell us what to call you';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _usernameFormatError() {
    final value = _username.text.trim();
    if (value.isEmpty) return 'Pick a username';
    if (value.length < 3) return 'At least 3 characters';
    return null;
  }

  String? _emailFormatError() {
    final value = _email.text.trim();
    if (value.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(value)) return 'That email doesn’t look right';
    return null;
  }

  String? _passwordError() {
    if (_password.text.isEmpty) return 'Choose a password';
    if (_password.text.length < 6) return 'At least 6 characters';
    return null;
  }

  Future<void> _checkEmailOnBlur() async {
    final formatError = _emailFormatError();
    if (_email.text.trim().isEmpty) return;
    if (formatError != null) {
      _setError(_Field.email, formatError);
      return;
    }
    final taken = await _emailTaken(_email.text.trim());
    if (!mounted) return;
    _setError(_Field.email, taken ? 'That email already has an account' : null);
  }

  /// Validates everything at once and focuses the first problem.
  Future<bool> _validateAll() async {
    final name = _nameError();
    final usernameFormat = _usernameFormatError();
    final emailFormat = _emailFormatError();
    final password = _passwordError();

    final results = await Future.wait<bool>([
      if (usernameFormat == null) _usernameTaken(_username.text.trim()),
      if (emailFormat == null) _emailTaken(_email.text.trim()),
    ]);
    var i = 0;
    final usernameTaken = usernameFormat == null ? results[i++] : false;
    final emailTaken = emailFormat == null ? results[i++] : false;
    if (!mounted) return false;

    final errors = <_Field, String?>{
      _Field.name: name,
      _Field.username: usernameFormat ??
          (usernameTaken ? 'That username is taken, try another' : null),
      _Field.email: emailFormat ??
          (emailTaken ? 'That email already has an account' : null),
      _Field.password: password,
      _Field.consent:
          _consent ? null : 'Please agree to the Terms and Privacy Policy',
      _Field.form: null,
    };
    setState(() {
      _errors
        ..clear()
        ..addAll(errors);
      if (usernameFormat == null) {
        _usernameStatus =
            usernameTaken ? _UsernameStatus.taken : _UsernameStatus.available;
      }
    });

    final firstBad = [
      (_Field.name, _nameFocus),
      (_Field.username, _usernameFocus),
      (_Field.email, _emailFocus),
      (_Field.password, _passwordFocus),
    ].where((e) => errors[e.$1] != null).map((e) => e.$2).firstOrNull;
    if (firstBad != null) {
      HapticFeedback.lightImpact();
      firstBad.requestFocus();
    } else if (errors[_Field.consent] != null) {
      HapticFeedback.lightImpact();
      FocusScope.of(context).unfocus();
    }
    return errors.values.every((e) => e == null);
  }

  // ───────────────────────── Submit ─────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      if (!await _validateAll()) return;

      final supabase = context.read<SupabaseService>();
      final wizardState = context.read<SignupWizardState>();
      final name = _name.text.trim();
      final email = _email.text.trim();

      final userId = await supabase.signUp(
        email,
        _password.text,
        name: name,
        username: _username.text.trim(),
      );
      if (userId.isEmpty) {
        throw Exception('Failed to create account');
      }

      wizardState.setUserId(userId);
      wizardState.setAccountInfo(name, email);

      var retries = 0;
      while (supabase.users.currentUser == null && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retries++;
      }

      // Independent writes, so run them together.
      await Future.wait([
        supabase.tags.initializeVibeTagsForUser(userId),
        supabase.users.acceptLegalConsent(userId),
      ]);

      // The photo upload is not on the critical path: continue straight into
      // onboarding and let it finish in the background.
      unawaited(_uploadProfilePhoto(supabase, wizardState, userId));

      if (mounted) widget.onNext();
    } catch (e) {
      if (mounted) {
        _setError(
          _Field.form,
          'We couldn’t create your account. ${_friendly(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendly(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('already') || text.contains('registered')) {
      return 'That email may already have an account.';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'Check your connection and try again.';
    }
    return 'Please try again.';
  }

  Future<void> _uploadProfilePhoto(
    SupabaseService supabase,
    SignupWizardState wizardState,
    String userId,
  ) async {
    try {
      final image = _photo ?? await _randomDefaultIcon();
      final ext = image.path.split('.').last;
      final url = await supabase.users
          .uploadImage(image, '$userId/$userId.$ext', userId);
      wizardState.setProfilePicture(url);
    } catch (_) {
      // Non-fatal: the avatar can be set later from the profile.
    }
  }

  Future<File> _randomDefaultIcon() async {
    const icons = [
      'burgerIcon',
      'curryIcon',
      'donutIcon',
      'phoIcon',
      'pizzaIcon',
      'steakIcon',
      'sushiIcon',
      'tacoIcon',
      'thaiIcon',
    ];
    final asset =
        'lib/assets/pin_emojis/${icons[Random().nextInt(icons.length)]}.jpg';
    final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${asset.split('/').last}');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _pickPhoto() async {
    HapticFeedback.selectionClick();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _photo = File(picked.path));
      }
    } catch (_) {
      // Permission denied or picker failed: keep the default avatar.
    }
  }

  // ───────────────────────── UI ─────────────────────────

  /// Staggered fade + slide for the n-th block of the form.
  Widget _reveal(int index, Widget child) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return child;
    final start = (index * 0.09).clamp(0.0, 0.6);
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinitColors.surfaceLight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                      _reveal(
                        0,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const OnboardingHeadline(
                                    text: 'Create your account',
                                    fontSize: 30,
                                    textAlign: TextAlign.start,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Takes about 20 seconds.',
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: PinitColors.aubergineSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _AvatarButton(photo: _photo, onTap: _pickPhoto),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _reveal(
                        1,
                        _LabeledField(
                          label: 'NAME',
                          controller: _name,
                          focusNode: _nameFocus,
                          hint: 'What should we call you?',
                          icon: Icons.person_outline_rounded,
                          error: _errors[_Field.name],
                          capitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.givenName],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _setError(_Field.name, null),
                          onSubmitted: (_) => _usernameFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _reveal(
                        2,
                        _LabeledField(
                          label: 'USERNAME',
                          controller: _username,
                          focusNode: _usernameFocus,
                          hint: 'For your mates to find you',
                          icon: Icons.alternate_email_rounded,
                          error: _errors[_Field.username],
                          helper: _usernameStatus == _UsernameStatus.available
                              ? 'Available'
                              : null,
                          autofillHints: const [AutofillHints.newUsername],
                          textInputAction: TextInputAction.next,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_.]'),
                            ),
                            LengthLimitingTextInputFormatter(24),
                          ],
                          trailing: switch (_usernameStatus) {
                            _UsernameStatus.checking => const _MiniSpinner(),
                            _UsernameStatus.available => const Icon(
                                Icons.check_circle_rounded,
                                color: PinitColors.teal,
                                size: 20,
                              ),
                            _UsernameStatus.taken => const Icon(
                                Icons.cancel_rounded,
                                color: PinitColors.accent,
                                size: 20,
                              ),
                            _ => null,
                          },
                          onChanged: (_) {
                            _usernameEdited = true;
                            _queueUsernameCheck();
                          },
                          onSubmitted: (_) => _emailFocus.requestFocus(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _reveal(
                        3,
                        Focus(
                          onFocusChange: (focused) {
                            if (!focused) _checkEmailOnBlur();
                          },
                          child: _LabeledField(
                            label: 'EMAIL',
                            controller: _email,
                            focusNode: _emailFocus,
                            hint: 'you@example.com',
                            icon: Icons.mail_outline_rounded,
                            error: _errors[_Field.email],
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => _setError(_Field.email, null),
                            onSubmitted: (_) => _passwordFocus.requestFocus(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _reveal(
                        4,
                        _LabeledField(
                          label: 'PASSWORD',
                          controller: _password,
                          focusNode: _passwordFocus,
                          hint: 'At least 6 characters',
                          icon: Icons.lock_outline_rounded,
                          error: _errors[_Field.password],
                          obscure: !_passwordVisible,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          trailing: GestureDetector(
                            onTap: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                            child: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: PinitColors.aubergineSoft,
                            ),
                          ),
                          onChanged: (_) => _setError(_Field.password, null),
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _reveal(
                        5,
                        LegalConsentSection(
                          value: _consent,
                          errorText: _errors[_Field.consent],
                          onChanged: (value) => setState(() {
                            _consent = value;
                            if (value) _errors[_Field.consent] = null;
                          }),
                          textColor: PinitColors.aubergine,
                          linkColor: PinitColors.aubergine,
                          checkboxActiveColor: PinitColors.aubergine,
                          checkboxCheckColor: PinitColors.cream,
                          checkboxSideColor: PinitColors.aubergineSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _reveal(
              6,
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                decoration: BoxDecoration(
                  color: PinitColors.surfaceLight,
                  boxShadow: [
                    BoxShadow(
                      color: PinitColors.aubergine.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _errors[_Field.form] == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                _errors[_Field.form]!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.accent,
                                ),
                              ),
                            ),
                    ),
                    _CreateButton(loading: _submitting, onTap: _submit),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    required this.onChanged,
    required this.onSubmitted,
    this.error,
    this.helper,
    this.trailing,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.formatters,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final String? error;
  final String? helper;
  final Widget? trailing;
  final bool obscure;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: PinitColors.aubergineSoft,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: focusNode,
          builder: (context, child) {
            final focused = focusNode.hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasError
                      ? PinitColors.accent
                      : focused
                          ? PinitColors.aubergine
                          : PinitColors.aubergine.withValues(alpha: 0.18),
                  width: focused || hasError ? 1.8 : 1.2,
                ),
                boxShadow: focused
                    ? const [
                        BoxShadow(
                          color: PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ]
                    : const [],
              ),
              child: child,
            );
          },
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            inputFormatters: formatters,
            autocorrect: false,
            enableSuggestions: !obscure,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: PinitColors.aubergine,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergine,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PinitColors.mute,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              prefixIcon:
                  Icon(icon, size: 20, color: PinitColors.aubergineSoft),
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: 1,
                        child: trailing,
                      ),
                    ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: (error ?? helper) == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    error ?? helper!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: hasError ? PinitColors.accent : PinitColors.teal,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.photo, required this.onTap});

  final File? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a profile photo (optional)',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PinitColors.creamSunk,
                  border: Border.all(color: PinitColors.aubergine, width: 1.5),
                  image: photo == null
                      ? null
                      : DecorationImage(
                          image: FileImage(photo!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: photo == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: PinitColors.aubergineSoft,
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: PinitColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    photo == null ? Icons.add_rounded : Icons.edit_rounded,
                    size: 14,
                    color: PinitColors.cream,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: PinitColors.aubergineSoft,
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: PinitColors.aubergine,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: PinitColors.accent,
            blurRadius: 0,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: loading ? null : onTap,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: loading
                  ? const LoadingWidget(
                      key: ValueKey('loading'),
                      width: 24,
                      height: 24,
                    )
                  : Text(
                      'CREATE ACCOUNT',
                      key: const ValueKey('label'),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: PinitColors.cream,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
