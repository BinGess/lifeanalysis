import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_state.dart';
import 'services/api.dart';
import 'services/storage.dart';
import 'ui/screens.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(api: DecisionApi(), store: DeviceStore());
  await state.load();
  runApp(LifeGuideApp(state: state));
}

class LifeGuideApp extends StatelessWidget {
  final AppState state;
  const LifeGuideApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '高性价比人生指南',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: AppTheme.build(Brightness.light),
    darkTheme: AppTheme.build(Brightness.dark),
    themeMode: ThemeMode.system,
    home: HomeShell(state: state),
  );
}
