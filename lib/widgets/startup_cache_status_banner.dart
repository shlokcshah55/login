import 'package:flutter/material.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:provider/provider.dart';

class StartupCacheStatusBanner extends StatelessWidget {
  const StartupCacheStatusBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isShowingStaleData = context.select<StartupCacheCoordinator, bool>(
      (coordinator) =>
          coordinator.refreshStatus == StartupCacheRefreshStatus.stale,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isShowingStaleData)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Showing saved data',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
