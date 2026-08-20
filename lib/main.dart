import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth/splash_screen.dart';
import 'shared/services/auth_service.dart';
import 'shared/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'shared/services/notification_service.dart';
import 'shared/services/time_format_controller.dart';
import 'shared/services/notification_preferences.dart';
import 'shared/services/theme_mode_controller.dart';
import 'shared/services/schedule_display_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();

  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  }

  final timeFormatController = await TimeFormatController.load();
  final notificationPrefsController = await NotificationPreferencesController.load();
  final themeModeController = await ThemeModeController.load();
  final scheduleDisplayController = await ScheduleDisplayController.load();

  runApp(UniversityCompanionApp(
    timeFormatController: timeFormatController,
    notificationPrefsController: notificationPrefsController,
    themeModeController: themeModeController,
    scheduleDisplayController: scheduleDisplayController,
  ));
}

class UniversityCompanionApp extends StatelessWidget {
  final TimeFormatController timeFormatController;
  final NotificationPreferencesController notificationPrefsController;
  final ThemeModeController themeModeController;
  final ScheduleDisplayController scheduleDisplayController;

  const UniversityCompanionApp({
    super.key,
    required this.timeFormatController,
    required this.notificationPrefsController,
    required this.themeModeController,
    required this.scheduleDisplayController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<TimeFormatController>.value(value: timeFormatController),
        ChangeNotifierProvider<NotificationPreferencesController>.value(value: notificationPrefsController),
        ChangeNotifierProvider<ThemeModeController>.value(value: themeModeController),
        ChangeNotifierProvider<ScheduleDisplayController>.value(value: scheduleDisplayController),
      ],
      child: Consumer<ThemeModeController>(
        builder: (context, themeCtrl, _) {
          return MaterialApp(
            title: 'University Companion',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.themeData,
            darkTheme: AppThemeDark.darkThemeData,
            themeMode: themeCtrl.mode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}