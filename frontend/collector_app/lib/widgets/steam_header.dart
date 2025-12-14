import 'package:flutter/material.dart';
import '../theme/steam_theme.dart';

class SteamHeader extends StatelessWidget implements PreferredSizeWidget {
  final String active; // e.g. "LIBRARY"
  final void Function(String tab) onTab;

  const SteamHeader({
    super.key,
    required this.active,
    required this.onTab,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final tabs = const ["LIBRARY", "COLLECTIONS", "COMMUNITY", "PROFILE"];

    return DecoratedBox(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        SteamColors.bg,
        SteamColors.panel,
      ],
    ),
    border: Border(
      bottom: BorderSide(color: SteamColors.panel2.withOpacity(0.7), width: 1),
    ),
  ),
  child: SafeArea(
    bottom: false,
    child: SizedBox(
      height: preferredSize.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // keep everything you already have inside the Row
          ],
        ),
      ),
    ),
  ),
);

  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? SteamColors.text : SteamColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 3,
            width: active ? 64 : 0,
            decoration: BoxDecoration(
              color: SteamColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
