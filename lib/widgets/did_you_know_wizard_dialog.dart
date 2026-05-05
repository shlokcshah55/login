import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

enum DidYouKnowWizardId {
  tiktokSharing,
  collections,
  bubbles,
  shareToBubble,
}

@immutable
class DidYouKnowWizardPage {
  final String illustrationAssetPath;
  final String title;
  final String description;

  const DidYouKnowWizardPage({
    required this.illustrationAssetPath,
    required this.title,
    required this.description,
  });
}

@immutable
class DidYouKnowWizard {
  final DidYouKnowWizardId id;
  final String header;
  final List<DidYouKnowWizardPage> pages;

  const DidYouKnowWizard({
    required this.id,
    required this.header,
    required this.pages,
  });
}

class DidYouKnowWizards {
  DidYouKnowWizards._();

  static const DidYouKnowWizard tiktokSharing = DidYouKnowWizard(
    id: DidYouKnowWizardId.tiktokSharing,
    header: 'We pin spots directly from social media..',
    pages: [
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/tiktok1.png',
        title: 'Step 1 : See a place you want to visit, hit share!',
        description: '',
      ),
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/tiktok2.png',
        title: 'Step 2 : Swipe to the end and click more!',
        description: '',
      ),
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/tiktok3.png',
        title: 'Step 3 : Hit pinit and now your done!',
        description: '',
      ),
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/tiktok4.png',
        title: 'Step 4: We\'ll let you know when you\'re nearby!',
        description: '',
      ),
    ],
  );

  static const DidYouKnowWizard collections = DidYouKnowWizard(
    id: DidYouKnowWizardId.collections,
    header: 'We sort your places into eat-lists',
    pages: [
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/Eatlists.png',
        title: '',
        description:
            'We automatically generate eat-lists from your saved or you can create your own to organize your spots anyway you like.',
      ),
    ],
  );

  static const DidYouKnowWizard bubbles = DidYouKnowWizard(
    id: DidYouKnowWizardId.bubbles,
    header: 'Bubbles find places that suit all of your mates',
    pages: [
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/bubble.png',
        title: '',
        description:
            'Bubbles group places by vibe — great for planning with friends.',
      ),
    ],
  );

  static const DidYouKnowWizard shareToBubble = DidYouKnowWizard(
    id: DidYouKnowWizardId.shareToBubble,
    header: ' You can share a place directly to a bubble',
    pages: [
      DidYouKnowWizardPage(
        illustrationAssetPath: 'lib/assets/wizards/Send-to-bubble.png',
        title: '',
        description: 'Send your bubble a place you think they\'d like',
      ),
    ],
  );

  static DidYouKnowWizard byId(DidYouKnowWizardId id) {
    switch (id) {
      case DidYouKnowWizardId.tiktokSharing:
        return tiktokSharing;
      case DidYouKnowWizardId.collections:
        return collections;
      case DidYouKnowWizardId.bubbles:
        return bubbles;
      case DidYouKnowWizardId.shareToBubble:
        return shareToBubble;
    }
  }
}

class DidYouKnowWizardDialog extends StatefulWidget {
  final DidYouKnowWizard wizard;

  const DidYouKnowWizardDialog({
    super.key,
    required this.wizard,
  });

