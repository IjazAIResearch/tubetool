import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/translations.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeModeNotifier;

  const SettingsScreen({super.key, required this.themeModeNotifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Box _settingsBox;
  late String _selectedRegion;
  late ThemeMode _currentThemeMode;
  late String _selectedLang;

  final Map<String, String> _regions = {
    'US': 'United States',
    'GB': 'United Kingdom',
    'IN': 'India',
    'PK': 'Pakistan',
    'CA': 'Canada',
    'AU': 'Australia',
    'DE': 'Germany',
    'FR': 'France',
    'JP': 'Japan',
    'KR': 'South Korea',
    'BR': 'Brazil',
    'AE': 'UAE',
    'SA': 'Saudi Arabia',
    'TR': 'Turkey',
    'ID': 'Indonesia',
    'MY': 'Malaysia',
    'BD': 'Bangladesh',
    'NG': 'Nigeria',
    'EG': 'Egypt',
    'PH': 'Philippines',
  };

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box('settings');
    _selectedRegion = _settingsBox.get('defaultRegion', defaultValue: 'US');
    final themeIndex = _settingsBox.get('themeMode', defaultValue: 0);
    _currentThemeMode = ThemeMode.values[themeIndex];
    _selectedLang = _settingsBox.get('language', defaultValue: 'en');
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _currentThemeMode = mode);
    widget.themeModeNotifier.value = mode;
    _settingsBox.put('themeMode', mode.index);
  }

  void _setLanguage(String code) {
    setState(() => _selectedLang = code);
    _settingsBox.put('language', code);
    languageNotifier.value = code; // triggers full app rebuild
    AppStrings.lang = code;
  }

  void _setRegion(String code) {
    setState(() => _selectedRegion = code);
    _settingsBox.put('defaultRegion', code);
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including search history. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final searchHistoryBox = await Hive.openBox('search_history');
      await searchHistoryBox.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cache cleared successfully ✨'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [

                // ── Language Section ──
                _buildSectionHeader(AppStrings.language, Icons.language),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: Text(
                        AppStrings.supportedLanguages
                            .firstWhere((l) => l['code'] == _selectedLang,
                                orElse: () => AppStrings.supportedLanguages.first)['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        AppStrings.supportedLanguages
                            .firstWhere((l) => l['code'] == _selectedLang,
                                orElse: () => AppStrings.supportedLanguages.first)['name']!,
                      ),
                      subtitle: Text(AppStrings.selectLanguage),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: _showLanguagePicker,
                    ),
                  ),
                ),
                const Divider(height: 32),

                // ── Theme Section ──
                _buildSectionHeader(AppStrings.appearance, Icons.palette),
                _buildThemeTile(AppStrings.systemDefault, Icons.brightness_auto, ThemeMode.system),
                _buildThemeTile(AppStrings.lightMode, Icons.light_mode, ThemeMode.light),
                _buildThemeTile(AppStrings.darkMode, Icons.dark_mode, ThemeMode.dark),
                const Divider(height: 32),

                // ── Region Section ──
                _buildSectionHeader(AppStrings.defaultRegion, Icons.public),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.flag, color: colorScheme.primary),
                      title: Text(_regions[_selectedRegion] ?? _selectedRegion),
                      subtitle: Text('Region code: $_selectedRegion'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: _showRegionPicker,
                    ),
                  ),
                ),
                const Divider(height: 32),

                // ── Data Section ──
                _buildSectionHeader(AppStrings.data, Icons.storage),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.delete_sweep, color: Colors.red),
                      title: Text(AppStrings.clearCache),
                      subtitle: Text(AppStrings.clearCacheDesc),
                      onTap: _clearCache,
                    ),
                  ),
                ),
                const Divider(height: 32),

                // ── Final Year Project Section ──
                _buildSectionHeader('FINAL YEAR PROJECT', Icons.school),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TubeTool Intelligence Suite',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      'AI-Powered YouTube Creator Studio',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'An academic capstone project focused on natural language generation, video discoverability algorithms, and intelligent creator automation.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildChip('Flutter 3.x', Colors.blue),
                              _buildChip('Groq LLaMA-3.3', Colors.deepPurple),
                              _buildChip('YouTube API v3', Colors.red),
                              _buildChip('Hive NoSQL', Colors.amber.shade800),
                              _buildChip('Material 3', Colors.teal),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 32),

                // ── About Section ──
                _buildSectionHeader(AppStrings.about, Icons.info_outline),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.star, color: Colors.amber[700]),
                          title: Text(AppStrings.rateApp),
                          subtitle: Text(AppStrings.rateAppDesc),
                          onTap: () {
                            launchUrl(
                              Uri.parse('https://play.google.com/store/apps/details?id=com.ask.tubetool'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.share, color: colorScheme.primary),
                          title: Text(AppStrings.shareApp),
                          subtitle: Text(AppStrings.shareAppDesc),
                          onTap: () {
                            Share.share(
                              'Check out TubeTool - the modern AI-Powered YouTube Creator Studio & Analytics Suite! 🚀\n'
                              'https://play.google.com/store/apps/details?id=com.ask.tubetool',
                            );
                          },
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.info, color: Colors.grey),
                          title: Text('Edition'),
                          subtitle: Text('2.0.0 (FYP Academic Edition)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeTile(String title, IconData icon, ThemeMode mode) {
    final isSelected = _currentThemeMode == mode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: Text(title),
          trailing: isSelected
              ? Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () => _setThemeMode(mode),
        ),
      ),
    );
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx2, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(AppStrings.selectLanguage,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: AppStrings.supportedLanguages.length,
                itemBuilder: (_, index) {
                  final lang = AppStrings.supportedLanguages[index];
                  final isSelected = _selectedLang == lang['code'];
                  return ListTile(
                    leading: Text(lang['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(lang['name']!),
                    subtitle: Text(lang['code']!, style: const TextStyle(fontSize: 11)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      _setLanguage(lang['code']!);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = Map.fromEntries(
              _regions.entries.where(
                (e) =>
                    e.value.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    e.key.toLowerCase().contains(searchQuery.toLowerCase()),
              ),
            );
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, controller) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search regions...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (v) => setModalState(() => searchQuery = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered.entries.elementAt(index);
                        final isSelected = _selectedRegion == entry.key;
                        return ListTile(
                          leading: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          title: Text(entry.value),
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            _setRegion(entry.key);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
