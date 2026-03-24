import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _autoScrollEnabled = true;
  bool _soundEnabled = false;
  String _language = 'English';
  String _fontSize = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _autoScrollEnabled = prefs.getBool('auto_scroll_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? false;
      _language = prefs.getString('language') ?? 'English';
      _fontSize = prefs.getString('font_size') ?? 'Medium';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('auto_scroll_enabled', _autoScrollEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setString('language', _language);
    await prefs.setString('font_size', _fontSize);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _darkMode;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2D2D2D),
                    const Color(0xFF1A1A1A),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.72),
                    const Color(0xFFFFF8E7).withOpacity(0.40),
                  ],
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.1),
                  border: Border.all(
                    color: isDark 
                        ? const Color(0xFFFFD27D).withOpacity(0.3)
                        : const Color(0xFFFFD27D).withOpacity(0.42),
                    width: 1.0,
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.templeBrown,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Appearance Section
                    _buildSectionHeader('Appearance', isDark),
                    _buildSwitchTile(
                      'Dark Mode',
                      'Enable dark theme for the app',
                      _darkMode,
                      (value) {
                        setState(() {
                          _darkMode = value;
                        });
                        _saveSettings();
                      },
                      isDark,
                      Icons.dark_mode_rounded,
                    ),
                    _buildLanguageTile(isDark),
                    _buildFontSizeTile(isDark),
                    
                    const SizedBox(height: 16),
                    
                    // Dashboard Settings Section
                    _buildSectionHeader('Dashboard Settings', isDark),
                    _buildSwitchTile(
                      'Auto-Scroll Carousel',
                      'Automatically scroll through temple images',
                      _autoScrollEnabled,
                      (value) {
                        setState(() {
                          _autoScrollEnabled = value;
                        });
                        _saveSettings();
                      },
                      isDark,
                      Icons.slideshow_rounded,
                    ),
                    _buildSwitchTile(
                      'Temple Bell Sound',
                      'Play a subtle bell sound when dashboard opens',
                      widget.bellEnabled,
                      widget.onBellEnabledChanged,
                      isDark,
                      Icons.notifications_active_rounded,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Notifications Section
                    _buildSectionHeader('Notifications', isDark),
                    _buildSwitchTile(
                      'Push Notifications',
                      'Receive notifications about temple activities',
                      _notificationsEnabled,
                      (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _saveSettings();
                      },
                      isDark,
                      Icons.notifications_rounded,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // About Section
                    _buildSectionHeader('About', isDark),
                    _buildMenuTile(
                      'System Info',
                      'App version and system details',
                      isDark,
                      Icons.info_outline_rounded,
                      () {},
                    ),
                    _buildMenuTile(
                      'Help & Support',
                      'Get help with the app',
                      isDark,
                      Icons.help_outline_rounded,
                      () {},
                    ),
                    _buildMenuTile(
                      'Privacy Policy',
                      'View our privacy policy',
                      isDark,
                      Icons.privacy_tip_outlined,
                      () {},
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Logout
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade400,
                            Colors.red.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: widget.onLogout,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    bool isDark,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D2D).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFFFFD27D).withOpacity(0.2)
              : const Color(0xFFFFD27D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.templeBrown,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
      ),
    );
  }

  Widget _buildLanguageTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D2D).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFFFFD27D).withOpacity(0.2)
              : const Color(0xFFFFD27D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.language_rounded,
          color: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
        title: Text(
          'Language',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.templeBrown,
          ),
        ),
        subtitle: Text(
          _language,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey,
        ),
        onTap: () {
          // Show language selection dialog
        },
      ),
    );
  }

  Widget _buildFontSizeTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D2D).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFFFFD27D).withOpacity(0.2)
              : const Color(0xFFFFD27D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.text_fields_rounded,
          color: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
        title: Text(
          'Font Size',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.templeBrown,
          ),
        ),
        subtitle: Text(
          _fontSize,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey,
        ),
        onTap: () {
          // Show font size selection dialog
        },
      ),
    );
  }

  Widget _buildMenuTile(
    String title,
    String subtitle,
    bool isDark,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF2D2D2D).withOpacity(0.8)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? const Color(0xFFFFD27D).withOpacity(0.2)
              : const Color(0xFFFFD27D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDark ? const Color(0xFFFFD27D) : AppTheme.deepSaffron,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.templeBrown,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
