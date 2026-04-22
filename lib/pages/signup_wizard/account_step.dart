import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../animations/animation_builders.dart';
import '../../animations/common_animations.dart';
import '../../animations/animation_constants.dart';
import '../../models/signup_wizard_state.dart';
import '../../supabase/service.dart';
import '../../widgets/auth/legal_consent_section.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/profile/profile_photo_selector.dart';
import '../auth_handler.dart';
import '../profile/widgets/pinit_colors.dart';

class AccountStep extends StatefulWidget {
  final VoidCallback onNext;
  final Function(int)? onSubStepChanged;

  const AccountStep({
    super.key,
    required this.onNext,
    this.onSubStepChanged,
  });

  @override
  State<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<AccountStep>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentSubStep = 0;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  // Focus nodes for fields (keep keyboard open and control focus)
  late FocusNode nameFocusNode;
  late FocusNode emailFocusNode;
  late FocusNode passwordFocusNode;
  late FocusNode usernameFocusNode;

  // Profile picture state
  File? _selectedProfileImage;
  late AnimationController _transitionController;

  // Error handling
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _legalConsentChecked = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    // initialize focus nodes
    nameFocusNode = FocusNode();
    emailFocusNode = FocusNode();
    passwordFocusNode = FocusNode();
    usernameFocusNode = FocusNode();

