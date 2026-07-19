import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/finance/recurring_review_card.dart';
import 'features/security/pin_lock_screen.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'services/share_intent_service.dart';
import 'state/reminder_sync.dart';
import 'state/settings_state.dart';
import 'theme/app_theme.dart';

class VibesightApp extends ConsumerStatefulWidget {
  const VibesightApp({super.key});

  @override
  ConsumerState<VibesightApp> createState() => _VibesightAppState();
}

class _VibesightAppState extends ConsumerState<VibesightApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire share-target intents once the first frame is up so navigator/router
    // are ready before incoming text is dispatched.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShareIntentService.instance.attach(ref);
      // Post any due auto-confirm recurring operations once on startup.
      processAutoRecurring(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Lock the app whenever it leaves the foreground so re-entry forces PIN
    // re-entry (matches React `PinLockScreen` visibilitychange behaviour).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(pinLockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    // Subscribe the reminder-scheduling bridge once for the lifetime of the
    // app. The provider has no value (Provider<void>) — reading it is enough
    // to register its `ref.listen` callbacks.
    ref.watch(reminderSyncProvider);

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    final overrideLocale = ref.watch(localeProvider);
    final pinLock = ref.watch(pinLockProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'Vibesight Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(dynamicScheme: lightDynamic),
          darkTheme: AppTheme.dark(dynamicScheme: darkDynamic),
          routerConfig: router,
          locale: overrideLocale ?? const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            if (pinLock.locked && pinLock.hasPin) {
              return Stack(
                children: [
                  if (child != null)
                    ExcludeFocus(
                      child:
                          ExcludeSemantics(child: IgnorePointer(child: child)),
                    ),
                  const Positioned.fill(child: PinLockScreen()),
                ],
              );
            }
            return child ?? const SizedBox.shrink();
          },
        );
      },
    );
  }
}