  static Future<void> show(
    BuildContext context, {
    required DidYouKnowWizard wizard,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, __) =>
          DidYouKnowWizardDialog(wizard: wizard),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<DidYouKnowWizardDialog> createState() => _DidYouKnowWizardDialogState();
}

class _DidYouKnowWizardDialogState extends State<DidYouKnowWizardDialog> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pages = widget.wizard.pages;
    final isScreenshotWizard = pages.isNotEmpty &&
        pages.every(
          (p) => _WizardMediaCard._isScreenshotAsset(p.illustrationAssetPath),
        );
    final useDarkDialogBackground = !isScreenshotWizard;
    final maxDialogHeightFactor =
        widget.wizard.id == DidYouKnowWizardId.tiktokSharing ? 0.82 : 0.72;
    final dialogHorizontalPadding = isScreenshotWizard ? 16.0 : 20.0;
    final maxDialogWidth = isScreenshotWizard ? 420.0 : 340.0;
    final maxDialogHeight = size.height *
        (isScreenshotWizard ? 0.82 : (maxDialogHeightFactor - 0.10));

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dialogHorizontalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxDialogWidth,
              maxHeight: maxDialogHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: useDarkDialogBackground ? null : PinitColors.cream,
                gradient: useDarkDialogBackground
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          PinitColors.aubergine,
                          Color(0xFF0B0B0D),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: useDarkDialogBackground
                      ? Colors.white.withValues(alpha: 0.18)
                      : PinitColors.creamDeep,
                  width: 1.5,
                ),
              ),
              child: isScreenshotWizard
                  ? _ScreenshotWizardBody(
                      pages: pages,
                      pageController: _pageController,
                      pageIndex: _pageIndex,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      header: widget.wizard.header,
                      onClose: () => Navigator.of(context).pop(),
                      wizardId: widget.wizard.id,
                    )
                  : _IllustrationWizardBody(
                      pages: pages,
                      pageController: _pageController,
                      pageIndex: _pageIndex,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      header: widget.wizard.header,
                      onClose: () => Navigator.of(context).pop(),
                      useDarkTheme: useDarkDialogBackground,
                      wizardId: widget.wizard.id,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IllustrationWizardBody extends StatelessWidget {
  final List<DidYouKnowWizardPage> pages;
  final PageController pageController;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final String header;
  final VoidCallback onClose;
  final bool useDarkTheme;
  final DidYouKnowWizardId wizardId;

  const _IllustrationWizardBody({
    required this.pages,
    required this.pageController,
    required this.pageIndex,
    required this.onPageChanged,
    required this.header,
    required this.onClose,
    required this.useDarkTheme,
    required this.wizardId,
  });

  @override
  Widget build(BuildContext context) {
    final didYouKnowColor = useDarkTheme
        ? Colors.white.withValues(alpha: 0.88)
        : PinitColors.aubergineSoft;
    final headerColor = useDarkTheme ? Colors.white : PinitColors.aubergine;
    final titleColor = useDarkTheme
        ? Colors.white.withValues(alpha: 0.95)
        : PinitColors.aubergine;
    final descriptionColor = useDarkTheme
        ? Colors.white.withValues(alpha: 0.80)
        : PinitColors.aubergineSoft;
    final grabHandleColor = useDarkTheme
        ? Colors.white.withValues(alpha: 0.22)
        : PinitColors.creamDeep;

    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: grabHandleColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [

              Expanded(
                child: Text(
                  'DID YOU KNOW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: didYouKnowColor,
                    letterSpacing: 1.32,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: useDarkTheme
                        ? PinitColors.creamSunk.withValues(alpha: 0.88)
                        : PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: useDarkTheme
                          ? Colors.white.withValues(alpha: 0.45)
                          : PinitColors.creamDeep,
                      width: useDarkTheme ? 1.2 : 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: PinitColors.aubergine,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              header,
              style: AppTypography.brand(
                fontSize: 32,
                fontWeight: FontWeight.w100,
                color: headerColor,
                letterSpacing: 1.2,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              itemCount: pages.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final page = pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: _WizardMediaCard(
                          assetPath: page.illustrationAssetPath,
                        ),
                      ),
                      const SizedBox(height: 10),
                      useDarkTheme
                          ? _DotIndicator(
                              count: pages.length,
                              index: pageIndex,
                              activeColor: Colors.white,
                              inactiveColor:
                                  Colors.white.withValues(alpha: 0.30),
                            )
                          : _DotIndicator(
                              count: pages.length, index: pageIndex),
                      const SizedBox(height: 16),
                      Text(
                        page.title,
                        style: AppTypography.brand(
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: titleColor,
                          height: 1.1,
                        ),
                      ),
                      if (page.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          page.description,
                          style: AppTypography.sans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: descriptionColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotWizardBody extends StatelessWidget {
  static const String _tiktokTryItUrlRaw = 'https://vm.tiktok.com/ZNRb3SMLF/';

  final List<DidYouKnowWizardPage> pages;
  final PageController pageController;
  final int pageIndex;
  final ValueChanged<int> onPageChanged;
  final String header;
  final VoidCallback onClose;
  final DidYouKnowWizardId wizardId;
  final bool showClose;
  final Widget? bottomAction;

  const _ScreenshotWizardBody({
    required this.pages,
    required this.pageController,
    required this.pageIndex,
    required this.onPageChanged,
    required this.header,
    required this.onClose,
    required this.wizardId,
    this.showClose = true,
    this.bottomAction,
  });

  Uri? _tiktokTryItUri() {
    final raw = _tiktokTryItUrlRaw.trim();
    if (raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    if (!parsed.hasScheme) return null;
    return parsed;
  }

  Future<void> _openTryItTikTok(BuildContext context) async {
    final uri = _tiktokTryItUri();
    if (uri == null) {
      await AppFeedback.showError(
        context,
        title: 'Missing TikTok link',
        message:
            'Set --dart-define=DID_YOU_KNOW_TIKTOK_TRY_IT_URL=<tiktok link> to enable this button.',
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      await AppFeedback.showError(
        context,
        title: 'Couldn’t open TikTok',
        message: 'Unable to open TikTok right now.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activePage =
        pages.isEmpty ? null : pages[(pageIndex.clamp(0, pages.length - 1))];
    final isTryItOutPage = wizardId == DidYouKnowWizardId.tiktokSharing &&
        pages.isNotEmpty &&
        pageIndex == pages.length - 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: pageController,
              itemCount: pages.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final page = pages[index];
                return _ScreenshotPage(assetPath: page.illustrationAssetPath);
              },
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x99000000),
                      Color(0x1A000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.45, 0.85],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                        const SizedBox(height: 32),

                    Text(
                      'DID YOU KNOW',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.88),
                        letterSpacing: 1.32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      header,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.brand(
                        fontSize: 22,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if ((activePage?.title ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        activePage!.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 0.6,
                          height: 1.15,
                        ),
                      ),
                    ],
                    if ((activePage?.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        activePage!.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: showClose
                ? GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: PinitColors.aubergine,
                        size: 18,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (pages.length > 1)
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTryItOutPage) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openTryItTikTok(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PinitColors.cream,
                          foregroundColor: PinitColors.aubergine,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: Text(
                          'Try it out',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (isTryItOutPage && bottomAction != null) ...[
                    bottomAction!,
                    const SizedBox(height: 10),
                  ],
                  _DotIndicator(
                    count: pages.length,
                    index: pageIndex,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.30),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class WhatWeDoWizardOverlay extends StatefulWidget {
  const WhatWeDoWizardOverlay({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => const WhatWeDoWizardOverlay()),
    );
  }

  @override
  State<WhatWeDoWizardOverlay> createState() => _WhatWeDoWizardOverlayState();
}

class _WhatWeDoWizardOverlayState extends State<WhatWeDoWizardOverlay> {
  late final PageController _tiktokController;
  int _tiktokIndex = 0;

  @override
  void initState() {
    super.initState();
    _tiktokController = PageController();
  }

  @override
  void dispose() {
    _tiktokController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = DidYouKnowWizards.tiktokSharing.pages;

    final onTiktokLastPage =
        pages.isNotEmpty && _tiktokIndex == pages.length - 1;
      final size = MediaQuery.sizeOf(context);
    final maxWidth = 440.0;
    final maxHeight = size.height * 0.88;
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        PinitColors.aubergine,
                        Color(0xFF0B0B0D),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: PinitColors.aubergine,
                        blurRadius: 0,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: _ScreenshotWizardBody(
                      pages: pages,
                      pageController: _tiktokController,
                      pageIndex: _tiktokIndex,
                      onPageChanged: (i) => setState(() => _tiktokIndex = i),
                      header: DidYouKnowWizards.tiktokSharing.header,
                      onClose: () => Navigator.of(context).pop(),
                      wizardId: DidYouKnowWizardId.tiktokSharing,
                      showClose: true,
                      bottomAction: onTiktokLastPage
                          ? SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                      width: 1.2,
                                    ),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Text(
                                  'Got it',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),
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

class _ScreenshotPage extends StatelessWidget {
  final String assetPath;

  const _ScreenshotPage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PinitColors.aubergine,
                Color(0xFF0B0B0D),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: const Alignment(0, 0.1),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int index;
  final Color activeColor;
  final Color inactiveColor;

  const _DotIndicator({
    required this.count,
    required this.index,
    this.activeColor = PinitColors.aubergine,
    this.inactiveColor = PinitColors.creamDeep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == index ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == index ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _WizardMediaCard extends StatelessWidget {
  final String assetPath;

  const _WizardMediaCard({
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    final isScreenshot = _isScreenshotAsset(assetPath);
    final height = isScreenshot ? 300.0 : 232.0;
    final padding = isScreenshot ? EdgeInsets.zero : const EdgeInsets.all(10);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: _buildAsset(padding: padding),
    );
  }

  static bool _isScreenshotAsset(String path) {
    final lower = path.toLowerCase();
    final isRaster = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
    return isRaster && lower.contains('/assets/wizards/');
  }

  Widget _buildAsset({required EdgeInsets padding}) {
    final lower = assetPath.toLowerCase();
    final Widget content = lower.endsWith('.svg')
        ? SvgPicture.asset(assetPath, fit: BoxFit.contain)
        : Image.asset(
            assetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );

    if (padding == EdgeInsets.zero) return content;
    return Padding(padding: padding, child: content);
  }
}
