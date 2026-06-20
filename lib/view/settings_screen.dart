import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../enums/card_order.dart';
import '../service/settings_service.dart';
import '../util/dialog_util.dart';

/// Full-screen settings editor for voice (STT), speak (TTS), display, and study options.
///
/// All values are read from and written to [SettingsService] reactively via [Obx].
/// Persisted to Hive automatically by [SettingsService].
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── 🎤 Voice (STT) ──────────────────────────────────────────────
          _SectionHeader(label: '🎤  Voice (STT)', colorScheme: cs),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.mic_outlined),
                title: const Text('Mic button'),
                value: s.micEnabled.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.micEnabled.value = v,
              )),
          Obx(() => _SliderTile(
                icon: Icons.timer_outlined,
                title: 'STT silence timeout',
                subtitle:
                    'Fallback: stops if no speech detected within this time',
                trailing: '${(s.sttPauseMs.value / 1000).toStringAsFixed(1)}s',
                value: s.sttPauseMs.value.toDouble(),
                min: 1000,
                max: 5000,
                divisions: 8, // steps of 500
                onChanged: (v) => s.sttPauseMs.value = (v / 500).round() * 500,
              )),
          Obx(() => _SliderTile(
                icon: Icons.hourglass_bottom_outlined,
                title: 'Speech stability window',
                subtitle:
                    'How long speech must stay unchanged before being evaluated',
                trailing:
                    '${(s.sttStabilityMs.value / 1000).toStringAsFixed(1)}s',
                value: s.sttStabilityMs.value.toDouble(),
                min: 300,
                max: 1500,
                divisions: 12, // steps of 100
                onChanged: (v) =>
                    s.sttStabilityMs.value = (v / 100).round() * 100,
              )),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.search_outlined),
                title: const Text('Accept if contains'),
                subtitle: const Text(
                    'Pass if the expected phrase appears as a contiguous sequence in your answer (extra words before/after are fine)'),
                value: s.containsMode.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.containsMode.value = v,
              )),
          Obx(() => _SliderTile(
                icon: Icons.tune_outlined,
                title: 'Match strictness',
                subtitle:
                    'Only used when "Accept if contains" is OFF — how closely you must match',
                trailing: '${(s.sttThreshold.value * 100).round()}%',
                value: s.sttThreshold.value,
                min: 0.50,
                max: 1.0,
                divisions: 10, // steps of 0.05
                onChanged: (v) => s.sttThreshold.value =
                    (v * 20).round() / 20, // snap to 0.05
              )),

          // ── 🔊 Speak (TTS) ───────────────────────────────────────────────
          _SectionHeader(label: '🔊  Speak (TTS)', colorScheme: cs),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Speak button'),
                value: s.speakEnabled.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.speakEnabled.value = v,
              )),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.campaign_outlined),
                title: const Text('Auto-speak on card open'),
                subtitle: const Text('Reads the card aloud when you open it'),
                value: s.autoSpeak.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.autoSpeak.value = v,
              )),
          Obx(() => _SliderTile(
                icon: Icons.speed_outlined,
                title: 'Speech rate',
                subtitle: 'Speed of text-to-speech playback',
                trailing: _speechRateLabel(s.speechRate.value),
                value: s.speechRate.value,
                min: 0.2,
                max: 1.0,
                divisions: 16, // steps of 0.05
                onChanged: (v) => s.speechRate.value = (v * 20).round() / 20,
              )),

          // ── 📱 Display ────────────────────────────────────────────────────
          _SectionHeader(label: '📱  Display', colorScheme: cs),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.copy_outlined),
                title: const Text('Copy button'),
                value: s.copyEnabled.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.copyEnabled.value = v,
              )),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.light_mode_outlined),
                title: const Text('Description button'),
                value: s.descEnabled.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.descEnabled.value = v,
              )),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.tag_outlined),
                title: const Text('Show card counter'),
                subtitle: const Text("Shows '3 / 50' in the AppBar"),
                value: s.counterVisible.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.counterVisible.value = v,
              )),
          Obx(() => SwitchListTile(
                secondary: const Icon(Icons.brightness_2_outlined),
                title: const Text('AMOLED auto-dim'),
                subtitle: const Text(
                    'Dims screen after inactivity to protect AMOLED displays'),
                value: s.amoledDim.value,
                activeThumbColor: cs.primary,
                onChanged: (v) => s.amoledDim.value = v,
              )),
          Obx(() => _SliderTile(
                icon: Icons.hourglass_bottom_outlined,
                title: 'Auto-dim delay',
                subtitle: 'Minutes of inactivity before screen dims',
                trailing: '${s.dimDelayMin.value} min',
                value: s.dimDelayMin.value.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (v) => s.dimDelayMin.value = v.round(),
              )),

          // ── 🃏 Study ──────────────────────────────────────────────────────
          _SectionHeader(label: '🃏  Study', colorScheme: cs),
          Obx(() => Column(
                children: CardOrder.values
                    .map((order) => RadioListTile<CardOrder>(
                          secondary: Icon(_cardOrderIcon(order)),
                          title: Text(order.label),
                          subtitle: Text(order.subtitle),
                          value: order,
                          groupValue: s.cardOrder.value,
                          activeColor: cs.primary,
                          onChanged: (v) {
                            if (v != null) s.cardOrder.value = v;
                          },
                        ))
                    .toList(),
              )),

          // ── Reset ─────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton.icon(
              icon: Icon(Icons.restore_outlined, color: cs.error),
              label:
                  Text('Reset to defaults', style: TextStyle(color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => DialogUtil.okCancel(
                context,
                title: 'Reset settings?',
                description:
                    'All settings will be restored to their default values.',
                onOk: s.resetToDefaults,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps a speech-rate double to a human-readable label.
  String _speechRateLabel(double rate) {
    if (rate <= 0.3) return 'Slow';
    if (rate >= 0.75) return 'Fast';
    return 'Normal';
  }

  /// Icon for each [CardOrder] option.
  IconData _cardOrderIcon(CardOrder order) {
    switch (order) {
      case CardOrder.highFirst:
        return Icons.arrow_downward_rounded;
      case CardOrder.lowFirst:
        return Icons.arrow_upward_rounded;
      case CardOrder.random:
        return Icons.shuffle_rounded;
    }
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

/// Uppercase section header styled with [colorScheme.primary].
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.colorScheme});

  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}

/// A [ListTile] with a [Slider] as its content and the current value on the right.
class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodyLarge),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(trailing,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                      fontSize: 13)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: cs.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
