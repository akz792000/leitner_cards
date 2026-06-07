import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/util/date_time_util.dart';

import '../enums/group_code.dart';
import '../service/sync_service.dart';
import '../util/dialog_util.dart';

/// Add-card form for creating a new [CardEntity] from scratch.
///
/// The id is generated as seconds-epoch so it fits within Hive's 32-bit key
/// constraint (`millisecondsSinceEpoch ~/ 1000`). Only the fields relevant to
/// the selected deck are shown (Farsi field for English deck; Deutsch for Deutsch).
class PersistScreen extends StatefulWidget {
  final GroupCode groupCode;

  const PersistScreen({super.key, required this.groupCode});

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

  bool get _isEnglish => widget.groupCode == GroupCode.english;
  Color get _accentColor => _isEnglish ? Colors.blue.shade600 : Colors.orange.shade700;
  List<Color> get _gradient => _isEnglish
      ? [const Color(0xFF1565C0), const Color(0xFF42A5F5)]
      : [const Color(0xFFE65100), const Color(0xFFFFB74D)];

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

  Future<void> _onPersist() async {
    if (_formKey.currentState!.validate()) {
      try {
        final now = DateTimeUtil.now();
        await _syncService.saveCard(CardEntity(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          created: now,
          modified: now,
          level: CardEntity.initLevel,
          subLevel: CardEntity.initSubLevel,
          order: 0,
          fa: _faController.text.trim(),
          en: _enController.text.trim(),
          de: _deController.text.trim(),
          desc: _descController.text.trim(),
          groupCode: widget.groupCode,
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
              gradient: LinearGradient(colors: _gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Image.asset('assets/flags/${_isEnglish ? 'en' : 'de'}.png', width: 40, height: 40),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.groupCode.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    const Text('New flashcard', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                    if (_isEnglish)
                      _buildField(
                        label: 'Farsi',
                        hint: 'فارسی',
                        controller: _faController,
                        icon: Icons.translate,
                        textDirection: TextDirection.rtl,
                      ),
                    _buildField(
                      label: 'English',
                      hint: 'e.g. apple',
                      controller: _enController,
                      icon: Icons.spellcheck,
                      validator: _required,
                    ),
                    if (!_isEnglish)
                      _buildField(
                        label: 'Deutsch',
                        hint: 'z.B. Apfel',
                        controller: _deController,
                        icon: Icons.translate,
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _onPersist,
                        icon: const Icon(Icons.add_card),
                        label: const Text('Add Card', style: TextStyle(fontSize: 16)),
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
