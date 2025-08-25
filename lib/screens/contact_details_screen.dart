import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/contact.dart';
import '../services/contact_database.dart';

class ContactDetailsScreen extends StatefulWidget {
  final Contact contact;
  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  bool _isEditing = false;
  late Contact _contact;
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

  void _loadFromContact() {
    final c = _contact;
    _nameController.text = c.name;
    if (c.birthDate != null) {
      _birthDate = c.birthDate;
      _birthController.text = DateFormat('dd.MM.yyyy').format(c.birthDate!);
    } else if (c.ageManual != null) {
      _ageManual = c.ageManual;
      _birthController.text = c.ageManual.toString();
    }
    _professionController.text = c.profession ?? '';
    _cityController.text = c.city ?? '';
    _phoneController.text = c.phone;
    _emailController.text = c.email ?? '';
    _socialType = c.social;
    _socialController.text = c.social ?? '';
    _category = c.category;
    _categoryController.text = c.category;
    _status = c.status;
    _statusController.text = c.status;
    _tags..clear()..addAll(c.tags);
    _commentController.text = c.comment ?? '';
    _addedDate = c.createdAt;
    _addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);
  }

  void _hintSelectCategory() async {
    await _ensureVisible(_categoryKey);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сначала выберите категорию')),
    );
    FocusScope.of(context).requestFocus(_focusCategory);
  }

  // ====== Состояния ======
  DateTime? _birthDate;
  int? _ageManual;
  String? _socialType;
  String? _category;
  String? _status;
  DateTime _addedDate = DateTime.now();
  final Set<String> _tags = {};

  bool _birthOpen = false;
  bool _socialOpen = false;
  bool _categoryOpen = false;
  bool _statusOpen = false;
  bool _addedOpen = false;

  bool _extraExpanded = false; // «Дополнительно» изначально свёрнут

  // FocusNodes — чтобы переводить фокус на «тайловые» поля
  final FocusNode _focusBirth = FocusNode(skipTraversal: true);
  final FocusNode _focusSocial = FocusNode(skipTraversal: true);
  final FocusNode _focusCategory = FocusNode(skipTraversal: true);
  final FocusNode _focusStatus = FocusNode(skipTraversal: true);
  final FocusNode _focusAdded = FocusNode(skipTraversal: true);

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // ===== Брендовые иконки (из папки assets/) =====
  // соответствие названия в UI -> имя файла (без .svg)
  static const Map<String, String> _brandSlug = {
    'Telegram': 'telegram',
    'VK': 'vk',
    'Instagram': 'instagram',
    'WhatsApp': 'whatsapp',
    'TikTok': 'tiktok',
    'Одноклассники': 'odnoklassniki',
    'Facebook': 'facebook',
    'Twitter': 'twitterx',
    'X': 'twitterx',
  };

  String _brandAssetPath(String value) {
    final slug = _brandSlug[value];
    if (slug == null) return '';
    // сейчас используем одну версию (без -night)
    return 'assets/$slug.svg';
  }

  Widget _brandIcon(String value, {double size = 24}) {
    final path = _brandAssetPath(value);
    if (path.isEmpty) return const Icon(Icons.public);
    return SvgPicture.asset(path, width: size, height: size, semanticsLabel: value);
  }

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _loadFromContact();

    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _professionController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _commentController.addListener(() => setState(() {}));
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

    _focusBirth.dispose();
    _focusSocial.dispose();
    _focusCategory.dispose();
    _focusStatus.dispose();
    _focusAdded.dispose();
    super.dispose();
  }

  // ==================== helpers ====================

  void _defocus() => FocusScope.of(context).unfocus();

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
    final parts =
    name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() +
        parts[1].characters.take(1).toString())
        .toUpperCase();
  }

  Future<void> _ensureVisible(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
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
    FocusScope.of(context).requestFocus(_focusBirth);
    setState(() => _birthOpen = true);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Выбрать дату рождения'),
              dense: true,
              onTap: () => Navigator.pop(context, 'date'),
            ),
            ListTile(
              leading: const Icon(Icons.numbers),
              title: const Text('Указать возраст'),
              dense: true,
              onTap: () => Navigator.pop(context, 'age'),
            ),
          ],
        ),
      ),
    );
    setState(() => _birthOpen = false);

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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            FilledButton(
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
        setState(() {});
      }
    }
  }

  // Bottom sheet соцсетей — иконки через SVG ассеты (БЕЗ пункта «Другая»)
  Future<void> _pickSocial() async {
    FocusScope.of(context).requestFocus(_focusSocial);
    setState(() => _socialOpen = true);

    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxH = MediaQuery.of(context).size.height * 0.8;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: _brandIcon('Telegram'),
                    title: const Text('Telegram'),
                    onTap: () => Navigator.pop(context, 'Telegram'),
                  ),
                  ListTile(
                    leading: _brandIcon('VK'),
                    title: const Text('VK'),
                    onTap: () => Navigator.pop(context, 'VK'),
                  ),
                  ListTile(
                    leading: _brandIcon('Instagram'),
                    title: const Text('Instagram'),
                    onTap: () => Navigator.pop(context, 'Instagram'),
                  ),
                  ListTile(
                    leading: _brandIcon('Facebook'),
                    title: const Text('Facebook'),
                    onTap: () => Navigator.pop(context, 'Facebook'),
                  ),
                  ListTile(
                    leading: _brandIcon('WhatsApp'),
                    title: const Text('WhatsApp'),
                    onTap: () => Navigator.pop(context, 'WhatsApp'),
                  ),
                  ListTile(
                    leading: _brandIcon('TikTok'),
                    title: const Text('TikTok'),
                    onTap: () => Navigator.pop(context, 'TikTok'),
                  ),
                  ListTile(
                    leading: _brandIcon('Одноклассники'),
                    title: const Text('Одноклассники'),
                    onTap: () => Navigator.pop(context, 'Одноклассники'),
                  ),
                  ListTile(
                    leading: _brandIcon('Twitter'),
                    title: const Text('Twitter'),
                    onTap: () => Navigator.pop(context, 'Twitter'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    setState(() => _socialOpen = false);

    if (result == null) return;

    // просто устанавливаем выбранное значение (варианта «Другая» больше нет)
    _socialType = result;
    _socialController.text = result;
    setState(() {});
  }

  Future<void> _pickCategory() async {
    FocusScope.of(context).requestFocus(_focusCategory);
    setState(() => _categoryOpen = true);
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
    setState(() => _categoryOpen = false);

    if (result != null) {
      setState(() {
        _category = result;
        _status = null;
        _categoryController.text = result;
        _statusController.text = '';
      });
      await _ensureVisible(_statusKey);
    }
  }

  Future<void> _pickStatus() async {
    if (_category == null) return;

    FocusScope.of(context).requestFocus(_focusStatus);

    final map = {
      'Партнёр': ['Активный', 'Пассивный', 'Потерянный'],
      'Клиент': ['Активный', 'Пассивный', 'Потерянный'],
      'Потенциальный': ['Холодный', 'Тёплый', 'Потерянный'],
    };
    final options = map[_category]!;
    setState(() => _statusOpen = true);
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
    setState(() => _statusOpen = false);

    if (result != null) {
      setState(() {
        _status = result;
        _statusController.text = result;
      });
    }
  }

  Future<void> _pickAddedDate() async {
    FocusScope.of(context).requestFocus(_focusAdded);
    setState(() => _addedOpen = true);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: _addedDate,
      locale: const Locale('ru'),
    );
    setState(() => _addedOpen = false);

    if (picked != null) {
      setState(() {
        _addedDate = picked;
        _addedController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
    }
  }

  // ==================== save ====================

  Future<void> _save() async {
    _defocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
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

    final updated = Contact(
      id: _contact.id,
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      ageManual: _ageManual,
      profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      social: _socialType,
      category: _category!,
      status: _status!,
      tags: _tags.toList(),
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      createdAt: _addedDate,
    );

    await ContactDatabase.instance.update(updated);
    if (!mounted) return;
    setState(() {
      _contact = updated;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Изменения сохранены')),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контакт?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ContactDatabase.instance.delete(_contact.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ==================== UI helpers ====================

  InputDecoration _outlinedDec(
      ThemeData theme, {
        required String label,
        IconData? prefixIcon,
        String? hint,
        required TextEditingController controller,
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
        tooltip: 'Очистить',
        icon: const Icon(Icons.close),
        onPressed: () {
          controller.clear();
          setState(() {}); // обновить видимость и валидность
        },
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      filled: false,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  // Обёртка с бордером и клипом для picker-полей — чтобы риппл не выходил за скругления
  Widget _borderedTile({required Widget child}) {
    final theme = Theme.of(context);
    final shape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Material(
      type: MaterialType.card,
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  // Сворачиваемый блок
  Widget _collapsibleSectionCard({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          onExpansionChanged: onChanged,
          maintainState: true,
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _pickerTile({
    required Key key,
    required IconData icon,
    required String title,
    required String? value,
    String? hint,
    required bool isOpen,
    required FocusNode focusNode,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final hasValue = (value ?? '').isNotEmpty;

    return Focus(
      focusNode: focusNode,
      canRequestFocus: true,
      child: _borderedTile(
        child: ListTile(
          key: key,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(icon),
          title: Text(title),
          subtitle: hasValue
              ? Text(value!)
              : (hint != null
              ? Text(hint, style: TextStyle(color: theme.hintColor))
              : null),
          trailing: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
          onTap: () {
            FocusScope.of(context).requestFocus(focusNode);
            onTap();
          },
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // Плитка «Соцсеть» — отдельная, чтобы показывать SVG leading
  Widget _socialPickerTile() {
    final theme = Theme.of(context);
    final value = _socialController.text;
    final hasValue = value.isNotEmpty;
    final t = (_socialType ?? value).trim();

    return Focus(
      focusNode: _focusSocial,
      canRequestFocus: true,
      child: _borderedTile(
        child: ListTile(
          key: const ValueKey('social'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: t.isEmpty ? const Icon(Icons.public) : _brandIcon(t),
          title: const Text('Соцсеть'),
          subtitle: hasValue
              ? Text(value)
              : Text('Выбрать соцсеть',
              style: TextStyle(color: theme.hintColor)),
          trailing: Icon(_socialOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
          onTap: () {
            if (!_isEditing) return;
            FocusScope.of(context).requestFocus(_focusSocial);
            _pickSocial();
          },
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(_nameController.text);

    Widget tagChip(String label) {
      final selected = _tags.contains(label);
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: _isEditing ? (v) {
          setState(() {
            if (v) {
              _tags.add(label);
            } else {
              _tags.remove(label);
            }
          });
        } : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: _isEditing ? TextButton(onPressed: () { setState(() { _isEditing = false; _loadFromContact(); }); }, child: const Text('Отмена')) : const BackButton(),
        title: Text(_isEditing ? 'Редактирование' : 'Детали контакта'),
        actions: [_isEditing ? TextButton(onPressed: _canSave ? _save : null, child: const Text('Сохранить')) : TextButton(onPressed: () => setState(() { _isEditing = true; }), child: const Text('Редактировать'))],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              // ===== Блок: Заголовок =====
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        child: Text(
                          initials.isEmpty ? '👤' : initials,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
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

              const SizedBox(height: 24),

              // ===== Блок: Основное =====
              _sectionCard(
                title: 'Основное',
                children: [
                  // ФИО
                  KeyedSubtree(
                    key: _nameKey,
                    child: TextFormField(
                      enabled: _isEditing,
                      controller: _nameController,
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      decoration: _outlinedDec(
                        theme,
                        label: 'ФИО*',
                        prefixIcon: Icons.person_outline,
                        controller: _nameController,
                      ),
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Введите ФИО' : null,
                      onTapOutside: (_) => _defocus(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Телефон
                  KeyedSubtree(
                    key: _phoneKey,
                    child: TextFormField(
                      enabled: _isEditing,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [_phoneMask],
                      decoration: _outlinedDec(
                        theme,
                        label: 'Телефон*',
                        prefixIcon: Icons.phone_outlined,
                        controller: _phoneController,
                      ),
                      validator: (v) => _phoneValid ? null : 'Введите телефон',
                      onTapOutside: (_) => _defocus(),
                    ),
                  ),
                ],
              ),

              // ===== Блок: Категория и статус =====
              _sectionCard(
                title: 'Категория и статус',
                children: [
                  _pickerTile(
                    key: _categoryKey,
                    icon: Icons.person_outline, // «человечек» как категория
                    title: 'Категория*',
                    value: _categoryController.text,
                    hint: 'Выберите категорию',
                    isOpen: _categoryOpen,
                    focusNode: _focusCategory,
                    onTap: _isEditing ? _pickCategory : null,
                  ),
                  const SizedBox(height: 12),
                  _pickerTile(
                    key: _statusKey,
                    icon: Icons.how_to_reg,
                    title: 'Статус*',
                    value: _statusController.text,
                    hint: _category == null ? 'Сначала выберите категорию' : 'Выберите статус',
                    isOpen: _statusOpen,
                    focusNode: _focusStatus,
                    onTap: () {
                    if (!_isEditing) return;
                    if (_category != null) {
                      _pickStatus();
                    } else {
                      _hintSelectCategory();
                    }
                  },
                  ),
                ],
              ),

              // ===== Блок: Теги =====
              _sectionCard(
                title: 'Теги',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      tagChip('Новый'),
                      tagChip('Напомнить'),
                      tagChip('VIP'),
                    ],
                  ),
                ],
              ),

              // ===== Блок: Дополнительно (сворачиваемый) — ПОД тегами =====
              _collapsibleSectionCard(
                title: 'Дополнительно',
                expanded: _extraExpanded,
                onChanged: (v) => setState(() => _extraExpanded = v),
                children: [
                  _pickerTile(
                    key: const ValueKey('birth'),
                    icon: Icons.cake_outlined,
                    title: 'Дата рождения / возраст',
                    value: _birthController.text,
                    hint: 'Указать дату или возраст',
                    isOpen: _birthOpen,
                    focusNode: _focusBirth,
                    onTap: _isEditing ? _pickBirthOrAge : null,
                  ),
                  const SizedBox(height: 12),

                  // Email — здесь
                  TextFormField(
                      enabled: _isEditing,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _outlinedDec(
                      theme,
                      label: 'Email',
                      prefixIcon: Icons.alternate_email_outlined,
                      controller: _emailController,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final regex = RegExp(r'.+@.+[.].+');
                      return regex.hasMatch(v) ? null : 'Некорректный email';
                    },
                    onTapOutside: (_) => _defocus(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                      enabled: _isEditing,
                    controller: _professionController,
                    textInputAction: TextInputAction.next,
                    decoration: _outlinedDec(
                      theme,
                      label: 'Профессия',
                      prefixIcon: Icons.work_outline,
                      controller: _professionController,
                    ),
                    onTapOutside: (_) => _defocus(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                      enabled: _isEditing,
                    controller: _cityController,
                    textInputAction: TextInputAction.next,
                    decoration: _outlinedDec(
                      theme,
                      label: 'Город проживания',
                      prefixIcon: Icons.location_city_outlined,
                      controller: _cityController,
                    ),
                    onTapOutside: (_) => _defocus(),
                  ),
                  const SizedBox(height: 12),

                  // Соцсеть — отдельная плитка с SVG leading
                  _socialPickerTile(),
                ],
              ),

              // ===== Блок: Заметки =====
              _sectionCard(
                title: 'Заметки',
                children: [
                  Card(
                    elevation: 0,
                    child: ListTile(title: Text('Нет заметок')),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(onPressed: () {}, child: const Text('Добавить заметку')),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () {}, child: const Text('Все заметки')),
                    ],
                  ),
                ],
              ),

              // ===== Блок: Комментарий =====
              _sectionCard(
                title: 'Комментарий',
                children: [
                  TextFormField(
                      enabled: _isEditing,
                    controller: _commentController,
                    maxLines: 1,
                    decoration: _outlinedDec(
                      theme,
                      label: 'Комментарий',
                      prefixIcon: Icons.notes_outlined,
                      controller: _commentController,
                    ),
                    onTapOutside: (_) => _defocus(),
                  ),
                ],
              ),

              // ===== Блок: Дата добавления =====
              _sectionCard(
                title: 'Дата добавления',
                children: [
                  _pickerTile(
                    key: const ValueKey('added'),
                    icon: Icons.event_outlined,
                    title: 'Дата добавления',
                    value: _addedController.text,
                    isOpen: _addedOpen,
                    focusNode: _focusAdded,
                    onTap: _isEditing ? _pickAddedDate : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заметки добавляются на экране Деталей контакта',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: !_isEditing ? Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _delete,
          child: const Text('Удалить контакт'),
        ),
      ) : null,
    );
  }
}

// ===== вспомогательные виджеты/расширения =====

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PickerTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.pop(context, value),
    );
  }
}