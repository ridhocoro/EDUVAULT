import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/catalog/screens/home_screen.dart';
import 'package:provider/provider.dart' as legacy; // Menggunakan alias agar tidak bentrok dengan Riverpod
import 'features/order/providers/order_provider.dart';
import 'features/chat/providers/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: EduVaultApp(),
    ),
  );
}

class EduVaultApp extends ConsumerStatefulWidget {
  const EduVaultApp({super.key});

  @override
  ConsumerState<EduVaultApp> createState() => _EduVaultAppState();
}

class _EduVaultAppState extends ConsumerState<EduVaultApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Tangkap deeplink saat app sudah terbuka (dari background)
    _appLinks.uriLinkStream.listen(
      (Uri uri) async {
        debugPrint('🔗 Deeplink diterima (stream): $uri');
        await _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('❌ Deeplink stream error: $err');
      },
    );

    // Tangkap deeplink saat app baru dibuka (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('🔗 Deeplink initial: $uri');
        _handleDeepLink(uri);
      } else {
        debugPrint('ℹ️ Tidak ada initial deeplink');
      }
    }).catchError((err) {
      debugPrint('❌ Initial deeplink error: $err');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('📌 Scheme: ${uri.scheme}, Host: ${uri.host}');
    debugPrint('📌 Params: ${uri.queryParameters}');

    if (uri.scheme == 'eduvault' && uri.host == 'auth') {
      final token = uri.queryParameters['token'];
      final error = uri.queryParameters['error'];

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token diterima, login...');
        await ref.read(authProvider.notifier).loginWithGoogleToken(token);
      } else if (error != null) {
        debugPrint('❌ OAuth error: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bungkus MaterialApp dengan ChangeNotifierProvider
    return legacy.ChangeNotifierProvider(
      create: (_) => OrderProvider(),
      child: MaterialApp(
        title: 'EduVault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1D9E75),
          ),
          fontFamily: 'Roboto',
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}