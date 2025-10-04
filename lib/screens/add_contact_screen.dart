import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';
import 'package:flutter/services.dart';

import '../models/contact.dart';
import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';

/// Словари (централизовано, без «магических» строк)
abstract class Dict {
  static const categories = ['Партнёр', 'Клиент', 'Потенциальный'];

  static const statusesByCategory = {
    'Партнёр': ['Активный', 'Пассивный', 'Потерянный'],
    'Клиент': ['Активный', 'Пассивный', 'Потерянный'],
    'Потенциальный': ['Холодный', 'Тёплый', 'Потерянный'],
  };

  static const tags = ['Новый', 'VIP'];
}

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
  final _addedKey = GlobalKey();
  final _emailFieldKey = GlobalKey();

  // Controllers
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _professionController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _socialController = TextEditingController(); // единый источник правды
  final _categoryController = TextEditingController();
  final _statusController = TextEditingController();
  final _commentController = TextEditingController();
  final _addedController = TextEditingController();

  // --- UI state ---
  bool _submitted = false;
  bool _saving = false;
  bool _emailTouched = false;

  // --- key для «Дополнительно» ---
  final _extraCardKey = GlobalKey();

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

  // ==== PREVIEW HELPERS ====
  Color _avatarBgFor(String seed, ColorScheme scheme) {
    int h = 0;
    for (final r in seed.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55);
    return hsl.toColor();
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Активный':
        return Icons.check_circle;
      case 'Пассивный':
        return Icons.pause_circle;
      case 'Потерянный':
        return Icons.cancel;
      case 'Холодный':
        return Icons.ac_unit;
      case 'Тёплый':
        return Icons.local_fire_department;
      default:
        return Icons.label_outline;
    }
  }

  IconData _categoryIcon(String? c) {
    switch (c) {
      case 'Партнёр':
        return Icons.handshake;
      case 'Клиент':
        return Icons.people;
      case 'Потенциальный':
        return Icons.person_add_alt_1;
      default:
        return Icons.person_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Активный':
        return Colors.green;
      case 'Пассивный':
        return Colors.orange;
      case 'Потерянный':
        return Colors.red;
      case 'Холодный':
        return Colors.cyan;
      case 'Тёплый':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  // читабельный цвет текста на ярких чипах статуса
  Color _onStatus(Color bg) {
    final brightness = bg.computeLuminance();
    return brightness > 0.5 ? Colors.black : Colors.white;
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Новый':
        return Colors.white;
      case Contact.reminderTagName:
      case Contact.legacyReminderTagName:
        return Colors.purple;
      case 'VIP':
        return Colors.yellow;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _tagTextColor(String tag) {
    switch (tag) {
      case 'Новый':
      case 'VIP':
        return Colors.black;
      case Contact.reminderTagName:
      case Contact.legacyReminderTagName:
        return Colors.white;
      default:
        return Colors.black;
    }
  }

  // Прогрессивная маска телефона для превью
  String _previewPhoneMasked() {
    final digits = _phoneMask.getUnmaskedText(); // 0..10
    const mask = '+7 (XXX) XXX-XX-XX';
    final buf = StringBuffer();
    int di = 0;
    for (int i = 0; i < mask.length; i++) {
      final ch = mask[i];
      if (ch == 'X') {
        if (di < digits.length) {
          buf.write(digits[di]);
          di++;
        } else {
          buf.write('X');
        }
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  Widget _previewCaption(BuildContext context, {String text = 'Предпросмотр карточки'}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: theme.hintColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPreview(BuildContext context) {
    const double kStatusReserve = 120;
    final scheme = Theme.of(context).colorScheme;
    final name = _nameController.text.trim().isEmpty ? 'Новый контакт' : _nameController.text.trim();
    final statusValue = (_status ?? _statusController.text).trim();
    final statusText = statusValue.isEmpty ? 'Статус' : statusValue;
    final statusBg = statusValue.isEmpty ? Colors.grey : _statusColor(statusValue);
    final onStatus = _onStatus(statusBg);
    final tags = _tags.toList();

    Widget avatar() {
      final bg = _avatarBgFor(name, scheme);
      final initials = _initials(name);
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 0),
        ),
        child: CircleAvatar(
          backgroundColor: bg,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Превью контакта. Имя: $name. Статус: $statusText. Телефон: ${_previewPhoneMasked()}.',
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: scheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: kStatusReserve),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        avatar(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _previewPhoneMasked(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in tags)
                            Chip(
                              label: Text(
                                tag,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: _tagTextColor(tag)),
                              ),
                              backgroundColor: _tagColor(tag),
                              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Chip(
                  label: Text(
                    statusText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: onStatus),
                  ),
                  backgroundColor: statusBg,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: onStatus.withOpacity(0.25), width: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== Состояния ======
  DateTime? _birthDate;
  int? _ageManual;
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
  final FocusNode _focusEmail = FocusNode();

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // ===== Брендовые иконки (из папки assets/) =====
  static const Map<String, String> _brandSlug = {
    'Telegram': 'telegram',
    'VK': 'vk',
    'WhatsApp': 'whatsapp',
    'TikTok': 'tiktok',
    'Одноклассники': 'odnoklassniki',
    'MAX': 'MAX',
  };

  String _brandAssetPath(String value) {
    final slug = _brandSlug[value];
    if (slug == null) return '';
    return 'assets/$slug.svg';
  }

  Widget _brandIcon(String value, {double size = 24}) {
    final path = _brandAssetPath(value);
    if (path.isEmpty) return const Icon(Icons.public);
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
      semanticsLabel: value,
      placeholderBuilder: (_) => const Icon(Icons.public),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _category = widget.category;
      _categoryController.text = widget.category!;
    }
    _addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);

    // Обновление превью по ключевым полям
    _nameController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _professionController.addListener(() => setState(() {}));
    _cityController.addListener(() => setState(() {}));
    _commentController.addListener(() => setState(() {}));

    _focusCategory.addListener(() => setState(() {}));
    _focusStatus.addListener(() => setState(() {}));
    _focusSocial.addListener(() => setState(() {}));
    _focusBirth.addListener(() => setState(() {}));
    _focusAdded.addListener(() => setState(() {}));
    _focusEmail.addListener(() {
      if (!_focusEmail.hasFocus && _emailController.text.trim().isNotEmpty && !_emailTouched) {
        setState(() => _emailTouched = true);
      }
    });
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
    _focusEmail.dispose();
    super.dispose();
  }

  // ==================== helpers ====================
  void _defocus() => FocusScope.of(context).unfocus();

  int _calcAge(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
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
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.take(1).toString() + parts[1].characters.take(1).toString()).toUpperCase();
  }

  Future<void> _ensureVisible(GlobalKey key) async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.1,
        ).whenComplete(() {
          if (!completer.isCompleted) completer.complete();
        });
      } else {
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _showFieldIssue({
    required String message,
    GlobalKey? targetKey,
    FocusNode? focusNode,
    bool expandExtra = false,
  }) async {
    showErrorBanner(message);
    if (expandExtra) {
      if (!_extraExpanded) {
        setState(() => _extraExpanded = true);
      }
      await _ensureVisible(_extraCardKey);
    }
    if (targetKey != null) {
      await _ensureVisible(targetKey);
    }
    if (focusNode != null) {
      FocusScope.of(context).requestFocus(focusNode);
    }
  }

  bool get _phoneValid => _phoneMask.getUnmaskedText().length == 10;

  bool get _emailValid {
    final value = _emailController.text.trim();
    if (value.isEmpty) return true;
    return _emailRegex.hasMatch(value);
  }

  bool get _canSave => !_saving;

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
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
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

  // Bottom sheet соцсетей — иконки через SVG ассеты
  Future<void> _pickSocial() async {
    FocusScope.of(context).requestFocus(_focusSocial);
    setState(() => _socialOpen = true);

    const options = [
      'Telegram',
      'VK',
      'WhatsApp',
      'TikTok',
      'Одноклассники',
      'MAX',
    ];

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
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0) const Divider(height: 0),
                    ListTile(
                      leading: _brandIcon(options[i]),
                      title: Text(options[i]),
                      onTap: () => Navigator.pop(context, options[i]),
                    ),
                  ],
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
        _categoryController.text = result;
        _statusController.text = '';
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
                leading: Icon(_statusIcon(s)),
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
      helpText: 'Дата добавления',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
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
    if (!_submitted) {
      setState(() => _submitted = true);
    }

    _formKey.currentState?.validate();

    final trimmedName = _nameController.text.trim();
    final categoryValue = _category ?? _categoryController.text.trim();
    final statusValue = _status ?? _statusController.text.trim();
    final addedValue = _addedController.text.trim();

    if (trimmedName.isEmpty) {
      await _showFieldIssue(
        message: 'Заполните поле «ФИО»',
        targetKey: _nameKey,
      );
      return;
    }

    if (!_phoneValid) {
      await _showFieldIssue(
        message: 'Введите номер телефона',
        targetKey: _phoneKey,
      );
      return;
    }

    if (!_emailValid) {
      if (!_emailTouched) {
        setState(() => _emailTouched = true);
      }
      await _showFieldIssue(
        message: 'Некорректный email',
        targetKey: _emailFieldKey,
        focusNode: _focusEmail,
        expandExtra: true,
      );
      return;
    }

    if (categoryValue.isEmpty) {
      await _showFieldIssue(
        message: 'Выберите категорию',
        targetKey: _categoryKey,
        focusNode: _focusCategory,
      );
      return;
    }

    if (statusValue.isEmpty) {
      await _showFieldIssue(
        message: 'Выберите статус',
        targetKey: _statusKey,
        focusNode: _focusStatus,
      );
      return;
    }

    if (addedValue.isEmpty) {
      await _showFieldIssue(
        message: 'Укажите дату добавления',
        targetKey: _addedKey,
        focusNode: _focusAdded,
      );
      return;
    }

    if (_saving) return;

    setState(() => _saving = true);

    // нормализуем телефон (в БД — только цифры)
    final rawPhone = _phoneMask.getUnmaskedText();

    final duplicate = await ContactDatabase.instance.contactByPhone(rawPhone);
    if (duplicate != null) {
      if (mounted) {
        showErrorBanner('Контакт с таким телефоном уже существует');
        await _ensureVisible(_phoneKey);
        setState(() => _saving = false);
      }
      return;
    }

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
      activeReminderCount: 0,
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
          child: value.isEmpty ? const Icon(Icons.public, size: 20) : _brandIcon(value, size: 20),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _previewCaption(context),
                    KeyedSubtree(
                      key: const ValueKey('header_preview'),
                      child: _buildHeaderPreview(context),
                    ),
                  ],
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
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))],
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
                      icon: _categoryIcon(catValue),
                      title: 'Категория*',
                      controller: _categoryController,
                      hint: 'Выберите категорию',
                      isOpen: _categoryOpen,
                      focusNode: _focusCategory,
                      onTap: _pickCategory,
                      requiredField: true,
                      forceFloatingLabel: categoryEmpty,
                      prefix: Icon(_categoryIcon(catValue)),
                    ),
                    const SizedBox(height: 12),
                    _pickerField(
                      key: _statusKey,
                      icon: _statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
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
                        _statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
                        color: statusValue.isEmpty ? Theme.of(context).hintColor : _statusColor(statusValue),
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
                              setState(() {
                                if (v) {
                                  _tags.add(label);
                                } else {
                                  _tags.remove(label);
                                }
                              });
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
                        key: _emailFieldKey,
                        controller: _emailController,
                        focusNode: _focusEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autovalidateMode:
                            _submitted || _emailTouched ? AutovalidateMode.always : AutovalidateMode.disabled,
                        decoration: _outlinedDec(
                          Theme.of(context),
                          label: 'Email',
                          prefixIcon: Icons.alternate_email_outlined,
                          controller: _emailController,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final value = v.trim();
                          return _emailRegex.hasMatch(value) ? null : 'Некорректный email';
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
                      minLines: 1,
                      maxLines: null,
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
                    label: _saving ? 'Сохранение контакта' : 'Сохранить контакт',
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
