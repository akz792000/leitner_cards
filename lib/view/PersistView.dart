import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

import '../enums/GroupCode.dart';
import '../repository/CardRepository.dart';

class PersistView extends StatefulWidget {
  final GroupCode groupCode;

  const PersistView({super.key, required this.groupCode});

  @override
  _PersistViewState createState() => _PersistViewState();
}

class _PersistViewState extends State<PersistView> {
  final CardRepository _cardRepository = Get.find<CardRepository>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _faController = TextEditingController();
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _deController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _fieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field can\'t be empty';
    }
    return null;
  }

  Future<void> _onPersist() async {
    if (_formKey.currentState!.validate()) {
      final cardEntity = CardEntity(
        id: 0,
        created: DateTimeUtil.now(),
        modified: DateTimeUtil.now(),
        level: CardEntity.initLevel,
        subLevel: CardEntity.initSubLevel,
        order: 0,
        fa: _faController.text,
        en: _enController.text,
        de: _deController.text,
        desc: _descController.text,
        groupCode: widget.groupCode,
      );

      await _cardRepository.merge(cardEntity);
      Navigator.pop(context);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextDirection? textDirection,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: controller,
          textDirection: textDirection,
          validator: validator,
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persist')),
      body: Padding(
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onPersist,
                  child: const Text('Persist'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
