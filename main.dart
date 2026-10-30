import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'screens/pdf_screen.dart';
import 'screens/excel_screen.dart';
import 'screens/image_screen.dart';
import 'screens/ppt_screen.dart';
import 'screens/certificate_screen.dart';
import 'screens/convert_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(VedantApp(prefs: prefs));
}

class VedantApp extends StatefulWidget {
  final SharedPreferences prefs;
  const VedantApp({super.key, required this.prefs});

  @override
  State<VedantApp> createState() => _VedantAppState();
}

class _VedantAppState extends State<VedantApp> {
  late ThemeMode _mode;
  StreamSubscription? _intentSub;
  String? _pendingFilePath;

  @override
  void initState() {
    super.initState();
    _mode = widget.prefs.getBool('dark') == true
        ? ThemeMode.dark
        : ThemeMode.light;

    // Handle "Open with" — file shared while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) {
          setState(() => _pendingFilePath = files.first.path);
        }
      },
    );

    // Handle "Open with" — app launched from file
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        setState(() => _pendingFilePath = files.first.path);
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  void toggleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    widget.prefs.setBool('dark', _mode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vedant',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(
        onToggleTheme: toggleTheme,
        isDark: _mode == ThemeMode.dark,
        pendingFilePath: _pendingFilePath,
        onPendingHandled: () => setState(() => _pendingFilePath = null),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E0E) : Colors.white;
    final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    const red = Color(0xFFCC2222);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: red,
        onPrimary: Colors.white,
        primaryContainer: isDark ? const Color(0xFF3A0A0A) : const Color(0xFFFFEEEE),
        onPrimaryContainer: fg,
        secondary: red,
        onSecondary: Colors.white,
        secondaryContainer: surface,
        onSecondaryContainer: fg,
        tertiary: red,
        onTertiary: Colors.white,
        tertiaryContainer: surface,
        onTertiaryContainer: fg,
        error: Colors.red,
        onError: Colors.white,
        errorContainer: surface,
        onErrorContainer: fg,
        background: bg,
        onBackground: fg,
        surface: surface,
        onSurface: fg,
        surfaceVariant: isDark ? const Color(0xFF202020) : const Color(0xFFF5F5F3),
        onSurfaceVariant: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
        outline: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0DC),
        outlineVariant: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFECECE8),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: isDark ? Colors.white : const Color(0xFF111111),
        onInverseSurface: isDark ? const Color(0xFF111111) : Colors.white,
        inversePrimary: red,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.caveat(
          fontSize: 56, fontWeight: FontWeight.w700, color: fg,
        ),
        displayMedium: GoogleFonts.caveat(
          fontSize: 40, fontWeight: FontWeight.w700, color: fg,
        ),
        headlineLarge: GoogleFonts.caveat(
          fontSize: 32, fontWeight: FontWeight.w700, color: fg,
        ),
        headlineMedium: GoogleFonts.caveat(
          fontSize: 26, fontWeight: FontWeight.w700, color: fg,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.caveat(
          fontSize: 22, fontWeight: FontWeight.w700, color: fg,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: bg,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF222222) : const Color(0xFFE8E8E4),
        thickness: 1, space: 1,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? const Color(0xFF222222) : const Color(0xFFE8E8E4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDD8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFDDDDD8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCC2222), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xFF999999) : const Color(0xFF777777),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Color(0xFFCC2222),
        thumbColor: Color(0xFFCC2222),
        inactiveTrackColor: Color(0x33CC2222),
        overlayColor: Color(0x22CC2222),
      ),
    );
  }
}

// ── SCREEN ROUTER ─────────────────────────────────────────────────────────────
class VedantRouter {
  static Widget routeToFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'pdf') return PDFScreen(filePath: path);
    if (['xlsx', 'xls', 'csv', 'ods'].contains(ext)) return ExcelScreen(filePath: path);
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) return ImageScreen(filePath: path);
    if (['pptx', 'ppt'].contains(ext)) return PPTScreen(filePath: path);
    if (['txt', 'md', 'json', 'xml'].contains(ext)) return ExcelScreen(filePath: path, isText: true);
    return const HomeScreen();
  }
}
