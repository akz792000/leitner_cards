import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:leitner_cards/entity/CardEntity.dart';
import 'package:leitner_cards/util/DateTimeUtil.dart';

import '../enums/GroupCode.dart';
import '../service/SyncService.dart';
import '../util/DialogUtil.dart';

class PersistView extends StatefulWidget {
  final GroupCode groupCode;

  const PersistView({super.key, required this.groupCode});

  @override
  _PersistViewState createState() => _PersistViewState();
}

class _PersistViewState extends State<PersistView> {
  final SyncService _syncService = Get.find<SyncService>();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _faController = TextEditingController();
  final TextEditingController _enController = TextEditingController();
  final TextEditingController _deController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _faController.dispose();
    _enController.dispose();
    _deController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String? _fieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field can\'t be empty';
    }
    return null;
  }

  Future<void> _onPersist() async {
    if (_formKey.currentState!.validate()) {
      try {
        final now = DateTimeUtil.now();
        final cardEntity = CardEntity(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          created: now,
          modified: now,
          level: CardEntity.initLevel,
          subLevel: CardEntity.initSubLevel,
          order: 0,
          fa: _faController.text,
          en: _enController.text,
          de: _deController.text,
          desc: _descController.text,
          groupCode: widget.groupCode,
        );
        await _syncService.saveCard(cardEntity);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) DialogUtil.error(context, e);
      }
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
    final isEnglish = widget.groupCode == GroupCode.english;

    return Scaffold(
      appBar: AppBar(title: const Text('Persist')),
      body: SingleChildScrollView(
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
              const SizedBox(height: 8),
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
