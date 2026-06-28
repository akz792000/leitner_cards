import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;

import '../entity/deck_entity.dart';
import '../repository/deck_repository.dart';
import '../service/deck_service.dart';

/// Full-page editor for a deck's name, icon, and color.
///
/// Also provides a delete option at the bottom. Navigates back on save
/// or after deletion. Reuses the same icon/color palettes as [CreateDeckScreen].
class EditDeckScreen extends StatefulWidget {
  final String deckId;

  const EditDeckScreen({super.key, required this.deckId});

  @override
  State<EditDeckScreen> createState() => _EditDeckScreenState();
}

class _EditDeckScreenState extends State<EditDeckScreen> {
  final _deckRepo = Get.find<DeckRepository>();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;

  late int _selectedColor;
  late int _selectedIcon;

  static const List<int> _deckColors = [
    0xFF1565C0,
    0xFFE65100,
    0xFF00695C,
    0xFF6A1B9A,
    0xFFC62828,
    0xFF2E7D32,
    0xFF283593,
    0xFF4E342E,
    0xFFAD1457,
    0xFF00838F,
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

  DeckEntity? get _deck => _deckRepo.findById(widget.deckId);

  @override
  void initState() {
    super.initState();
    final deck = _deck;
    _nameCtrl = TextEditingController(text: deck?.name ?? '');
    _selectedColor = deck?.colorValue ?? 0xFF1565C0;
    _selectedIcon = deck?.iconCodePoint ?? Icons.style.codePoint;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor => Color(_selectedColor);

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    final deck = _deck;
    if (deck == null) return;

    deck.name = _nameCtrl.text.trim();
    deck.iconCodePoint = _selectedIcon;
    deck.colorValue = _selectedColor;
    deck.modifiedAt = tz.TZDateTime.now(tz.local);
    await _deckRepo.merge(deck);
    if (mounted) Navigator.pop(context);
  }

  void _onDelete() {
    final deck = _deck;
    if (deck == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text(
          'Delete "${deck.name}" and all its cards and progress?\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              await Get.find<DeckService>().deleteDeckWithData(deck);
              // Pop all the way back to HomeScreen.
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    if (deck == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Deck not found')),
        body: const Center(child: Text('This deck no longer exists.')),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          deck.groupCode.isNotEmpty
              ? deck.groupCode
              : '${deck.sourceLang.toUpperCase()}_${deck.targetLang.toUpperCase()}',
        ),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field.
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Deck Name',
                  prefixIcon: Icon(Icons.title, color: _accentColor),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _accentColor, width: 2),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 28),

              // Icon picker.
              Text('Icon',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _deckIcons.map((icon) {
                  final isSelected = icon.codePoint == _selectedIcon;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = icon.codePoint),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _accentColor.withAlpha(40)
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: _accentColor, width: 2)
                            : Border.all(color: cs.outlineVariant),
                      ),
                      child: Icon(icon,
                          color:
                              isSelected ? _accentColor : cs.onSurfaceVariant,
                          size: 24),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Color picker.
              Text('Color',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _deckColors.map((c) {
                  final isSelected = c == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: Color(c).withAlpha(150),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Save button.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Changes',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),

              // Delete button.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label:
                      const Text('Delete Deck', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
