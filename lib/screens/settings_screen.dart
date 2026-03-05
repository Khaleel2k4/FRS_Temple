import 'dart:ui';

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.bellEnabled,
    required this.onBellEnabledChanged,
    required this.onLogout,
  });

  final bool bellEnabled;
  final ValueChanged<bool> onBellEnabledChanged;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.72),
                  const Color(0xFFFFF8E7).withOpacity(0.40),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD27D).withOpacity(0.42),
                width: 1.0,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: bellEnabled,
                  onChanged: onBellEnabledChanged,
                  title: const Text('Temple Bell Sound'),
                  subtitle: const Text('Play a subtle bell sound when dashboard opens'),
                ),
                const Divider(height: 22),
                ListTile(
                  leading: const Icon(Icons.color_lens_rounded),
                  title: const Text('Change Theme'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_rounded),
                  title: const Text('Notifications'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('System Info'),
                  onTap: () {},
                ),
                const Divider(height: 22),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Logout'),
                  onTap: onLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
