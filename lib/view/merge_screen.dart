import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/card_entity.dart';
import 'package:leitner_cards/entity/deck_entity.dart';
import 'package:leitner_cards/entity/progress_entity.dart';
import 'package:leitner_cards/enums/group_code.dart';
import 'package:leitner_cards/repository/progress_repository.dart';
import 'package:leitner_cards/util/date_time_util.dart';
import 'package:timezone/timezone.dart' as tz;
import '../service/sync_service.dart';
import '../util/dialog_util.dart';

/// Edit form for an existing [CardEntity].
///
/// All text fields are pre-populated from the card passed via route arguments.
/// Saving always resets [level] and [subLevel] to their initial values so the
/// edited card re-enters the Leitner queue from the beginning. Read-only
/// metadata (dates, order, level) is shown in a summary chip panel rather than
/// editable fields to prevent accidental corruption.
///
/// Accepts an optional [DeckEntity] for user-created decks. When provided,
/// colors and language fields are derived from the deck entity.
class MergeScreen extends StatefulWidget {
  final CardEntity cardEntity;
  final DeckEntity? deck;

  const MergeScreen({super.key, required this.cardEntity, this.deck});

  @override
  _MergeScreenState createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final SyncService _syncService = Get.find<SyncService>();
  final ProgressRepository _progressRepository = Get.find<ProgressRepository>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final tz.TZDateTime _created;
  late final TextEditingController _faController;
  late final TextEditingController _enController;
  late final TextEditingController _deController;
  late final TextEditingController _descController;
  late final TextEditingController _orderController;
  late final TextEditingController _levelController;
  late final TextEditingController _subLevelController;
  late final TextEditingController _createdController;
  late final TextEditingController _modifiedController;
  late final GroupCode? _groupCode;

  String get _sourceLang =>
      widget.deck?.sourceLang ?? (_groupCode == GroupCode.faEn ? 'fa' : 'en');
  String get _targetLang =>
      widget.deck?.targetLang ?? (_groupCode == GroupCode.faEn ? 'en' : 'de');

  bool get _showFa => _sourceLang == 'fa' || _targetLang == 'fa';
  bool get _showEn => _sourceLang == 'en' || _targetLang == 'en';
  bool get _showDe => _sourceLang == 'de' || _targetLang == 'de';

  Color get _accentColor => widget.deck != null
      ? Color(widget.deck!.colorValue)
      : (_groupCode == GroupCode.faEn
          ? Colors.blue.shade600
          : Colors.orange.shade700);

  List<Color> get _gradient => [
        _accentColor,
        Color.lerp(_accentColor, Colors.white, 0.3) ?? _accentColor,
      ];

  String get _headerTitle =>
      widget.deck?.name ?? _groupCode?.title ?? 'Edit Card';

  @override
  void initState() {
    super.initState();
    final card = widget.cardEntity;
    final progress = _progressRepository.findOrCreate(card.id);
    _idController = TextEditingController(text: card.id.toString());
    _created = card.created;
    _faController = TextEditingController(text: card.fa);
    _enController = TextEditingController(text: card.en);
    _deController = TextEditingController(text: card.de);
    _descController = TextEditingController(text: card.desc);
    _orderController = TextEditingController(text: progress.order.toString());
    _levelController = TextEditingController(text: progress.level.toString());
    _subLevelController =
        TextEditingController(text: progress.subLevel.toString());
    _createdController =
        TextEditingController(text: DateTimeUtil.adjustDateTime(card.created));
    _modifiedController = TextEditingController(
        text: DateTimeUtil.adjustDateTime(progress.modified));
    _groupCode = GroupCode.tryFromCode(card.groupCode);
  }

  @override
  void dispose() {
    _idController.dispose();
    _faController.dispose();
    _enController.dispose();
    _deController.dispose();
    _descController.dispose();
    _orderController.dispose();
    _levelController.dispose();
    _subLevelController.dispose();
    _createdController.dispose();
    _modifiedController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;

  /// Resolves the groupCode to store on the card.
  String get _cardGroupCode {
    if (widget.deck != null) {
      final d = widget.deck!;
      return d.groupCode.isNotEmpty ? d.groupCode : d.id;
    }
    return widget.cardEntity.groupCode;
  }

  void _onDelete() {
    final label = widget.cardEntity.en.isNotEmpty
        ? widget.cardEntity.en
        : widget.cardEntity.fa;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Delete "$label"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _syncService.removeCard(widget.cardEntity,
                    withProgress: true);
              } catch (e) {
                if (mounted) DialogUtil.error(context, e);
                return;
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _onMerge() async {
    if (_formKey.currentState!.validate()) {
      try {
        final cardId = int.parse(_idController.text);
        await _syncService.saveCard(CardEntity(
          id: cardId,
          created: _created,
          modified: DateTimeUtil.now(),
          groupCode: _cardGroupCode,
          fa: _faController.text.trim(),
          en: _enController.text.trim(),
          de: _deController.text.trim(),
          desc: _descController.text.trim(),
        ));
        // Reset progress when editing card content
        final progress = _progressRepository.findOrCreate(cardId);
        progress.level = ProgressEntity.initLevel;
        progress.subLevel = ProgressEntity.initSubLevel;
        progress.modified = DateTimeUtil.now();
        await _progressRepository.merge(progress);
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
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        textDirection: textDirection,
        validator: validator,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        style: readOnly
            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: readOnly ? Colors.grey : _accentColor),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _accentColor, width: 2),
          ),
          filled: readOnly,
          fillColor: readOnly
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
        ),
      ),
    );
  }

  Widget _buildMetadataSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'CARD METADATA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _metaChip(
                    'Level', _levelController.text, Icons.layers_outlined),
                _metaChip('Sub-level', _subLevelController.text,
                    Icons.subdirectory_arrow_right),
                _metaChip('Order', _orderController.text, Icons.sort),
                _metaChip('Created', _createdController.text,
                    Icons.calendar_today_outlined),
                _metaChip('Modified', _modifiedController.text,
                    Icons.edit_calendar_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
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
    final flagName = _groupCode == GroupCode.faEn ? 'en' : 'de';
    return Image.asset('assets/flags/$flagName.png', width: 40, height: 40);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Card'),
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
                    Text(
                      _headerTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${_idController.text}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
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
                      hint: 'Optional hint',
                      controller: _descController,
                      icon: Icons.lightbulb_outline,
                      maxLines: 2,
                    ),
                    _buildMetadataSection(),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _onMerge,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Changes',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        label: const Text('Delete Card',
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
