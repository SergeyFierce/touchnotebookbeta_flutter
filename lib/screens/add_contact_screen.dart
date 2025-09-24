library add_contact_screen;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';

import '../models/contact.dart';
import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';

part 'add_contact/add_contact_controller.dart';
part 'add_contact/add_contact_preview.dart';

/// Словари (централизовано, без «магических» строк)
abstract class Dict {
  static const categories = ['Партнёр', 'Клиент', 'Потенциальный'];

  static const statusesByCategory = {
    'Партнёр': ['Активный', 'Пассивный', 'Потерянный'],
    'Клиент': ['Активный', 'Пассивный', 'Потерянный'],
    'Потенциальный': ['Холодный', 'Тёплый', 'Потерянный'],
  };

  static const tags = ['Новый', 'Напомнить', 'VIP'];
}

class AddContactScreen extends StatefulWidget {
  final String? category; // preselected category (singular)
  const AddContactScreen({super.key, this.category});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  late final AddContactFormController _form;

  GlobalKey<FormState> get _formKey => _form.formKey;
  ScrollController get _scroll => _form.scrollController;

  GlobalKey get _nameKey => _form.nameKey;
  GlobalKey get _phoneKey => _form.phoneKey;
  GlobalKey get _categoryKey => _form.categoryKey;
  GlobalKey get _statusKey => _form.statusKey;
  GlobalKey get _addedKey => _form.addedKey;
  GlobalKey get _extraCardKey => _form.extraCardKey;

  TextEditingController get _nameController => _form.nameController;
  TextEditingController get _birthController => _form.birthController;
  TextEditingController get _professionController => _form.professionController;
  TextEditingController get _cityController => _form.cityController;
  TextEditingController get _phoneController => _form.phoneController;
  TextEditingController get _emailController => _form.emailController;
  TextEditingController get _socialController => _form.socialController;
  TextEditingController get _categoryController => _form.categoryController;
  TextEditingController get _statusController => _form.statusController;
  TextEditingController get _commentController => _form.commentController;
  TextEditingController get _addedController => _form.addedController;

  bool get _submitted => _form.submitted;
  set _submitted(bool value) => _form.setSubmitted(value);

  bool get _saving => _form.saving;
  set _saving(bool value) => _form.setSaving(value);

  DateTime? get _birthDate => _form.birthDate;
  set _birthDate(DateTime? value) => _form.setBirthDate(value);

  int? get _ageManual => _form.ageManual;
  set _ageManual(int? value) => _form.setAgeManual(value);

  String? get _category => _form.category;
  set _category(String? value) => _form.setCategory(value);

  String? get _status => _form.status;
  set _status(String? value) => _form.setStatus(value);

  DateTime get _addedDate => _form.addedDate;
  set _addedDate(DateTime value) => _form.updateAddedDate(value);

  Set<String> get _tags => _form.tags;

  bool get _birthOpen => _form.birthOpen;
  set _birthOpen(bool value) => _form.setBirthOpen(value);

  bool get _socialOpen => _form.socialOpen;
  set _socialOpen(bool value) => _form.setSocialOpen(value);

  bool get _categoryOpen => _form.categoryOpen;
  set _categoryOpen(bool value) => _form.setCategoryOpen(value);

  bool get _statusOpen => _form.statusOpen;
  set _statusOpen(bool value) => _form.setStatusOpen(value);

  bool get _addedOpen => _form.addedOpen;
  set _addedOpen(bool value) => _form.setAddedOpen(value);

  bool get _extraExpanded => _form.extraExpanded;
  set _extraExpanded(bool value) => _form.setExtraExpanded(value);

  FocusNode get _focusBirth => _form.focusBirth;
  FocusNode get _focusSocial => _form.focusSocial;
  FocusNode get _focusCategory => _form.focusCategory;
  FocusNode get _focusStatus => _form.focusStatus;
  FocusNode get _focusAdded => _form.focusAdded;

  MaskTextInputFormatter get _phoneMask => _form.phoneMask;

