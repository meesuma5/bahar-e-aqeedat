import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import 'judge_home_screen.dart';
import 'judge_session_screen.dart';
import 'judge_history_screen.dart';

class JudgeShell extends StatefulWidget {
  final AppUser judge;
  const JudgeShell({super.key, required this.judge});

  @override
  State<JudgeShell> createState() => _JudgeShellState();
}

class _JudgeShellState extends State<JudgeShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _TabItem(
      icon: Icons.mic_none_outlined,
      activeIcon: Icons.mic_rounded,
      label: 'Session',
    ),
    _TabItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
  ];

  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [JudgeHomeScreen(judge: widget.judge), null, null];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens
            .map((screen) => screen ?? const SizedBox.shrink())
            .toList(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: List.generate(_tabs.length, _buildNavItem)),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final tab = _tabs[index];
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_screens[index] == null) {
            _screens[index] = switch (index) {
              1 => JudgeSessionScreen(judge: widget.judge),
              2 => JudgeHistoryScreen(judge: widget.judge),
              _ => JudgeHomeScreen(judge: widget.judge),
            };
          }
          setState(() => _currentIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? tab.activeIcon : tab.icon,
                color: isActive ? AppTheme.primary : AppTheme.textMuted,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppTheme.primary : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon, activeIcon;
  final String label;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
