/// The Settings screen for Zephyr.
///
/// Displays grouped settings sections including API configuration,
/// feature toggles, RAG parameters, data management, and about info.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/app_constants.dart';
import '../../../../theme/zephyr_theme.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// Navigates to the settings screen.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SettingsViewModel>();
      vm.init();
      _apiKeyController.text = vm.geminiApiKey;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Saves the API key from the text field.
  Future<void> _saveApiKey() async {
    await context.read<SettingsViewModel>().saveApiKey(_apiKeyController.text);
    _showSnackBar('API key saved');
  }

  /// Shows a brief snackbar message.
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ZephyrColors.bgTertiary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusSm),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows the clear data confirmation dialog.
  Future<void> _showClearDataDialog() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear All Data'),
            content: const Text(
              'This will permanently delete all documents, conversations, '
              'chunks, and settings. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: ZephyrColors.error,
                ),
                child: const Text('Clear All'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      await context.read<SettingsViewModel>().clearData();
      _apiKeyController.clear();
      _showSnackBar('All data cleared');
    }
  }

  /// Shows the reset settings confirmation dialog.
  Future<void> _showResetSettingsDialog() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Settings'),
            content: const Text(
              'Reset all settings to their default values. Your API key '
              'and documents will be preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      await context.read<SettingsViewModel>().resetSettings();
      _showSnackBar('Settings reset to defaults');
    }
  }

  /// Handles exporting user data.
  Future<void> _handleExportData() async {
    final vm = context.read<SettingsViewModel>();
    final path = await vm.exportData();
    if (path != null && mounted) {
      _showSnackBar('Data exported to $path');
    } else if (mounted) {
      _showSnackBar('Export failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZephyrColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: UIConstants.spacingMd),
            children: [
              // ── API Configuration ────────────────────────────────
              const SettingsSection(
                title: 'API Configuration',
                subtitle: 'Configure your Gemini API key',
              ),
              _buildApiKeySection(vm),
              const SizedBox(height: 8),

              // ── Features ────────────────────────────────────────
              const SettingsSection(
                title: 'Features',
                subtitle: 'Toggle app features and behaviors',
              ),
              SettingsTile(
                leading: Icons.circle_rounded,
                title: 'Ghost Bubble',
                subtitle: 'Floating overlay for quick access',
                trailing: Switch(
                  value: vm.enableGhostBubble,
                  onChanged: (_) => vm.toggleGhostBubble(),
                ),
              ),
              SettingsTile(
                leading: Icons.accessibility_new_rounded,
                title: 'Accessibility',
                subtitle: 'Larger text and high contrast mode',
                trailing: Switch(
                  value: vm.enableAccessibility,
                  onChanged: (_) => vm.toggleAccessibility(),
                ),
              ),
              SettingsTile(
                leading: Icons.cloud_upload_rounded,
                title: 'Background Indexing',
                subtitle: 'Index documents in the background',
                trailing: Switch(
                  value: vm.enableBackgroundIndexing,
                  onChanged: (_) => vm.toggleBackgroundIndexing(),
                ),
              ),
              const SizedBox(height: 8),

              // ── RAG Settings ────────────────────────────────────
              const SettingsSection(
                title: 'RAG Settings',
                subtitle: 'Configure retrieval-augmented generation',
              ),
              _buildChunkSizeSlider(vm),
              _buildTopKSlider(vm),
              _buildSimilarityThresholdSlider(vm),
              const SizedBox(height: 8),

              // ── Data Management ─────────────────────────────────
              const SettingsSection(
                title: 'Data Management',
                subtitle: 'Export, clear, or reset your data',
              ),
              SettingsTile(
                leading: Icons.download_rounded,
                title: 'Export Data',
                subtitle: 'Save settings to a JSON file',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                ),
                onTap: _handleExportData,
              ),
              SettingsTile(
                leading: Icons.delete_sweep_rounded,
                title: 'Clear All Data',
                subtitle: 'Delete everything permanently',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.error,
                  size: 20,
                ),
                onTap: _showClearDataDialog,
                isDestructive: true,
              ),
              SettingsTile(
                leading: Icons.restore_rounded,
                title: 'Reset Settings',
                subtitle: 'Restore defaults (keeps API key)',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                ),
                onTap: _showResetSettingsDialog,
              ),
              const SizedBox(height: 8),

              // ── About ──────────────────────────────────────────
              const SettingsSection(
                title: 'About',
                subtitle: 'App information and links',
              ),
              SettingsTile(
                leading: Icons.info_outline_rounded,
                title: 'Version',
                subtitle: '1.0.0',
              ),
              SettingsTile(
                leading: Icons.code_rounded,
                title: 'GitHub',
                subtitle: 'View source code',
                trailing: const Icon(
                  Icons.open_in_new_rounded,
                  color: ZephyrColors.textMuted,
                  size: 18,
                ),
                onTap: () {
                  // TODO: launch URL
                },
              ),
              SettingsTile(
                leading: Icons.gavel_rounded,
                title: 'License',
                subtitle: 'MIT License',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                ),
                onTap: () {
                  // TODO: show license dialog
                },
              ),

              // Bottom padding.
              const SizedBox(height: 32),
            ],
          ).animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 400)),
              MoveEffect(
                begin: Offset(0, 10),
                duration: Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              ),
            ],
          );
        },
      ),
    );
  }

  // ── API Key Section ─────────────────────────────────────────────

  Widget _buildApiKeySection(SettingsViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: UIConstants.spacingMd),
      child: Column(
        children: [
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              hintText: 'Enter your Gemini API key',
              prefixIcon: const Icon(
                Icons.key_rounded,
                color: ZephyrColors.textMuted,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: ZephyrColors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              ),
              // Connection status helper text.
              helperText: vm.isApiKeySet ? 'Connected' : 'Not configured',
              helperStyle: TextStyle(
                color: vm.isApiKeySet
                    ? ZephyrColors.success
                    : ZephyrColors.textMuted,
                fontSize: 12,
              ),
              helperMaxLines: 1,
            ),
            onChanged: (value) {
              // Live update the controller text; save on button press.
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (vm.isApiKeySet)
                TextButton(
                  onPressed: () {
                    vm.clearApiKey();
                    _apiKeyController.clear();
                  },
                  child: const Text('Clear'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveApiKey,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chunk Size Slider ───────────────────────────────────────────

  Widget _buildChunkSizeSlider(SettingsViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chunk Size',
                style: const TextStyle(
                  color: ZephyrColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${vm.chunkSize}',
                style: const TextStyle(
                  color: ZephyrColors.accentPurpleLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: vm.chunkSize.toDouble(),
            min: 256,
            max: 2048,
            divisions: 15,
            label: '${vm.chunkSize}',
            onChanged: (value) => vm.updateChunkSize(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('256', style: _sliderLabelStyle),
              Text('2048', style: _sliderLabelStyle),
            ],
          ),
        ],
      ),
    );
  }

  // ── Top-K Slider ────────────────────────────────────────────────

  Widget _buildTopKSlider(SettingsViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top-K Retrieval',
                style: const TextStyle(
                  color: ZephyrColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${vm.topK}',
                style: const TextStyle(
                  color: ZephyrColors.accentPurpleLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: vm.topK.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            label: '${vm.topK}',
            onChanged: (value) => vm.updateTopK(value.round()),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: _sliderLabelStyle),
              Text('20', style: _sliderLabelStyle),
            ],
          ),
        ],
      ),
    );
  }

  // ── Similarity Threshold Slider ─────────────────────────────────

  Widget _buildSimilarityThresholdSlider(SettingsViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacingMd,
        vertical: UIConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Similarity Threshold',
                style: const TextStyle(
                  color: ZephyrColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                vm.similarityThreshold.toStringAsFixed(2),
                style: const TextStyle(
                  color: ZephyrColors.accentPurpleLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: vm.similarityThreshold,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: vm.similarityThreshold.toStringAsFixed(2),
            onChanged: (value) => vm.updateSimilarityThreshold(value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.00', style: _sliderLabelStyle),
              Text('1.00', style: _sliderLabelStyle),
            ],
          ),
        ],
      ),
    );
  }

  static const TextStyle _sliderLabelStyle = TextStyle(
    color: ZephyrColors.textMuted,
    fontSize: 11,
  );
}