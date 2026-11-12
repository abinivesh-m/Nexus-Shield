import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/screenshot_analyzer_screen.dart';
import 'screens/text_analyzer_screen.dart';
import 'screens/url_checker_screen.dart';
import 'screens/copilot_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/internship_verifier_screen.dart';
import 'screens/intel/intel_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/dashboard/personal_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';
import 'widgets/clipboard_monitor.dart';
import 'widgets/biometric_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0f172a),
  ));
  runApp(ChangeNotifierProvider(create: (_) => ApiService(), child: const NexusShieldApp()));
}

class AppColors {
  static const bg       = Color(0xFF0f172a);
  static const surface  = Color(0xFF1e293b);
  static const surface2 = Color(0xFF263248);
  static const border   = Color(0xFF334155);
  static const red      = Color(0xFFdc2626);
  static const orange   = Color(0xFFf97316);
  static const green    = Color(0xFF22c55e);
  static const blue     = Color(0xFF3b82f6);
  static const yellow   = Color(0xFFfbbf24);
  static const textPrim = Color(0xFFf1f5f9);
  static const textSec  = Color(0xFF94a3b8);
  static const textMuted= Color(0xFF64748b);

  // Light theme counterparts (Phase 8 - Dark & Light themes)
  static const lightBg       = Color(0xFFf8fafc);
  static const lightSurface  = Color(0xFFffffff);
  static const lightBorder   = Color(0xFFe2e8f0);
  static const lightTextPrim = Color(0xFF0f172a);
  static const lightTextSec  = Color(0xFF475569);
}

class ThemeController extends ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;
  void setDark(bool value) {
    _isDark = value;
    notifyListeners();
  }
}

class NexusShieldApp extends StatelessWidget {
  const NexusShieldApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          return MaterialApp(
            title: 'NexusShield',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(dark: true),
            darkTheme: _buildTheme(dark: true),
            // A full light theme exists in _buildTheme(dark:false); kept dark as the
            // primary brand experience for now but wired through ThemeController
            // so Settings > Appearance can flip it (see profile/settings_screen.dart).
            themeMode: themeController.isDark ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme({required bool dark}) {
    final bgColor = dark ? AppColors.bg : AppColors.lightBg;
    final surfaceColor = dark ? AppColors.surface : AppColors.lightSurface;
    final borderColor = dark ? AppColors.border : AppColors.lightBorder;
    final textPrim = dark ? AppColors.textPrim : AppColors.lightTextPrim;
    final textSec = dark ? AppColors.textSec : AppColors.lightTextSec;

    final base = dark ? ThemeData.dark() : ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgColor,
      colorScheme: dark
          ? const ColorScheme.dark(primary: AppColors.red, secondary: AppColors.orange, surface: AppColors.surface)
          : ColorScheme.light(primary: AppColors.red, secondary: AppColors.orange, surface: surfaceColor),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: textPrim, displayColor: textPrim,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrim),
        titleTextStyle: TextStyle(color: textPrim, fontWeight: FontWeight.w700, fontSize: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
        hintStyle: TextStyle(color: textSec),
      ),
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),
    );
  }
}

/// Restores any saved session on startup and routes to Login or the main
/// app shell accordingly. Also reacts live to logout/login from anywhere
/// in the app since ApiService is a ChangeNotifier.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiService>().restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiService>(
      builder: (context, api, _) {
        if (!api.isInitialized) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator(color: AppColors.red)),
          );
        }
        return api.isAuthenticated
            ? BiometricGate(child: ClipboardMonitor(child: MainShell()))
            : const LoginScreen();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Core scanning tools stay on the bottom bar (matches the original
  // prototype's nav exactly); History, Reports, Intel, and Profile are one
  // tap away from Home via the quick-access row added to HomeScreen, plus
  // accessible through the app bar action below for direct access.
  final List<Widget> _screens = const [
    HomeScreen(),
    ScreenshotAnalyzerScreen(),
    TextAnalyzerScreen(),
    UrlCheckerScreen(),
    CopilotScreen(),
    DashboardScreen(),
  ];

  void _openMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            _moreTile(sheetContext, Icons.history, 'History', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
            _moreTile(sheetContext, Icons.insights_outlined, 'My Protection Dashboard', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const PersonalDashboardScreen()))),
            _moreTile(sheetContext, Icons.flag_outlined, 'Report a Scam', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
            _moreTile(sheetContext, Icons.verified_outlined, 'Verify Internship Offer', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const InternshipVerifierScreen()))),
            _moreTile(sheetContext, Icons.shield_moon_outlined, 'Threat Intel & News', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const IntelScreen()))),
            _moreTile(sheetContext, Icons.person_outline, 'Profile & Settings', () => Navigator.push(
                sheetContext, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrim),
      title: Text(label, style: GoogleFonts.inter(color: AppColors.textPrim, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openMore(context),
        backgroundColor: AppColors.surface2,
        elevation: 0,
        child: const Icon(Icons.apps_rounded, color: AppColors.textPrim),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
      child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.transparent,
        indicatorColor: AppColors.red.withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.shield, color: AppColors.red), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.image_search_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.image_search, color: AppColors.red), label: 'Screen'),
          NavigationDestination(icon: Icon(Icons.text_snippet_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.text_snippet, color: AppColors.red), label: 'Text'),
          NavigationDestination(icon: Icon(Icons.link_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.link, color: AppColors.red), label: 'URL'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.smart_toy, color: AppColors.red), label: 'Copilot'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined, color: AppColors.textMuted), selectedIcon: Icon(Icons.bar_chart, color: AppColors.red), label: 'Stats'),
        ],
      ),
    );
  }
}
