import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../entity/deck_entity.dart';
import '../enums/group_code.dart';
import '../service/sync_service.dart';
import '../util/dialog_util.dart';

/// Add-card form for creating a new [CardEntity] from scratch.
///
/// The id is generated as seconds-epoch so it fits within Hive's 32-bit key
/// constraint (`millisecondsSinceEpoch ~/ 1000`). Only the fields relevant to
/// the selected deck are shown based on source/target languages.
///
/// Accepts either a [GroupCode] (legacy) or a [DeckEntity] (new decks).
/// When [deck] is provided it takes precedence — colors and language fields
/// are derived from the entity.
class PersistScreen extends StatefulWidget {
  final GroupCode? groupCode;
  final DeckEntity? deck;

  const PersistScreen({super.key, this.groupCode, this.deck})
      : assert(groupCode != null || deck != null,
            'Either groupCode or deck must be provided');

  @override
  _PersistScreenState createState() => _PersistScreenState();
}

class _PersistScreenState extends State<PersistScreen> {
  final SyncService _syncService = Get.find<SyncService>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _faController = TextEditingController();
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _deController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String get _sourceLang =>
      widget.deck?.sourceLang ??
      (widget.groupCode == GroupCode.faEn ? 'fa' : 'en');
  String get _targetLang =>
      widget.deck?.targetLang ??
      (widget.groupCode == GroupCode.faEn ? 'en' : 'de');

  bool get _showFa => _sourceLang == 'fa' || _targetLang == 'fa';
  bool get _showEn => _sourceLang == 'en' || _targetLang == 'en';
  bool get _showDe => _sourceLang == 'de' || _targetLang == 'de';

  Color get _accentColor => widget.deck != null
      ? Color(widget.deck!.colorValue)
      : (widget.groupCode == GroupCode.faEn
          ? Colors.blue.shade600
          : Colors.orange.shade700);

  List<Color> get _gradient => [
        _accentColor,
        Color.lerp(_accentColor, Colors.white, 0.3) ?? _accentColor,
      ];

  String get _headerTitle =>
      widget.deck?.name ?? widget.groupCode?.title ?? 'New Card';

  @override
  void dispose() {
    _faController.dispose();
    _enController.dispose();
    _deController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;

  /// Resolves the groupCode to store on the card.
  /// Legacy decks use the GroupCode string; user-created decks use the deck ID.
  String get _cardGroupCode {
    if (widget.deck != null) {
      final d = widget.deck!;
      return d.groupCode.isNotEmpty ? d.groupCode : d.id;
    }
    return widget.groupCode!.code;
  }

  Future<void> _onPersist() async {
    if (_formKey.currentState!.validate()) {
      try {
        final now = DateTimeUtil.now();
        await _syncService.saveCard(CardEntity(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          created: now,
          modified: now,
          groupCode: _cardGroupCode,
          fa: _faController.text.trim(),
          en: _enController.text.trim(),
          de: _deController.text.trim(),
          desc: _descController.text.trim(),
        ));
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) DialogUtil.error(context, e);
      }
    }
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextDirection? textDirection,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        textDirection: textDirection,
        validator: validator,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _accentColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accentColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    if (widget.deck != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(51),
          borderRadius: BorderRadius.circular(10),
        ),
        // ignore: non_const_argument_for_const_parameter
        child: Icon(
          IconData(widget.deck!.iconCodePoint, fontFamily: 'MaterialIcons'),
          color: Colors.white,
          size: 22,
        ),
      );
    }
    final flagName = widget.groupCode == GroupCode.faEn ? 'en' : 'de';
    return Image.asset('assets/flags/$flagName.png', width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Card'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: _gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                _buildHeaderIcon(),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_headerTitle,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    const Text('New flashcard',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_showFa)
                      _buildField(
                        label: 'Farsi',
                        hint: 'فارسی',
                        controller: _faController,
                        icon: Icons.translate,
                        textDirection: TextDirection.rtl,
                        validator: _sourceLang == 'fa' ? _required : null,
                      ),
                    if (_showEn)
                      _buildField(
                        label: 'English',
                        hint: 'e.g. apple',
                        controller: _enController,
                        icon: Icons.spellcheck,
                        validator: _required,
                      ),
                    if (_showDe)
                      _buildField(
                        label: 'Deutsch',
                        hint: 'z.B. Apfel',
                        controller: _deController,
                        icon: Icons.translate,
                        validator: _sourceLang == 'de' ? _required : null,
                      ),
                    _buildField(
                      label: 'Description',
                      hint: 'Optional hint shown during study',
                      controller: _descController,
                      icon: Icons.lightbulb_outline,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _onPersist,
                        icon: const Icon(Icons.add_card),
                        label: const Text('Add Card',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