  Future<void> _scrollToCard(GlobalKey key) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment: 0.0,
      );
    });
  }

  void _hintSelectCategory() async {
    setState(() => _submitted = true);
    await _ensureVisible(_categoryKey);
    FocusScope.of(context).requestFocus(_focusCategory);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _form = AddContactFormController(initialCategory: widget.category)
      ..addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _form.removeListener(_onFormChanged);
    _form.dispose();
    super.dispose();
  }

  // ==================== helpers ====================
  void _defocus() => FocusScope.of(context).unfocus();

  Future<void> _ensureVisible(GlobalKey key) => _form.scrollToCard(key);

  bool get _phoneValid => _form.phoneValid;

  bool get _canSave => _form.canSave;

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
        helpText: 'Дата рождения',
        cancelText: 'Отмена',
        confirmText: 'Выбрать',
      );
      if (picked != null) {
        setState(() {
          _birthDate = picked;
          _ageManual = null;
        });
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
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (age != null) {
        setState(() {
          _ageManual = age;
          _birthDate = null;
        });
      }
    }
  }

  // Bottom sheet соцсетей — иконки через SVG ассеты
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
                  ListTile(leading: _form.brandIcon('Telegram'), title: const Text('Telegram'), onTap: () => Navigator.pop(context, 'Telegram')),
                  ListTile(leading: _form.brandIcon('VK'), title: const Text('VK'), onTap: () => Navigator.pop(context, 'VK')),
                  ListTile(leading: _form.brandIcon('Instagram'), title: const Text('Instagram'), onTap: () => Navigator.pop(context, 'Instagram')),
                  ListTile(leading: _form.brandIcon('Facebook'), title: const Text('Facebook'), onTap: () => Navigator.pop(context, 'Facebook')),
                  ListTile(leading: _form.brandIcon('WhatsApp'), title: const Text('WhatsApp'), onTap: () => Navigator.pop(context, 'WhatsApp')),
                  ListTile(leading: _form.brandIcon('TikTok'), title: const Text('TikTok'), onTap: () => Navigator.pop(context, 'TikTok')),
                  ListTile(leading: _form.brandIcon('Одноклассники'), title: const Text('Одноклассники'), onTap: () => Navigator.pop(context, 'Одноклассники')),
                  ListTile(leading: _form.brandIcon('Twitter'), title: const Text('Twitter'), onTap: () => Navigator.pop(context, 'Twitter')),
                ],
              ),
            ),
          ),
        );
      },
    );

    setState(() => _socialOpen = false);
    if (result == null) return;
    _socialController.text = result;
    setState(() {});
  }

  Future<void> _pickCategory() async {
    FocusScope.of(context).requestFocus(_focusCategory);
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() => _categoryOpen = true);
    await Future.delayed(const Duration(milliseconds: 50));

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
      });
    }
  }

  Future<void> _pickStatus() async {
    if (_category == null) return;
    FocusScope.of(context).requestFocus(_focusStatus);
    final options = Dict.statusesByCategory[_category]!;
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
                leading: Icon(_form.statusIcon(s)),
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
      helpText: 'Дата добавления',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    setState(() => _addedOpen = false);
    if (picked != null) {
      setState(() => _addedDate = picked);
    }
  }

  // ==================== save ====================
  Future<void> _save() async {
    _defocus();
    setState(() => _submitted = true);

    // Мгновенно подсказать, что не так, и проскроллить к первой ошибке
    if (_nameController.text.trim().isEmpty) {
      await _ensureVisible(_nameKey);
      return;
    }
    if (!_phoneValid) {
      await _ensureVisible(_phoneKey);
      return;
    }
    if (_category == null || _categoryController.text.trim().isEmpty) {
      await _ensureVisible(_categoryKey);
      FocusScope.of(context).requestFocus(_focusCategory);
      return;
    }
    if (_status == null || _statusController.text.trim().isEmpty) {
      await _ensureVisible(_statusKey);
      FocusScope.of(context).requestFocus(_focusStatus);
      return;
    }
    if (_addedController.text.trim().isEmpty) {
      await _ensureVisible(_addedKey);
      FocusScope.of(context).requestFocus(_focusAdded);
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);

    // нормализуем телефон (в БД — только цифры)
    final rawPhone = _phoneMask.getUnmaskedText();

    final contact = Contact(
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      ageManual: _ageManual,
      profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      phone: rawPhone,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim().toLowerCase() : null,
      social: _socialController.text.trim().isNotEmpty ? _socialController.text.trim() : null,
      category: _category!,
      status: _status!,
      tags: _tags.toList(),
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      createdAt: _addedDate,
    );

    try {
      await ContactDatabase.instance.insert(contact);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showErrorBanner('Не удалось сохранить. Возможно, контакт с таким телефоном уже существует.');
      setState(() => _saving = false);
    }
  }

  // ==================== UI helpers ====================
  InputDecoration _outlinedDec(
      ThemeData theme, {
        required String label,
        IconData? prefixIcon,
        String? hint,
        required TextEditingController controller,
        Widget? suffixIcon,
        bool showClear = true,
        bool requiredField = false,
        FloatingLabelBehavior floatingLabelBehavior = FloatingLabelBehavior.auto,
        String? errorText,
      }) {
    Widget? suffix = suffixIcon;
    if (showClear && controller.text.isNotEmpty) {
      suffix = IconButton(
        tooltip: 'Очистить',
        icon: const Icon(Icons.close),
        onPressed: () {
          controller.clear();
          setState(() {}); // обновить видимость и валидность
        },
      );
    }
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffix,
      helperText: requiredField ? 'Обязательное поле' : 'Необязательное поле',
      errorText: errorText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      floatingLabelBehavior: floatingLabelBehavior,
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
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

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
          childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          onExpansionChanged: onChanged,
          maintainState: true,
          trailing: const SizedBox.shrink(),
          title: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more),
              ),
              const Spacer(),
            ],
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _pickerField({
    required Key key,
    required IconData icon,
    required String title,
    required TextEditingController controller,
    String? hint,
    required bool isOpen,
    required FocusNode focusNode,
    required VoidCallback onTap,
    bool requiredField = false,
    bool forceFloatingLabel = false,
    Widget? prefix,
  }) {
    final floating = isOpen || focusNode.hasFocus || forceFloatingLabel;
    final showError = _submitted && requiredField && controller.text.trim().isEmpty;
    return TextFormField(
      key: key,
      controller: controller,
      readOnly: true,
      focusNode: focusNode,
      decoration: _outlinedDec(
        Theme.of(context),
        label: title,
        hint: floating ? hint : null,
        prefixIcon: null,
        controller: controller,
        suffixIcon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
        showClear: false,
        requiredField: requiredField,
        floatingLabelBehavior: floating ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
        errorText: showError ? 'Обязательное поле' : null,
      ).copyWith(
        prefixIcon: prefix ?? Icon(icon),
      ),
      onTap: () {
        FocusScope.of(context).requestFocus(focusNode);
        onTap();
      },
    );
  }

  Widget _socialPickerField() {
    final value = _socialController.text.trim();
    return TextFormField(
      key: const ValueKey('social'),
      controller: _socialController,
      readOnly: true,
      focusNode: _focusSocial,
      decoration: _outlinedDec(
        Theme.of(context),
        label: 'Соцсеть',
        hint: 'Выбрать соцсеть',
        controller: _socialController,
        suffixIcon: Icon(_socialOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
        showClear: false,
      ).copyWith(
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: value.isEmpty ? const Icon(Icons.public, size: 20) : _form.brandIcon(value, size: 20),
        ),
      ),
      onTap: () {
        FocusScope.of(context).requestFocus(_focusSocial);
        _pickSocial();
      },
    );
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    final catValue = (_category ?? _categoryController.text.trim());
    final statusValue = (_status ?? _statusController.text.trim());
    final categoryEmpty = catValue.isEmpty;
    final statusEmpty = statusValue.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: const Text('Добавить контакт'),
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            onPressed: _canSave ? _save : null, // всегда видима, но может быть disabled
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
          child: Scrollbar(
            controller: _scroll,
            child: ListView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // ===== Превью =====
                KeyedSubtree(
                  key: const ValueKey('header_preview'),
                  child: AddContactPreview(controller: _form),
                ),
                const SizedBox(height: 24),

                // ===== Основное =====
                _sectionCard(
                  title: 'Основное',
                  children: [
                    // ФИО
                    KeyedSubtree(
                      key: _nameKey,
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        maxLines: 1,
                        autofillHints: const [AutofillHints.name],
                        textInputAction: TextInputAction.next,
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'ФИО*',
                          prefixIcon: Icons.person_outline,
                          controller: _nameController,
                          requiredField: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Обязательное поле' : null,
                        onTapOutside: (_) => _defocus(),
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
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [_phoneMask],
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'Телефон*',
                          prefixIcon: Icons.phone_outlined,
                          controller: _phoneController,
                          requiredField: true,
                        ),
                        validator: (_) => _phoneValid ? null : 'Введите 10 цифр',
                        onTapOutside: (_) => _defocus(),
                      ),
                    ),
                  ],
                ),

                // ===== Категория и статус =====
                _sectionCard(
                  title: 'Категория и статус',
                  children: [
                    _pickerField(
                      key: _categoryKey,
                      icon: _form.categoryIcon(catValue),
                      title: 'Категория*',
                      controller: _categoryController,
                      hint: 'Выберите категорию',
                      isOpen: _categoryOpen,
                      focusNode: _focusCategory,
                      onTap: _pickCategory,
                      requiredField: true,
                      forceFloatingLabel: categoryEmpty,
                      prefix: Icon(_form.categoryIcon(catValue)),
                    ),
                    const SizedBox(height: 12),
                    _pickerField(
                      key: _statusKey,
                      icon: _form.statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
                      title: 'Статус*',
                      controller: _statusController,
                      hint: _category == null ? 'Сначала выберите категорию' : 'Выберите статус',
                      isOpen: _statusOpen,
                      focusNode: _focusStatus,
                      onTap: () {
                        if (_category != null) {
                          _pickStatus();
                        } else {
                          _hintSelectCategory();
                        }
                      },
                      requiredField: true,
                      forceFloatingLabel: statusEmpty,
                      prefix: Icon(
                        _form.statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
                        color: statusValue.isEmpty
                            ? Theme.of(context).hintColor
                            : _form.statusColor(statusValue),
                      ),
                    ),
                  ],
                ),

                // ===== Теги =====
                _sectionCard(
                  title: 'Теги',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in Dict.tags)
                          ChoiceChip(
                            label: Text(label),
                            selected: _tags.contains(label),
                            onSelected: (v) {
                              setState(() => _form.toggleTag(label));
                            },
                          ),
                      ],
                    ),
                  ],
                ),

                // ===== Дополнительно =====
                KeyedSubtree(
                  key: _extraCardKey,
                  child: _collapsibleSectionCard(
                    title: 'Дополнительно',
                    expanded: _extraExpanded,
                    onChanged: (v) {
                      setState(() => _extraExpanded = v);
                      if (v) _scrollToCard(_extraCardKey);
                    },
                    children: [
                      _pickerField(
                        key: const ValueKey('birth'),
                        icon: Icons.cake_outlined,
                        title: 'Дата рождения / возраст',
                        controller: _birthController,
                        hint: 'Указать дату или возраст',
                        isOpen: _birthOpen,
                        focusNode: _focusBirth,
                        onTap: _pickBirthOrAge,
                        forceFloatingLabel: true,
                      ),
                      const SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'Email',
                          prefixIcon: Icons.alternate_email_outlined,
                          controller: _emailController,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final value = v.trim();
                          final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          return regex.hasMatch(value) ? null : 'Некорректный email';
                        },
                        onTapOutside: (_) => _defocus(),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _professionController,
                        textInputAction: TextInputAction.next,
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'Профессия',
                          prefixIcon: Icons.work_outline,
                          controller: _professionController,
                        ),
                        onTapOutside: (_) => _defocus(),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _cityController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'Город проживания',
                          prefixIcon: Icons.location_city_outlined,
                          controller: _cityController,
                        ),
                        onTapOutside: (_) => _defocus(),
                      ),
                      const SizedBox(height: 12),

                      // Соцсеть
                      _socialPickerField(),
                    ],
                  ),
                ),

                // ===== Комментарий =====
                _sectionCard(
                  title: 'Комментарий',
                  children: [
                    TextFormField(
                      controller: _commentController,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: _outlinedDec(
                        Theme.of(context),
                        label: 'Комментарий',
                        prefixIcon: Icons.notes_outlined,
                        controller: _commentController,
                      ),
                      onTapOutside: (_) => _defocus(),
                    ),
                  ],
                ),

                // ===== Дата добавления =====
                _sectionCard(
                  title: 'Дата добавления',
                  children: [
                    _pickerField(
                      key: _addedKey,
                      icon: Icons.event_outlined,
                      title: 'Дата добавления*',
                      controller: _addedController,
                      isOpen: _addedOpen,
                      focusNode: _focusAdded,
                      onTap: _pickAddedDate,
                      requiredField: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Используется для истории и сортировки. Заметки добавляются на экране Деталей контакта.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ===== КНОПКА СОХРАНЕНИЯ =====
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 24),
                  child: Semantics(
                    button: true,
                    enabled: _canSave,
                    label: _saving
                        ? 'Сохранение контакта'
                        : (_canSave ? 'Сохранить контакт' : 'Кнопка сохранить недоступна'),
                    child: FilledButton.icon(
                      onPressed: _canSave ? _save : null,
                      icon: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Сохранить контакт'),
                      ),
                    ),
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

// ===== вспомогательные виджеты =====
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
