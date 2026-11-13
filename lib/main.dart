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
import 'widgets/ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF070B14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(ChangeNotifierProvider(
      create: (_) => ApiService(), child: const NexusShieldApp()));
}

class AppColors {
  // Core surfaces
  static const bg        = Color(0xFF070B14);
  static const surface   = Color(0xFF0F1729);
  static const surface2  = Color(0xFF182338);
  static const border    = Color(0xFF22304A);

  // Brand
  static const red       = Color(0xFFF43F5E);
  static const orange    = Color(0xFFF97316);
  static const green     = Color(0xFF22C55E);
  static const blue      = Color(0xFF3B82F6);
  static const yellow    = Color(0xFFFBBF24);
  static const violet    = Color(0xFF8B5CF6);

  static const brandStart = Color(0xFFFF5A5F);
  static const brandMid   = Color(0xFFE11D48);
  static const brandEnd   = Color(0xFFF97316);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandStart, brandMid, brandEnd],
  );

  static const emberGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33F43F5E), Color(0x000F1729)],
  );

  // Text
  static const textPrim  = Color(0xFFF8FAFC);
  static const textSec   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // Light theme counterparts (Settings > Appearance)
  static const lightBg       = Color(0xFFF6F7FB);
  static const lightSurface  = Color(0xFFFFFFFF);
  static const lightBorder   = Color(0xFFE2E8F0);
  static const lightTextPrim = Color(0xFF0B1220);
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
            theme: _buildTheme(dark: false),
            darkTheme: _buildTheme(dark: true),
            themeMode:
                themeController.isDark ? ThemeMode.dark : ThemeMode.light,
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
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: textPrim,
      displayColor: textPrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgColor,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: AppColors.red,
              secondary: AppColors.orange,
              surface: AppColors.surface,
              error: Color(0xFFEF4444),
            )
          : ColorScheme.light(
              primary: AppColors.brandMid,
              secondary: AppColors.orange,
              surface: surfaceColor,
            ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.0),
        headlineMedium: textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.7),
        titleLarge: textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
        titleMedium: textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrim),
        titleTextStyle: GoogleFonts.inter(
          color: textPrim,
          fontWeight: FontWeight.w800,
          fontSize: 18,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandMid,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.1),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.orange,
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.025),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.red, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
        ),
        hintStyle: TextStyle(color: textSec),
        labelStyle: TextStyle(color: textSec),
      ),
      dividerTheme: DividerThemeData(
          color: borderColor.withValues(alpha: 0.7), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.surface2 : AppColors.lightTextPrim,
        contentTextStyle: GoogleFonts.inter(
            color: dark ? AppColors.textPrim : Colors.white, fontSize: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: borderColor),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        showDragHandle: true,
        dragHandleColor: borderColor,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.red),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        labelStyle: GoogleFonts.inter(color: textPrim, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
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
            body: Center(
                child: CircularProgressIndicator(color: AppColors.red)),
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

  final List<Widget> _screens = const [
    HomeScreen(),
    ScreenshotAnalyzerScreen(),
    TextAnalyzerScreen(),
    UrlCheckerScreen(),
    CopilotScreen(),
  ];

  static const _items = <_NavItem>[
    _NavItem(Icons.shield_outlined, Icons.shield_rounded, 'Home'),
    _NavItem(Icons.image_search_outlined, Icons.image_search_rounded, 'Screen'),
    _NavItem(Icons.text_snippet_outlined, Icons.text_snippet_rounded, 'Text'),
    _NavItem(Icons.link_outlined, Icons.link_rounded, 'URL'),
    _NavItem(Icons.smart_toy_outlined, Icons.smart_toy_rounded, 'Copilot'),
    _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  void _openMore(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _moreTile(sheetContext, Icons.history_rounded, 'History',
                  'Every scan you have run',
                  () => const HistoryScreen()),
              _moreTile(
                  sheetContext,
                  Icons.insights_rounded,
                  'My Protection Dashboard',
                  'Your personal risk score',
                  () => const PersonalDashboardScreen()),
              _moreTile(sheetContext, Icons.bar_chart_rounded, 'Analytics',
                  'Scan volume, trends and scam mix',
                  () => const DashboardScreen()),
              _moreTile(sheetContext, Icons.flag_rounded, 'Report a Scam',
                  'Help protect the community',
                  () => const ReportsScreen()),
              _moreTile(
                  sheetContext,
                  Icons.verified_rounded,
                  'Verify Internship Offer',
                  'Check before you pay any fee',
                  () => const InternshipVerifierScreen()),
              _moreTile(sheetContext, Icons.shield_moon_rounded,
                  'Threat Intel & News', 'Live scam intelligence',
                  () => const IntelScreen()),
              _moreTile(sheetContext, Icons.person_rounded, 'Profile & Settings',
                  'Account, security, preferences', () => const ProfileScreen()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreTile(BuildContext context, IconData icon, String label,
      String subtitle, Widget Function() builder) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.red, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.inter(
              color: AppColors.textPrim,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.inter(
              color: AppColors.textMuted, fontSize: 11.5)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final isMore = i == _items.length - 1;
            final selected = !isMore && i == _index;
            return Expanded(
              child: Pressable(
                scale: 0.92,
                onTap: () {
                  if (isMore) {
                    _openMore(context);
                  } else {
                    setState(() => _index = i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.red.withValues(alpha: 0.20),
                              AppColors.red.withValues(alpha: 0.04),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.active : item.icon,
                        size: 21,
                        color:
                            selected ? AppColors.red : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? AppColors.textPrim
                              : AppColors.textMuted,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData active;
  final String label;
  const _NavItem(this.icon, this.active, this.label);
}
