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
  final _scroll = ScrollController();

  // Keys для автоскролла к ошибкам
  final _nameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _categoryKey = GlobalKey();
  final _statusKey = GlobalKey();

  // Controllers
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

  // State
  DateTime? _birthDate;
  int? _ageManual;
  String? _socialType;
  String? _category;
  String? _status;
  DateTime _addedDate = DateTime.now();
  final Set<String> _tags = {};

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##', filter: {'#': RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _category = widget.category;
      _categoryController.text = widget.category!;
    }
    _addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);

    // обновлять кнопку «Сохранить» и аватарку по мере ввода
    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scroll.dispose();
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

  // ==================== helpers ====================

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
    if (lastTwo >= 11 && lastTwo <= 14) return '$age лет';
    if (last == 1) return '$age год';
    if (last >= 2 && last <= 4) return '$age года';
    return '$age лет';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() +
        parts[1].characters.take(1).toString()).toUpperCase();
  }

  Future<void> _ensureVisible(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
  }

  bool get _phoneValid => _phoneMask.getUnmaskedText().length == 10;
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
          _phoneValid &&
          _category != null &&
          _status != null;

  // ==================== pickers ====================

  Future<void> _pickBirthOrAge() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.cake_outlined),
              title: Text('Выбрать дату рождения'), dense: true,
            )._value('date'),
            ListTile(leading: Icon(Icons.numbers),
              title: Text('Указать возраст'), dense: true,
            )._value('age'),
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
        _birthController.text = '${DateFormat('dd.MM.yyyy').format(picked)} (${_formatAge(age)})';
        setState(() {});
      }
    } else if (choice == 'age') {
      final ctrl = TextEditingController();
      final age = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Возраст'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Количество лет',
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (age != null) {
        _ageManual = age;
        _birthDate = null;
        _birthController.text = 'Возраст: ${_formatAge(age)}';
        setState(() {});
      }
    }
  }

  Future<void> _pickSocial() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.telegram), title: Text('Telegram'))._value('Telegram'),
            ListTile(leading: Icon(Icons.groups_2_outlined), title: Text('VK'))._value('VK'),
            ListTile(leading: Icon(Icons.camera_alt_outlined), title: Text('Instagram'))._value('Instagram'),
            Divider(height: 0),
            ListTile(leading: Icon(Icons.more_horiz), title: Text('Другая'))._value('Other'),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == 'Other') {
      final ctrl = TextEditingController();
      final other = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Другая соцсеть'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Название соцсети',
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('OK')),
          ],
        ),
      );
      if (other != null && other.isNotEmpty) {
        _socialType = other;
        _socialController.text = other;
        setState(() {});
      }
    } else {
      _socialType = result;
      _socialController.text = result;
      setState(() {});
    }
  }

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _PickerTile(icon: Icons.handshake, label: 'Партнёр', value: 'Партнёр'),
            _PickerTile(icon: Icons.people, label: 'Клиент', value: 'Клиент'),
            _PickerTile(icon: Icons.person_add_alt_1, label: 'Потенциальный', value: 'Потенциальный'),
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
      await _ensureVisible(_statusKey); // удобно — сразу к выбору статуса
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
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in options)
              ListTile(
                leading: const Icon(Icons.label_outline),
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

  // ==================== save ====================

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      // прокрутка к первому потенциальному полю с ошибкой
      if (_nameController.text.trim().isEmpty) {
        await _ensureVisible(_nameKey);
        return;
      }
      if (!_phoneValid) {
        await _ensureVisible(_phoneKey);
        return;
      }
    }
    if (_category == null) {
      await _ensureVisible(_categoryKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию')),
      );
      return;
    }
    if (_status == null) {
      await _ensureVisible(_statusKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите статус')),
      );
      return;
    }

    final contact = Contact(
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      ageManual: _ageManual,
      profession: _professionController.text.trim().isEmpty
          ? null
          : _professionController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      social: _socialType,
      category: _category!,
      status: _status!,
      tags: _tags.toList(),
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      createdAt: _addedDate,
    );

    await ContactDatabase.instance.insert(contact);
    if (mounted) Navigator.pop(context, true);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(_nameController.text);

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    InputDecoration inputDec(String label, {IconData? icon, String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      );
    }

    Widget tile({
      required Key key,
      required IconData icon,
      required String title,
      String? value,
      String? hint,
      VoidCallback? onTap,
    }) {
      final hasValue = value != null && value.isNotEmpty;
      return ListTile(
        key: key,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(icon),
        title: Text(title),
        subtitle: hasValue
            ? Text(value!)
            : (hint != null ? Text(hint, style: TextStyle(color: theme.hintColor)) : null),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: theme.colorScheme.surfaceVariant,
      );
    }

    Widget tagChip(String label) {
      final selected = _tags.contains(label);
      return ChoiceChip(
        label: Text(label),
        selected: selected,
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

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Добавить контакт'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              // header с аватаром
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          initials.isEmpty ? '👤' : initials,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nameController.text.trim().isEmpty
                              ? 'Новый контакт'
                              : _nameController.text.trim(),
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              sectionTitle('Основное'),
              // ФИО
              KeyedSubtree(
                key: _nameKey,
                child: TextFormField(
                  controller: _nameController,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  decoration: inputDec('ФИО*', icon: Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Введите ФИО' : null,
                ),
              ),
              const SizedBox(height: 12),
              // Телефон
              KeyedSubtree(
                key: _phoneKey,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [_phoneMask],
                  decoration: inputDec('Телефон*', icon: Icons.phone_outlined),
                  validator: (v) => _phoneValid ? null : 'Введите телефон',
                ),
              ),
              const SizedBox(height: 12),
              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: inputDec('Email', icon: Icons.alternate_email_outlined),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final regex = RegExp(r'.+@.+[.].+');
                  return regex.hasMatch(v) ? null : 'Некорректный email';
                },
              ),

              sectionTitle('Дополнительно'),
              tile(
                key: const ValueKey('birth'),
                icon: Icons.cake_outlined,
                title: 'Дата рождения / возраст',
                value: _birthController.text,
                hint: 'Указать дату или возраст',
                onTap: _pickBirthOrAge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _professionController,
                textInputAction: TextInputAction.next,
                decoration: inputDec('Профессия', icon: Icons.work_outline),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.next,
                decoration: inputDec('Город проживания', icon: Icons.location_city_outlined),
              ),
              const SizedBox(height: 12),
              tile(
                key: const ValueKey('social'),
                icon: Icons.alternate_email,
                title: 'Соцсеть',
                value: _socialController.text,
                hint: 'Выбрать соцсеть',
                onTap: _pickSocial,
              ),

              sectionTitle('Категория и статус'),
              tile(
                key: _categoryKey,
                icon: Icons.category_outlined,
                title: 'Категория*',
                value: _categoryController.text,
                hint: 'Выберите категорию',
                onTap: _pickCategory,
              ),
              const SizedBox(height: 12),
              tile(
                key: _statusKey,
                icon: Icons.flag_outlined,
                title: 'Статус*',
                value: _statusController.text,
                hint: _category == null ? 'Сначала выберите категорию' : 'Выберите статус',
                onTap: _category != null ? _pickStatus : null,
              ),

              sectionTitle('Теги'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  tagChip('Новый'),
                  tagChip('Напомнить'),
                  tagChip('VIP'),
                ],
              ),

              sectionTitle('Комментарий'),
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                decoration: inputDec('Комментарий', icon: Icons.notes_outlined),
              ),

              sectionTitle('Служебное'),
              tile(
                key: const ValueKey('added'),
                icon: Icons.event_outlined,
                title: 'Дата добавления',
                value: _addedController.text,
                onTap: _pickAddedDate,
              ),
              const SizedBox(height: 8),
              Text(
                'Заметки добавляются на экране Деталей контакта',
                style: TextStyle(color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),

      // Кнопка снизу
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _canSave ? _save : null,
          icon: const Icon(Icons.save_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Сохранить контакт'),
          ),
        ),
      ),
    );
  }
}

// ===== вспомогательные виджеты/расширения =====

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PickerTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }
}

// Позволяет коротко указывать возвращаемое value у ListTile в bottom sheet
extension on ListTile {
  Widget _value(String v) {
    return Builder(
      builder: (context) => ListTile(
        leading: leading,
        title: title,
        dense: dense,
        onTap: () => Navigator.pop(context, v),
      ),
    );
  }
}
