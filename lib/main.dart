import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/judge/judge_shell.dart';
import 'services/app_logger.dart';
import 'services/providers.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MunqabatCompetitionApp()));
}

class MunqabatCompetitionApp extends ConsumerWidget {
  const MunqabatCompetitionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Munqabat Competition',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

// ─── Auth Gate ────────────────────────────────────────────────────────────────

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const _LoadingScreen(),
      error: (e, _) {
        appLogger.e('Auth state error', error: e);
        return const Scaffold(
          body: Center(child: Text('Authentication error. Please try again.')),
        );
      },
      data: (user) {
        if (user == null) return const LoginScreen();
        return const _RoleRouter();
      },
    );
  }
}

// ─── Role Router — reads Firestore role and sends to the right shell ──────────

class _RoleRouter extends ConsumerWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      loading: () => const _LoadingScreen(),
      error: (e, _) {
        appLogger.e('User profile error', error: e);
        return const Scaffold(
          body: Center(child: Text('Unable to load your profile.')),
        );
      },
      data: (appUser) {
        if (appUser == null) return const _AccessDeniedScreen();
        switch (appUser.role) {
          case UserRole.admin:
            return const MainShell();
          case UserRole.judge:
            return JudgeShell(judge: appUser);
          case UserRole.neither:
            return const _AccessDeniedScreen();
        }
      },
    );
  }
}

// ─── Shared utility screens ───────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
    );
  }
}

class _AccessDeniedScreen extends ConsumerWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 56,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'You do not have access to this app.\nContact an administrator to get a role assigned.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                onPressed: () => ref.read(firebaseServiceProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
