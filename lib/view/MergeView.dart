import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';
import 'package:timezone/timezone.dart' as tz;
import '../service/SyncService.dart';
import '../util/DialogUtil.dart';

class MergeView extends StatefulWidget {
  final CardEntity cardEntity;

  const MergeView({super.key, required this.cardEntity});

  @override
  _MergeViewState createState() => _MergeViewState();
}

class _MergeViewState extends State<MergeView> {
  final SyncService _syncService = Get.find<SyncService>();
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
  late final GroupCode _groupCode;

  @override
  void initState() {
    super.initState();
    final card = widget.cardEntity;
    _idController = TextEditingController(text: card.id.toString());
    _created = card.created;
    _faController = TextEditingController(text: card.fa);
    _enController = TextEditingController(text: card.en);
    _deController = TextEditingController(text: card.de);
    _descController = TextEditingController(text: card.desc);
    _orderController = TextEditingController(text: card.order.toString());
    _levelController = TextEditingController(text: card.level.toString());
    _subLevelController = TextEditingController(text: card.subLevel.toString());
    _createdController = TextEditingController(text: DateTimeUtil.adjustDateTime(card.created));
    _modifiedController = TextEditingController(text: DateTimeUtil.adjustDateTime(card.modified));
    _groupCode = card.groupCode;
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

  String? _fieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field can\'t be empty';
    }
    return null;
  }

  Future<void> _onMerge() async {
    if (_formKey.currentState!.validate()) {
      try {
        final mergedCard = CardEntity(
          id: int.parse(_idController.text),
          created: _created,
          modified: DateTimeUtil.now(),
          level: CardEntity.initLevel,
          subLevel: CardEntity.initSubLevel,
          order: int.parse(_orderController.text),
          fa: _faController.text,
          en: _enController.text,
          de: _deController.text,
          desc: _descController.text,
          groupCode: _groupCode,
        );
        await _syncService.saveCard(mergedCard);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) DialogUtil.error(context, e);
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextDirection? textDirection,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          validator: validator,
          textDirection: textDirection,
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = _groupCode == GroupCode.english;

    return Scaffold(
      appBar: AppBar(title: const Text('Merge')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (isEnglish)
                  _buildTextField(
                    label: 'Farsi',
                    controller: _faController,
                    textDirection: TextDirection.rtl,
                  ),
                _buildTextField(
                  label: 'English',
                  controller: _enController,
                  validator: _fieldValidator,
                ),
                if (!isEnglish)
                  _buildTextField(
                    label: 'Deutsch',
                    controller: _deController,
                  ),
                _buildTextField(
                  label: 'Description',
                  controller: _descController,
                ),
                _buildTextField(
                  label: 'Level',
                  controller: _levelController,
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'SubLevel',
                  controller: _subLevelController,
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'Created',
                  controller: _createdController,
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'Modified',
                  controller: _modifiedController,
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'Order',
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _fieldValidator,
                ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _onMerge,
                    child: const Text('Merge'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
