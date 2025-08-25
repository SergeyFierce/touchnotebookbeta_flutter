import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../models/contact.dart';
import '../services/contact_database.dart';

class AddContactScreen extends StatefulWidget {
  final String? category; // preselected category (singular)

  const AddContactScreen({super.key, this.category});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _professionController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _socialController = TextEditingController();
  final _categoryController = TextEditingController();
  final _statusController = TextEditingController();
  final _commentController = TextEditingController();
  final _addedController = TextEditingController();

  DateTime? _birthDate;
  int? _ageManual;
  String? _socialType;
  String? _category;
  String? _status;
  DateTime _addedDate = DateTime.now();
  final Set<String> _tags = {};

  final _phoneMask = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##', filter: {'#': RegExp(r'[0-9]')});

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _category = widget.category;
      _categoryController.text = widget.category!;
    }
    _addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthController.dispose();
    _professionController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _socialController.dispose();
    _categoryController.dispose();
    _statusController.dispose();
    _commentController.dispose();
    _addedController.dispose();
    super.dispose();
  }

  int _calcAge(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  String _formatAge(int age) {
    final lastTwo = age % 100;
    final last = age % 10;
    String suffix;
    if (lastTwo >= 11 && lastTwo <= 14) {
      suffix = 'лет';
    } else if (last == 1) {
      suffix = 'год';
    } else if (last >= 2 && last <= 4) {
      suffix = 'года';
    } else {
      suffix = 'лет';
    }
    return '$age $suffix';
  }

  Future<void> _pickBirthOrAge() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Выбрать дату рождения'),
                  onTap: () => Navigator.pop(context, 'date'),
                ),
                ListTile(
                  title: const Text('Указать возраст'),
                  onTap: () => Navigator.pop(context, 'age'),
                ),
              ],
            ),
          ),
    );
    if (choice == 'date') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: now,
        initialDate: now,
        locale: const Locale('ru'),
      );
      if (picked != null) {
        _birthDate = picked;
        _ageManual = null;
        final age = _calcAge(picked);
        _birthController.text =
        '${DateFormat('dd.MM.yyyy').format(picked)} (${_formatAge(age)})';
      }
    } else if (choice == 'age') {
      final ctrl = TextEditingController();
      final age = await showDialog<int>(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: const Text('Возраст'),
              content: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Количество лет'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Отмена')),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context, int.tryParse(ctrl.text)),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (age != null) {
        _ageManual = age;
        _birthDate = null;
        _birthController.text = 'Возраст: ${_formatAge(age)}';
      }
    }
    setState(() {});
  }

  Future<void> _pickSocial() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Telegram'),
                  onTap: () => Navigator.pop(context, 'Telegram'),
                ),
                ListTile(
                  title: const Text('VK'),
                  onTap: () => Navigator.pop(context, 'VK'),
                ),
                ListTile(
                  title: const Text('Instagram'),
                  onTap: () => Navigator.pop(context, 'Instagram'),
                ),
                ListTile(
                  title: const Text('Другая'),
                  onTap: () => Navigator.pop(context, 'Other'),
                ),
              ],
            ),
          ),
    );
    if (result != null) {
      if (result == 'Other') {
        final ctrl = TextEditingController();
        final other = await showDialog<String>(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Другая соцсеть'),
                content: TextField(controller: ctrl),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, ctrl.text),
                      child: const Text('OK')),
                ],
              ),
        );
        if (other != null) {
          _socialType = other;
          _socialController.text = other;
        }
      } else {
        _socialType = result;
        _socialController.text = result;
      }
    }
  }

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Партнёр'),
                  onTap: () => Navigator.pop(context, 'Партнёр'),
                ),
                ListTile(
                  title: const Text('Клиент'),
                  onTap: () => Navigator.pop(context, 'Клиент'),
                ),
                ListTile(
                  title: const Text('Потенциальный'),
                  onTap: () => Navigator.pop(context, 'Потенциальный'),
                ),
              ],
            ),
          ),
    );
    if (result != null) {
      setState(() {
        _category = result;
        _status = null;
        _categoryController.text = result;
        _statusController.text = '';
      });
    }
  }

  Future<void> _pickStatus() async {
    if (_category == null) return;
    final map = {
      'Партнёр': ['Активный', 'Пассивный', 'Потерянный'],
      'Клиент': ['Активный', 'Пассивный', 'Потерянный'],
      'Потенциальный': ['Холодный', 'Тёплый', 'Потерянный'],
    };
    final options = map[_category]!;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) =>
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in options)
                  ListTile(
                    title: Text(s),
                    onTap: () => Navigator.pop(context, s),
                  ),
              ],
            ),
          ),
    );
    if (result != null) {
      setState(() {
        _status = result;
        _statusController.text = result;
      });
    }
  }

  Future<void> _pickAddedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: _addedDate,
      locale: const Locale('ru'),
    );
    if (picked != null) {
      setState(() {
        _addedDate = picked;
        _addedController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  Widget _tagChip(String label, Color color, Color textColor) {
    final selected = _tags.contains(label);
    return FilterChip(
      label: Text(label),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(color: textColor),
      onSelected: (v) {
        setState(() {
          if (v) {
            _tags.add(label);
          } else {
            _tags.remove(label);
          }
        });
      },
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_category == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Выберите категорию')));
      return;
    }
    if (_status == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Выберите статус')));
      return;
    }
    final contact = Contact(
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      ageManual: _ageManual,
      profession: _professionController.text
          .trim()
          .isEmpty
          ? null
          : _professionController.text.trim(),
      city: _cityController.text
          .trim()
          .isEmpty
          ? null
          : _cityController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text
          .trim()
          .isEmpty
          ? null
          : _emailController.text.trim(),
      social: _socialType,
      category: _category!,
      status: _status!,
      tags: _tags.toList(),
      comment: _commentController.text
          .trim()
          .isEmpty
          ? null
          : _commentController.text.trim(),
      createdAt: _addedDate,
    );
    await ContactDatabase.instance.insert(contact);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Добавить контакт'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ФИО*'),
              validator: (v) =>
              v == null || v
                  .trim()
                  .isEmpty ? 'Введите ФИО' : null,
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _birthController,
              decoration:
              const InputDecoration(labelText: 'Дата рождения / Возраст'),
              readOnly: true,
              onTap: _pickBirthOrAge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _professionController,
              decoration: const InputDecoration(labelText: 'Профессия'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration:
              const InputDecoration(labelText: 'Город проживания'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Телефон*'),
              keyboardType: TextInputType.phone,
              inputFormatters: [_phoneMask],
              validator: (v) =>
              _phoneMask
                  .getUnmaskedText()
                  .length == 10
                  ? null
                  : 'Введите телефон',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final regex = RegExp('.+@.+[.].+');
                return regex.hasMatch(v) ? null : 'Некорректный email';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _socialController,
              decoration: const InputDecoration(labelText: 'Соцсеть'),
              readOnly: true,
              onTap: _pickSocial,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Категория*',
                helperText: 'Категория определяет доступные статусы',
                hintText: 'Выберите категорию',
              ),
              readOnly: true,
              onTap: _pickCategory,
              validator: (v) =>
              v == null || v.isEmpty ? 'Выберите категорию' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _statusController,
              decoration: InputDecoration(
                labelText: 'Статус*',
                helperText: _category == null
                    ? 'Сначала выберите категорию'
                    : 'Статусы зависят от категории',
                hintText:
                _category == null ? 'Недоступно' : 'Выберите статус',
              ),
              readOnly: true,
              enabled: _category != null,
              onTap: _category != null ? _pickStatus : null,
              validator: (v) =>
              v == null || v.isEmpty ? 'Выберите статус' : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _tagChip('Новый', Colors.white, Colors.black),
                _tagChip('Напомнить', Colors.purple, Colors.white),
                _tagChip('VIP', Colors.yellow, Colors.black),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(labelText: 'Комментарий'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addedController,
              decoration:
              const InputDecoration(labelText: 'Дата добавления'),
              readOnly: true,
              onTap: _pickAddedDate,
            ),
            const SizedBox(height: 16),
            const Text(
              'Заметки добавляются на экране Деталей контакта',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