    // Notify parent of initial sub-step and focus first field after mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSubStepChanged?.call(_currentSubStep + 1);
      _focusCurrentField();
    });
  }

  Future<bool> _ensureLegalConsentAccepted() async {
    if (!_legalConsentChecked) {
      errorNotifier.value =
          'Please agree to the Terms and Conditions and Privacy Policy.';
      return false;
    }

    errorNotifier.value = null;
    return true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transitionController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    errorNotifier.dispose();
    nameFocusNode.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    usernameFocusNode.dispose();
    usernameController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _transitionController = AnimationController(
      duration: AnimationDurations.signupTransition,
      vsync: this,
    );
    _transitionController.forward();
  }

  Widget _buildAnimatedSubStep({required Widget child}) {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        return Transform.rotate(
          angle:
              AnimationBuilders.createRotationAnimation(_transitionController)
                  .value,
          child: Transform.translate(
            offset: Offset(
              0,
              AnimationBuilders.createMainSlideAnimation(_transitionController)
                      .value
                      .dy *
                  MediaQuery.of(context).size.height,
            ),
            child: Opacity(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController)
                      .value,
              child: Transform.scale(
                scale: AnimationBuilders.createScaleAnimation(
                        _transitionController)
                    .value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Future<bool> _validateUserName() async {
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      errorNotifier.value = 'Username cannot be empty';
      return false;
    }

    if (username.length < 3) {
      errorNotifier.value = 'Username must be at least 3 characters';
      return false;
    }

    final _supabaseService =
        Provider.of<SupabaseService>(context, listen: false);

    if (await _supabaseService.users.usernameExists(username) == true) {
      errorNotifier.value = 'Username is already in use, please choose another';
      return false;
    }

    // Clear any errors
    errorNotifier.value = null;
    return true;
  }

  bool _validateName() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      errorNotifier.value = 'Name cannot be empty';
      return false;
    }

    if (name.length < 2) {
      errorNotifier.value = 'Name must be at least 2 characters';
      return false;
    }

    // Clear any errors
    errorNotifier.value = null;
    return true;
  }

  Future<bool> _validateEmail() async {
    if (emailController.text.isEmpty) {
      errorNotifier.value = 'Email cannot be empty';
      return false;
    }

    final _supabaseService =
        Provider.of<SupabaseService>(context, listen: false);

    if (await _supabaseService.users.emailExists(emailController.text) ==
        true) {
      errorNotifier.value = 'Email is already in use, please sign in';
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(emailController.text)) {
      errorNotifier.value = 'Please enter a valid email';
      return false;
    }

    errorNotifier.value = null;
    return true;
  }

  bool _validatePassword() {
    if (passwordController.text.isEmpty) {
      errorNotifier.value = 'Password cannot be empty';
      return false;
    }

    if (passwordController.text.length < 6) {
      errorNotifier.value = 'Password must be at least 6 characters';
      return false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      errorNotifier.value = 'Passwords do not match';
      return false;
    }

    errorNotifier.value = null;
    return true;
  }

  Future<void> _advanceToNextSubStep() async {
    print(
        '⏭️ [ADVANCE] Moving from step $_currentSubStep to ${_currentSubStep + 1}');

    // Reverse animation
    await _transitionController.reverse();

    // Move to next sub-step
    setState(() => _currentSubStep++);
    print('⏭️ [ADVANCE] Now at step $_currentSubStep');

    await _pageController.animateToPage(
      _currentSubStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Forward animation for new step
    await _transitionController.forward();

    // Focus the appropriate field for the newly shown sub-step
    print('⏭️ [ADVANCE] Calling _focusCurrentField for step $_currentSubStep');
    _focusCurrentField();

    // Notify parent of progress
    widget.onSubStepChanged?.call(_currentSubStep + 1);
  }

  Future<void> _createAccountAndAdvance() async {
    if (!_validatePassword()) {
      print('❌ [CREATE_ACCOUNT] Password validation failed');
      return;
    }

    if (!await _ensureLegalConsentAccepted()) {
      print('❌ [CREATE_ACCOUNT] Legal consent not accepted');
      return;
    }

    setState(() => isLoading = true);
    errorNotifier.value = null;

    try {
      print('🚀 [CREATE_ACCOUNT] Starting account creation...');
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      final wizardState =
          Provider.of<SignupWizardState>(context, listen: false);

      // Create the Supabase account and continue directly into the app.
      print(
          '📝 [CREATE_ACCOUNT] Calling signUp with email: ${emailController.text}');
      String userID = await supabaseProvider.signUp(
        emailController.text,
        passwordController.text,
        name: nameController.text,
        username: usernameController.text,
      );

      print('✅ [CREATE_ACCOUNT] Account created successfully. UserID: $userID');

      if (userID.isEmpty) {
        throw Exception('Failed to create account');
      }

      wizardState.setUserId(userID);
      wizardState.setAccountInfo(nameController.text, emailController.text);

      print('🏷️ [CREATE_ACCOUNT] Initializing vibe tags for user: $userID');
      await supabaseProvider.tags.initializeVibeTagsForUser(userID);

      print('⏳ [CREATE_ACCOUNT] Waiting for authenticated session...');
      int retryCount = 0;
      while (supabaseProvider.users.currentUser == null && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      print('✅ [CREATE_ACCOUNT] Session ready (retries: $retryCount)');
      await supabaseProvider.users.acceptLegalConsent(userID);
      await _addProfilePic();
    } catch (e) {
      print('❌ [CREATE_ACCOUNT] Error: ${e.toString()}');
      errorNotifier.value = 'Sign up failed: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Helper method to get a random default icon from assets
  Future<File> _getRandomDefaultIcon() async {
    final iconFiles = [
      'lib/assets/pin_emojis/burgerIcon.jpg',
      'lib/assets/pin_emojis/curryIcon.jpg',
      'lib/assets/pin_emojis/donutIcon.jpg',
      'lib/assets/pin_emojis/phoIcon.jpg',
      'lib/assets/pin_emojis/pizzaIcon.jpg',
      'lib/assets/pin_emojis/steakIcon.jpg',
      'lib/assets/pin_emojis/sushiIcon.jpg',
      'lib/assets/pin_emojis/tacoIcon.jpg',
      'lib/assets/pin_emojis/thaiIcon.jpg',
    ];

    // Randomly select one icon
    final random = Random();
    final selectedIcon = iconFiles[random.nextInt(iconFiles.length)];

    // Load asset as bytes
    final byteData = await rootBundle.load(selectedIcon);
    final bytes = byteData.buffer.asUint8List();

    // Create temporary file
    final tempDir = await getTemporaryDirectory();
    final fileName = selectedIcon.split('/').last;
    final tempFile = File('${tempDir.path}/$fileName');

    // Write bytes to temp file
    await tempFile.writeAsBytes(bytes);

    return tempFile;
  }

  // We create have already created the account before this step, but this stores the profile pic
  Future<void> _addProfilePic() async {
    setState(() => isLoading = true);

    try {
      final supabaseService =
          Provider.of<SupabaseService>(context, listen: false);
      final wizardState =
          Provider.of<SignupWizardState>(context, listen: false);

      // Always upload a profile picture (user-selected or default)
      if (wizardState.userId != null) {
        File imageToUpload;

        if (_selectedProfileImage != null) {
          // User selected a photo - use it
          imageToUpload = _selectedProfileImage!;
        } else {
          // No photo selected - pick random default icon
          imageToUpload = await _getRandomDefaultIcon();
        }

        // Upload the image (user-selected or default)
        final fileExt = imageToUpload.path.split('.').last;
        final filePath = '${wizardState.userId}/${wizardState.userId}.$fileExt';

        String profilePictureUrl = await supabaseService.users
            .uploadImage(imageToUpload, filePath, wizardState.userId!);

        wizardState.setProfilePicture(profilePictureUrl);
      }

      // Navigate to MainScreen via AuthHandler (which will show wizard completion popover)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
          (route) => false,
        );
      }
    } catch (e) {
      errorNotifier.value = 'Failed to complete signup: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildKeyboardAwareSubStep(Widget child, {bool lockKeyboard = false}) {
    // Compute a height that keeps content visible above the keyboard when locked.
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final keyboardHeight = mq.viewInsets.bottom;
    final baseHeight = screenHeight * 0.75;

    final topBuffer = 80.0;
    // Available height when keyboard is open
    final availableHeight = max(0.0, screenHeight - keyboardHeight - topBuffer);
    final containerHeight =
        lockKeyboard ? min(baseHeight, availableHeight) : baseHeight;

    final content = lockKeyboard
        ? SizedBox(
            height: containerHeight,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: child,
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
            child: Container(
              height: containerHeight,
              padding: const EdgeInsets.all(24.0),
              child: child,
            ),
          );

    return GestureDetector(
      onTap: () {
        if (!lockKeyboard) FocusScope.of(context).unfocus();
      },
      child: content,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          right: BorderSide(
            color: PinitColors.aubergine,
            width: 4,
          ),
          bottom: BorderSide(
            color: PinitColors.aubergine,
            width: 4,
          ),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        focusNode: focusNode,
        autofocus: false,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.dmSans(fontSize: 15, color: PinitColors.aubergine),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
              color: PinitColors.aubergineSoft.withValues(alpha: 0.6)),
          prefixIcon: Icon(icon,
              color: PinitColors.aubergineSoft.withValues(alpha: 0.6)),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: height != null ? 12 : 18,
          ),
          filled: true,
          fillColor: PinitColors.creamSunk,
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: errorNotifier,
      builder: (context, error, _) {
        if (error == null) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              right: BorderSide(
                color: PinitColors.aubergine,
                width: 4,
              ),
              bottom: BorderSide(
                color: PinitColors.aubergine,
                width: 4,
              ),
            ),
            boxShadow: PinitColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: PinitColors.aubergine, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  error,
                  style: GoogleFonts.dmSans(
                    color: PinitColors.aubergine,
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => errorNotifier.value = null,
                child:
                    Icon(Icons.close, size: 18, color: PinitColors.aubergine),
              ),
            ],
          ),
        );
      },
    );
  }

  // Focus on right text field based on current sub-step
  void _focusCurrentField() {
    if (!mounted) return;
    switch (_currentSubStep) {
      case 0:
        print('📍 [FOCUS] Reached Name step');
        FocusScope.of(context).requestFocus(nameFocusNode);
        break;
      case 1:
        print('📍 [FOCUS] Reached Username step');
        FocusScope.of(context).requestFocus(usernameFocusNode);
        break;
      case 2:
        print('📍 [FOCUS] Reached Email step');
        FocusScope.of(context).requestFocus(emailFocusNode);
        break;
      case 3:
        print('📍 [FOCUS] Reached Password step');
        FocusScope.of(context).requestFocus(passwordFocusNode);
        break;
      case 4:
        print('📍 [FOCUS] Reached Profile Picture step');
        FocusScope.of(context).unfocus();
        break;
      default:
        print('📍 [FOCUS] Reached default step');
        FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Container(
        decoration: const BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentSubStep = index);
            widget.onSubStepChanged?.call(index + 1);
            _focusCurrentField();
          },
          children: [
            _buildKeyboardAwareSubStep(_buildNameSubStep(), lockKeyboard: true),
            _buildKeyboardAwareSubStep(_buildUserNameSubStep(),
                lockKeyboard: true),
            _buildKeyboardAwareSubStep(_buildEmailSubStep(),
                lockKeyboard: true),
            _buildKeyboardAwareSubStep(_buildPasswordSubStep(),
                lockKeyboard: true),
            _buildKeyboardAwareSubStep(_buildProfilePictureSubStep()),
          ],
        ),
      ),
    );
  }

  // Sub-Step 1: Name Field
  Widget _buildNameSubStep() {
    return _buildAnimatedSubStep(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Top text with stagger
          SlideTransition(
            position: AnimationBuilders.createTextSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  TypingText(
                    key: ValueKey(_currentSubStep == 0),
                    text: 'What should we call you?',
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 18,
                      fontWeight: FontWeight.w100,
                      color: PinitColors.aubergine,
                      letterSpacing: 1.2,
                      height: 1.2,
                    ),
                    totalDuration: const Duration(milliseconds: 2200),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Middle: Name field
          SlideTransition(
            position: AnimationBuilders.createFieldSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  _buildErrorBanner(),
                  _buildTextField(
                    controller: nameController,
                    hintText: 'Full Name',
                    icon: Icons.person_outline,
                    focusNode: nameFocusNode,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom: Continue button
          SlideTransition(
            position: AnimationBuilders.createBottomSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    right: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                    bottom: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                  ),
                  boxShadow: PinitColors.cardShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_validateName()) {
                        _advanceToNextSubStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: PinitColors.cream,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w100,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Quote design
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Box space
                const SizedBox(height: 30),
                // Quote text
                Text(
                  'Did you know less than 5% of saved posts ever get looked at again',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.aubergine,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sub-Step 2: Username Field
  Widget _buildUserNameSubStep() {
    return _buildAnimatedSubStep(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Top text with stagger
          SlideTransition(
            position: AnimationBuilders.createTextSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  TypingText(
                    key: ValueKey(_currentSubStep == 1),
                    text: 'Pick a username for your mates to see..',
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 22,
                      fontWeight: FontWeight.normal,
                      color: PinitColors.aubergine,
                    ),
                    totalDuration: const Duration(milliseconds: 2200),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Middle: Name field
          SlideTransition(
            position: AnimationBuilders.createFieldSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  _buildErrorBanner(),
                  _buildTextField(
                    controller: usernameController,
                    hintText: 'User Name',
                    icon: Icons.person_outline,
                    focusNode: usernameFocusNode,
                  ),
                ],
              ),
            ),
          ),

          // Bottom: Continue button
          SlideTransition(
            position: AnimationBuilders.createBottomSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    right: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                    bottom: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                  ),
                  boxShadow: PinitColors.cardShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (await _validateUserName()) {
                        _advanceToNextSubStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: PinitColors.cream,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Quote design
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large quotation mark
                const SizedBox(height: 2),
                Text(
                  'Did you know the average person spends 40 minutes researching restaurants on social media before booking',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.aubergine,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sub-Step 3: Email Field
  Widget _buildEmailSubStep() {
    return _buildAnimatedSubStep(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Top text
          SlideTransition(
            position: AnimationBuilders.createTextSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  TypingText(
                    key: ValueKey(_currentSubStep == 2),
                    text: 'What\'s your email address?',
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 22,
                      fontWeight: FontWeight.normal,
                      color: PinitColors.aubergine,
                    ),
                    totalDuration: const Duration(milliseconds: 2200),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Middle: Email field
          SlideTransition(
            position: AnimationBuilders.createFieldSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  _buildErrorBanner(),
                  _buildTextField(
                    controller: emailController,
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: emailFocusNode,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bottom: Continue button
          SlideTransition(
            position: AnimationBuilders.createBottomSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    right: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                    bottom: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                  ),
                  boxShadow: PinitColors.cardShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (await _validateEmail()) {
                        _advanceToNextSubStep();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: PinitColors.cream,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Quote design
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Quote text
                Text(
                  '73% of people end up settling for a restaurant simply because it’s easier than deciding.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.aubergine,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sub-Step 4: Password Fields
  Widget _buildPasswordSubStep() {
    return _buildAnimatedSubStep(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Top text
          SlideTransition(
            position: AnimationBuilders.createTextSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  TypingText(
                    key: ValueKey(_currentSubStep == 3),
                    text: 'Create a secure password',
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 24,
                      fontWeight: FontWeight.normal,
                      color: PinitColors.aubergine,
                    ),
                    totalDuration: const Duration(milliseconds: 2200),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Middle: Password fields (staggered)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildErrorBanner(),
                  SlideTransition(
                    position: AnimationBuilders.createFieldSlideAnimation(
                        _transitionController),
                    child: FadeTransition(
                      opacity: AnimationBuilders.createFadeAnimation(
                          _transitionController),
                      child: _buildTextField(
                        controller: passwordController,
                        hintText: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: !_isPasswordVisible,
                        focusNode: passwordFocusNode,
                        height: 60,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _transitionController,
                      curve:
                          const Interval(0.15, 0.65, curve: Curves.easeOutBack),
                    )),
                    child: FadeTransition(
                      opacity: Tween<double>(
                        begin: 0.0,
                        end: 1.0,
                      ).animate(CurvedAnimation(
                        parent: _transitionController,
                        curve:
                            const Interval(0.15, 0.55, curve: Curves.easeInOut),
                      )),
                      child: _buildTextField(
                        controller: confirmPasswordController,
                        hintText: 'Confirm Password',
                        icon: Icons.lock_outline,
                        obscureText: !_isConfirmPasswordVisible,
                        height: 60,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: PinitColors.aubergine,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: Continue button
          SlideTransition(
            position: AnimationBuilders.createBottomSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        right: BorderSide(
                          color: PinitColors.aubergine,
                          width: 2,
                        ),
                        bottom: BorderSide(
                          color: PinitColors.aubergine,
                          width: 2,
                        ),
                      ),
                      boxShadow: PinitColors.cardShadow,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _advanceToNextSubStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PinitColors.aubergine,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const LoadingWidget(width: 24, height: 24)
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w100,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Sub-Step 5: Profile Picture (Final step)
  Widget _buildProfilePictureSubStep() {
    return _buildAnimatedSubStep(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Use the reusable ProfilePhotoSelector widget
          Expanded(
            child: Center(
              child: ProfilePhotoSelector(
                currentImage: _selectedProfileImage,
                onPhotoSelected: (File file) {
                  setState(() {
                    _selectedProfileImage = file;
                  });
                },
                onPhotoRemoved: () {
                  setState(() {
                    _selectedProfileImage = null;
                  });
                },
                animationController: _transitionController,
                borderColor: PinitColors.aubergine.withValues(alpha: 0.3),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Bottom: Buttons section
          SlideTransition(
            position: AnimationBuilders.createBottomSlideAnimation(
                _transitionController),
            child: FadeTransition(
              opacity:
                  AnimationBuilders.createFadeAnimation(_transitionController),
              child: Column(
                children: [
                  LegalConsentSection(
                    value: _legalConsentChecked,
                    onChanged: (value) {
                      setState(() {
                        _legalConsentChecked = value;
                      });
                      if (value && errorNotifier.value != null) {
                        errorNotifier.value = null;
                      }
                    },
                    textColor: PinitColors.aubergine,
                    linkColor: PinitColors.aubergine,
                    checkboxActiveColor: PinitColors.aubergine,
                    checkboxCheckColor: PinitColors.cream,
                    checkboxSideColor: PinitColors.aubergineSoft,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _createAccountAndAdvance,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PinitColors.aubergine,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isLoading
                          ? const LoadingWidget(width: 24, height: 24)
                          : Text(
                              _selectedProfileImage != null
                                  ? 'Create Account'
                                  : 'Skip & Create Account',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w100,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You\'re all set! Let\'s personalize your experience',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
