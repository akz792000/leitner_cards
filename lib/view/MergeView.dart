import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/enums/GroupCode.dart';
import 'package:leitner_cards/repository/CardRepository.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';
import 'package:timezone/timezone.dart' as tz;

class MergeView extends StatefulWidget {
  final CardEntity cardEntity;

  const MergeView({super.key, required this.cardEntity});

  @override
  _MergeViewState createState() => _MergeViewState();
}

class _MergeViewState extends State<MergeView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _idController;
  late final tz.TZDateTime _created;
  late final tz.TZDateTime _modified;
  late final int _level;
  late final int _subLevel;
  late final TextEditingController _faController;
  late final TextEditingController _enController;
  late final TextEditingController _deController;
  late final TextEditingController _descController;
  late final TextEditingController _orderController;
  late final GroupCode _groupCode;

  @override
  void initState() {
    super.initState();
    final card = widget.cardEntity;
    _idController = TextEditingController(text: card.id.toString());
    _created = card.created;
    _modified = card.modified;
    _level = card.level;
    _subLevel = card.subLevel;
    _faController = TextEditingController(text: card.fa);
    _enController = TextEditingController(text: card.en);
    _deController = TextEditingController(text: card.de);
    _descController = TextEditingController(text: card.desc);
    _orderController = TextEditingController(text: card.order.toString());
    _groupCode = card.groupCode;
  }

  String? _fieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field can\'t be empty';
    }
    return null;
  }

  Future<void> _onMerge() async {
    if (_formKey.currentState!.validate()) {
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
      await _cardRepository.merge(mergedCard);
      Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Merge')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                  controller: TextEditingController(text: _level.toString()),
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'SubLevel',
                  controller: TextEditingController(text: _subLevel.toString()),
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'Created',
                  controller:
                  TextEditingController(text: DateTimeUtil.adjustDateTime(_created)),
                  readOnly: true,
                ),
                _buildTextField(
                  label: 'Modified',
                  controller:
                  TextEditingController(text: DateTimeUtil.adjustDateTime(_modified)),
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
