import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../entity/deck_entity.dart';
import '../repository/deck_repository.dart';

/// Wizard screen for creating a new flashcard deck.
///
/// Steps: pick source language → pick target language → name → optional icon/color → create.
class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  static const _uuid = Uuid();

  // Supported languages.
  static const List<_Language> _languages = [
    _Language('en', 'English', '🇬🇧'),
    _Language('de', 'Deutsch', '🇩🇪'),
    _Language('fa', 'فارسی', '🇮🇷'),
    _Language('es', 'Español', '🇪🇸'),
    _Language('fr', 'Français', '🇫🇷'),
    _Language('it', 'Italiano', '🇮🇹'),
    _Language('pt', 'Português', '🇵🇹'),
    _Language('nl', 'Nederlands', '🇳🇱'),
    _Language('tr', 'Türkçe', '🇹🇷'),
    _Language('ar', 'العربية', '🇸🇦'),
    _Language('zh', '中文', '🇨🇳'),
    _Language('ja', '日本語', '🇯🇵'),
    _Language('ko', '한국어', '🇰🇷'),
    _Language('ru', 'Русский', '🇷🇺'),
    _Language('hi', 'हिन्दी', '🇮🇳'),
  ];

  static const List<int> _deckColors = [
    0xFF1565C0, // blue
    0xFFE65100, // orange
    0xFF00695C, // teal
    0xFF6A1B9A, // purple
    0xFFC62828, // red
    0xFF2E7D32, // green
    0xFF283593, // indigo
    0xFF4E342E, // brown
    0xFFAD1457, // pink
    0xFF00838F, // cyan
  ];

  static const List<IconData> _deckIcons = [
    Icons.translate,
    Icons.chat_bubble_outline,
    Icons.menu_book_outlined,
    Icons.school_outlined,
    Icons.science_outlined,
    Icons.code,
    Icons.music_note_outlined,
    Icons.image_outlined,
    Icons.format_list_bulleted,
    Icons.star_outline,
    Icons.flash_on_outlined,
    Icons.language,
  ];

  _Language? _sourceLang;
  _Language? _targetLang;
  final _nameController = TextEditingController();
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _autoSuggestName() {
    if (_sourceLang != null && _targetLang != null) {
      _nameController.text = '${_sourceLang!.name} → ${_targetLang!.name}';
    }
  }

  bool get _canCreate =>
      _sourceLang != null &&
      _targetLang != null &&
      _nameController.text.trim().isNotEmpty;

  Future<void> _createDeck() async {
    if (!_canCreate) return;

    final now = tz.TZDateTime.now(tz.local);
    final deck = DeckEntity(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      sourceLang: _sourceLang!.code,
      targetLang: _targetLang!.code,
      iconCodePoint: _deckIcons[_selectedIconIndex].codePoint,
      colorValue: _deckColors[_selectedColorIndex],
      createdAt: now,
      modifiedAt: now,
    );

    await Get.find<DeckRepository>().merge(deck);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Deck'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _sourceLang == null) return;
          if (_currentStep == 1 && _targetLang == null) return;
          if (_currentStep < 3) {
            if (_currentStep == 1) _autoSuggestName();
            setState(() => _currentStep++);
          } else {
            _createDeck();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 3;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLast ? 'Create Deck' : 'Continue'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                ),
              ],
            ),
          );
        },
        steps: [
          // Step 0: Source language.
          Step(
            title: Text(_sourceLang != null
                ? 'I speak: ${_sourceLang!.name}'
                : 'I speak...'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildLanguagePicker(
              selected: _sourceLang,
              exclude: _targetLang,
              onSelect: (lang) => setState(() => _sourceLang = lang),
            ),
          ),
          // Step 1: Target language.
          Step(
            title: Text(_targetLang != null
                ? 'I learn: ${_targetLang!.name}'
                : 'I want to learn...'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildLanguagePicker(
              selected: _targetLang,
              exclude: _sourceLang,
              onSelect: (lang) => setState(() => _targetLang = lang),
            ),
          ),
          // Step 2: Deck name.
          Step(
            title: const Text('Deck name'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Farsi → English',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Step 3: Icon & color.
          Step(
            title: const Text('Customize'),
            isActive: _currentStep >= 3,
            content: _buildCustomizeStep(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomizeStep(ColorScheme cs) {
    final selectedColor = Color(_deckColors[_selectedColorIndex]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(_deckColors.length, (i) {
            final selected = i == _selectedColorIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedColorIndex = i),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(_deckColors[i]),
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: cs.onSurface, width: 3)
                      : null,
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Text('Icon',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_deckIcons.length, (i) {
            final selected = i == _selectedIconIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedIconIndex = i),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? selectedColor : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _deckIcons[i],
                  color: selected ? Colors.white : cs.onSurfaceVariant,
                  size: 24,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        _buildPreviewCard(selectedColor),
      ],
    );
  }

  Widget _buildPreviewCard(Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.white, 0.3)!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(_deckIcons[_selectedIconIndex], color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _nameController.text.isEmpty ? 'Preview' : _nameController.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguagePicker({
    required _Language? selected,
    _Language? exclude,
    required ValueChanged<_Language> onSelect,
  }) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _languages.where((l) => l != exclude).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered.map((lang) {
        final isSelected = lang == selected;
        return ChoiceChip(
          label: Text('${lang.emoji}  ${lang.name}'),
          selected: isSelected,
          onSelected: (_) => onSelect(lang),
          selectedColor: cs.primaryContainer,
          labelStyle: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        );
      }).toList(),
    );
  }
}

class _Language {
  final String code;
  final String name;
  final String emoji;
  const _Language(this.code, this.name, this.emoji);
}
