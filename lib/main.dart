import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audio_session/audio_session.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'l10n/app_localizations.dart';
import 'providers/audio_library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/library_screen.dart';
import 'screens/player_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 PackageInfo (官方推荐在 runApp 之前调用)
  final packageInfo = await PackageInfo.fromPlatform();

  // 初始化音频会话，支持后台播放 (仅限原生平台)
  if (!kIsWeb) {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      print('Audio session configured for background playback');
    } catch (e) {
      print('Error configuring audio session: $e');
    }
  } else {
    print('Web platform: skipping audio session configuration');
  }

  runApp(ListenMasterApp(packageInfo: packageInfo));
}

class ListenMasterApp extends StatelessWidget {
  final PackageInfo packageInfo;

  const ListenMasterApp({super.key, required this.packageInfo});

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PackageInfo>.value(value: packageInfo),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AudioLibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'Listen Master',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: settings.themeMode,
            locale: settings.locale,
            supportedLocales: const [Locale('en'), Locale('zh')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const MainScreen(),
            routes: {
              '/player': (context) => const PlayerScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load library on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioLibraryProvider>().loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 600;

        return Scaffold(
          body: Row(
            children: [
              if (isWideScreen)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: NavigationRail(
                    extended: constraints.maxWidth >= 800,
                    selectedIndex: _selectedIndex,
                    backgroundColor: Colors.transparent,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.library_music),
                        label: Text(l10n.library),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.play_circle),
                        label: Text(l10n.player),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.account_circle),
                        label: Text(l10n.account),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _getSelectedScreen()),
            ],
          ),
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.library_music, size: 24),
                      label: l10n.library,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.play_circle, size: 24),
                      label: l10n.player,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.account_circle, size: 24),
                      label: l10n.account,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const LibraryScreen();
      case 1:
        return const PlayerScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const LibraryScreen();
    }
  }
}
