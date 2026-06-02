// lib/main.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import 'package:app_links/app_links.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/order/providers/order_provider.dart';
import 'features/catalog/screens/home_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/subscription/screens/subscription_screen.dart';
import 'features/subscription/providers/subscription_provider.dart';

// ─── Singleton AppLinks + pending URI ────────────────────────────────
// Diinisialisasi sebelum runApp agar tidak ada deeplink yang terlewat
// saat app baru dibuka dari background oleh Android Intent.
final _appLinks = AppLinks();
Uri? _pendingUri; // simpan URI jika datang sebelum widget siap

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  // Tangkap cold-start URI sedini mungkin — sebelum runApp
  try {
    _pendingUri = await _appLinks.getInitialLink();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: EduVaultApp()));
}

class EduVaultApp extends ConsumerStatefulWidget {
  const EduVaultApp({super.key});

  @override
  ConsumerState<EduVaultApp> createState() => _EduVaultAppState();
}

class _EduVaultAppState extends ConsumerState<EduVaultApp> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _initDeepLinks() {
    // 1. Proses cold-start URI yang sudah ditangkap di main()
    if (_pendingUri != null) {
      final uri = _pendingUri!;
      _pendingUri = null;
      // Post-frame agar provider sudah terikat ke widget tree
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleDeepLink(uri);
      });
    }

    // 2. Warm-start — app sudah jalan, deeplink masuk lewat stream
    _linkSub = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri),
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'eduvault' || uri.host != 'auth') return;

    final error = uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Login Google gagal: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      await ref.read(authProvider.notifier).loginWithGoogleToken(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isLoggedIn && !(prev?.isLoggedIn ?? false)) {
        ref.read(subscriptionProvider.notifier).fetchMySubscription();
      }
    });
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
        home: const MainShell(),
      ),
    );
  }
}

// ─── Main Shell dengan Bottom Navigation ─────────────────────────────
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    SubscriptionScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Beranda',
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: 'Koleksi',
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Premium',
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profil',
                  isActive: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF1D9E75).withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isActive
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? const Color(0xFF1D9E75)
                      : const Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}