import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';

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

  // --- key для «Дополнительно» ---
  final _extraCardKey = GlobalKey();

// Плавный скролл к карточке после анимации раскрытия
  Future<void> _scrollToCard(GlobalKey key) async {
    await Future.delayed(const Duration(milliseconds: 240));
    await _ensureVisible(key);
  }


  void _hintSelectCategory() async {
    await _ensureVisible(_categoryKey);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сначала выберите категорию')),
    );
    FocusScope.of(context).requestFocus(_focusCategory);
  }

  // ==== PREVIEW HELPERS (как в _ContactCard из списка) ====

  Color _avatarBgFor(String seed, ColorScheme scheme) {
    int h = 0;
    for (final r in seed.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55);
    return hsl.toColor();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Активный':   return Colors.green;
      case 'Пассивный':  return Colors.orange;
      case 'Потерянный': return Colors.red;
      case 'Холодный':   return Colors.cyan;
      case 'Тёплый':     return Colors.pink;
      default:           return Colors.grey;
    }
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Новый':     return Colors.white;
      case 'Напомнить': return Colors.purple;
      case 'VIP':       return Colors.yellow;
      default:          return Colors.grey.shade200;
    }
  }

  Color _tagTextColor(String tag) {
    switch (tag) {
      case 'Новый':     return Colors.black;
      case 'Напомнить': return Colors.white;
      case 'VIP':       return Colors.black;
      default:          return Colors.black;
    }
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
    const double kStatusReserve = 120; // резерв справа под чип статуса
    final scheme = Theme.of(context).colorScheme;

    final name  = _nameController.text.trim().isEmpty ? 'Новый контакт' : _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final status = (_status ?? _statusController.text).trim();
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

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: scheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // контент с резервом под статус
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
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    phone.isEmpty ? '' : phone,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 10, color: _tagTextColor(tag)),
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
            // чип статуса в правом верхнем углу
            if (status.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: Chip(
                  label: Text(
                    status,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _statusColor(status),
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
          ],
        ),
      ),
    );
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
    if (widget.category != null) {
      _category = widget.category;
      _categoryController.text = widget.category!;
    }
    _addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);

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
          trailing: const SizedBox.shrink(),
          title: Row(
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
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
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      readOnly: true,
      focusNode: focusNode,
      decoration: _outlinedDec(
        Theme.of(context),
        label: title,
        hint: hint,
        prefixIcon: icon,
        controller: controller,
        suffixIcon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
        showClear: false,
        requiredField: requiredField,
      ),
      onTap: () {
        FocusScope.of(context).requestFocus(focusNode);
        onTap();
      },
    );
  }

  // Плитка «Соцсеть» — отдельная, чтобы показывать SVG leading
  Widget _socialPickerField() {
    final value = _socialController.text;
    final t = (_socialType ?? value).trim();
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
          padding: const EdgeInsets.all(10), // уменьшаем отступы
          child: t.isEmpty
              ? const Icon(Icons.public, size: 20) // стандартная иконка
              : _brandIcon(t, size: 20),          // svg-иконка меньшего размера
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
    final theme = Theme.of(context);
    final initials = _initials(_nameController.text);

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
        actions: [
          if (_canSave)
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.add),
              onPressed: _save,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              // ===== Блок: Заголовок (превью карточки) =====
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

              // ===== Блок: Основное =====
              _sectionCard(
                title: 'Основное',
                children: [
                  // ФИО
                  KeyedSubtree(
                    key: _nameKey,
                    child: TextFormField(
                      controller: _nameController,
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      decoration: _outlinedDec(
                        Theme.of(context),
                        label: 'ФИО*',
                        prefixIcon: Icons.person_outline,
                        controller: _nameController,
                        requiredField: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Введите ФИО' : null,
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
                      inputFormatters: [_phoneMask],
                      decoration: _outlinedDec(
                        Theme.of(context),
                        label: 'Телефон*',
                        prefixIcon: Icons.phone_outlined,
                        controller: _phoneController,
                        requiredField: true,
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
                  _pickerField(
                    key: _categoryKey,
                    icon: Icons.person_outline,
                    title: 'Категория*',
                    controller: _categoryController,
                    hint: 'Выберите категорию',
                    isOpen: _categoryOpen,
                    focusNode: _focusCategory,
                    onTap: _pickCategory,
                    requiredField: true,
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    key: _statusKey,
                    icon: Icons.how_to_reg,
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
                      for (final label in const ['Новый', 'Напомнить', 'VIP'])
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

              // ===== Блок: Дополнительно (скролл при раскрытии) =====
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
                    ),
                    const SizedBox(height: 12),

                    // Email
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _outlinedDec(
                        Theme.of(context),
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

              // ===== Блок: Комментарий =====
              _sectionCard(
                title: 'Комментарий',
                children: [
                  TextFormField(
                    controller: _commentController,
                    maxLines: 1,
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

              // ===== Блок: Дата добавления =====
              _sectionCard(
                title: 'Дата добавления',
                children: [
                  _pickerField(
                    key: const ValueKey('added'),
                    icon: Icons.event_outlined,
                    title: 'Дата добавления',
                    controller: _addedController,
                    isOpen: _addedOpen,
                    focusNode: _focusAdded,
                    onTap: _pickAddedDate,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заметки добавляются на экране Деталей контакта',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),


      // Кнопка снизу — скрыта, если нельзя сохранять
      bottomNavigationBar: _canSave
          ? SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Сохранить контакт'),
          ),
        ),
      )
          : null,
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