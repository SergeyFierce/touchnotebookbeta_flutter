import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';

import '../app.dart'; // для App.navigatorKey (SnackBar после pop)
import '../models/contact.dart';
import '../models/note.dart';
import '../services/contact_database.dart';
import 'contact_list_screen.dart'; // переход к восстановленному контакту
import 'notes_list_screen.dart';
import 'add_note_screen.dart';
import 'note_details_screen.dart';

class ContactDetailsScreen extends StatefulWidget {
  final Contact contact;
  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  bool _isEditing = false;          // режим редактирования
  late Contact _contact;            // последний сохранённый снимок

  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();

  // Keys для автоскролла к ошибкам
  final _nameKey = GlobalKey();
  final _phoneKey = GlobalKey();
  final _categoryKey = GlobalKey();
  final _statusKey = GlobalKey();
  final _addedKey = GlobalKey();

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

  // --- keys для автоскролла к самим карточкам ---
  final _extraCardKey = GlobalKey();
  final _notesCardKey = GlobalKey();

  // Плавный автоскролл к карточке после раскрытия (более мягкий)
  Future<void> _scrollToCard(GlobalKey key) async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment: 0.0, // к началу видимой области
      );
    });
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

  // ==== PREVIEW HELPERS (совпадают с _ContactCard) ====

  String _initialsFrom(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+'));
    String first = parts[0];
    String? second = parts.length > 1 ? parts[1] : null;

    String takeFirstLetter(String s) {
      if (s.isEmpty) return '';
      return s.characters.first.toUpperCase();
    }

    final a = takeFirstLetter(first);
    final b = second == null ? '' : takeFirstLetter(second);
    final res = (a + b);
    return res.isEmpty ? '?' : res;
  }

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
      case 'Активный': return Colors.green;
      case 'Пассивный': return Colors.orange;
      case 'Потерянный': return Colors.red;
      case 'Холодный': return Colors.cyan;
      case 'Тёплый': return Colors.pink;
    // <<< цвет плейсхолдера "Статус"
      case 'Статус': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Новый': return Colors.white;
      case 'Напомнить': return Colors.purple;
      case 'VIP': return Colors.yellow;
      default: return Colors.grey.shade200;
    }
  }

  Color _tagTextColor(String tag) {
    switch (tag) {
      case 'Новый': return Colors.black;
      case 'Напомнить': return Colors.white;
      case 'VIP': return Colors.black;
      default: return Colors.black;
    }
  }

  // <<< помощник: цифры из строки
  String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  // <<< НОВОЕ: формат превью телефона с X-плейсхолдерами
  // Берём последние 10 цифр (чтобы отрезать константную "7" из "+7 ..."),
  // подставляем их слева направо в шаблон "+7 (XXX) XXX-XX-XX".
  String _phonePreview() {
    // всегда только пользовательские 0..10 цифр без литерала +7
    final raw = _phoneMask.getUnmaskedText(); // пример: "931293463" (пока не 10 цифр)
    const template = '+7 (XXX) XXX-XX-XX';

    final buf = StringBuffer();
    int i = 0;
    for (final ch in template.runes) {
      if (String.fromCharCode(ch) == 'X') {
        buf.write(i < raw.length ? raw[i] : 'X');
        i++;
      } else {
        buf.writeCharCode(ch);
      }
    }
    return buf.toString();
  }


  // <<< НОВОЕ: текст статуса или плейсхолдер "Статус"
  String _statusOrPlaceholder() {
    final s = (_status ?? _statusController.text).trim();
    return s.isEmpty ? 'Статус' : s;
  }

  Widget _buildHeaderPreview(BuildContext context) {
    const double kStatusReserve = 120; // как в _ContactCard
    final scheme = Theme.of(context).colorScheme;
    final name = _nameController.text.trim().isEmpty ? 'Новый контакт' : _nameController.text.trim();

    // <<< телефон в превью с X-плейсхолдерами
    final phonePreview = _phonePreview();

    // <<< статус с плейсхолдером "Статус"
    final statusText = _statusOrPlaceholder();
    final tags = _tags.toList();

    Widget avatar() {
      final bg = _avatarBgFor(name, scheme);
      final initials = _initialsFrom(name);
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
            initials,
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
                  // <<< показываем всегда маску телефона с X
                  Text(
                    phonePreview,
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
            // <<< чип статуса теперь показывается ВСЕГДА; если статуса нет — "Статус" серый
            Positioned(
              top: 0,
              right: 0,
              child: Chip(
                label: Text(
                  statusText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: _statusColor(statusText),
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

  // ====== Состояния, соответствующие полям ======
  DateTime? _birthDate;
  int? _ageManual;
  String? _socialType;
  String? _category;
  String? _status;
  DateTime _addedDate = DateTime.now();
  final Set<String> _tags = <String>{};

  // UI flags
  bool _birthOpen = false;
  bool _socialOpen = false;
  bool _categoryOpen = false;
  bool _statusOpen = false;
  bool _addedOpen = false;

  bool _extraExpanded = false; // «Дополнительно»
  bool _notesExpanded = true; // «Заметки» открыто
  List<Note> _notes = [];

  // FocusNodes — для подсветки/навигации
  final FocusNode _focusBirth = FocusNode(skipTraversal: true);
  final FocusNode _focusSocial = FocusNode(skipTraversal: true);
  final FocusNode _focusCategory = FocusNode(skipTraversal: true);
  final FocusNode _focusStatus = FocusNode(skipTraversal: true);
  final FocusNode _focusAdded = FocusNode(skipTraversal: true);

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  // ===== Брендовые иконки (из assets/) =====
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
    _loadNotes();
    // чтобы превью обновлялось при каждом символе
    _phoneController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
    _statusController.addListener(() => setState(() {}));
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

  Future<void> _loadNotes() async {
    if (_contact.id == null) return;
    final notes = await ContactDatabase.instance.lastNotesByContact(_contact.id!, limit: 3);
    if (mounted) setState(() => _notes = notes);
  }

  Future<void> _addNote() async {
    if (_contact.id == null) return;
    final note = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNoteScreen(contactId: _contact.id!),
      ),
    );
    if (note != null) {
      await _loadNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заметка добавлена')));
    }
  }

  Future<void> _openNote(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailsScreen(note: note)),
    );

    if (result is Map && result['deleted'] is Note) {
      final deleted = result['deleted'] as Note;
      await _loadNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Заметка удалена'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final id = await ContactDatabase.instance.insertNote(deleted.copyWith(id: null));
              await _loadNotes();
              if (!mounted) return;
              final restored = deleted.copyWith(id: id);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteDetailsScreen(note: restored)),
              );
            },
          ),
        ),
      );
    }
  }

  // ==================== helpers ====================

  void _defocus() => FocusScope.of(context).unfocus();

  Contact _snapshot() => Contact(
    id: _contact.id,
    name: _nameController.text.trim(),
    birthDate: _birthDate,
    ageManual: _ageManual,
    profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
    city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
    phone: _phoneController.text.trim(),
    email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
    social: _socialType,
    category: _category ?? _categoryController.text.trim(),
    status: _status ?? _statusController.text.trim(),
    tags: _tags.toList(),
    comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    createdAt: _addedDate,
  );

  bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool get _isDirty {
    final cur = _snapshot();
    final old = _contact;

    if (cur.name != old.name) return true;
    if (cur.phone != old.phone) return true;
    if (cur.email != old.email) return true;
    if (cur.profession != old.profession) return true;
    if (cur.city != old.city) return true;
    if (cur.birthDate != old.birthDate) return true;
    if (cur.ageManual != old.ageManual) return true;
    if (cur.social != old.social) return true;
    if (cur.category != old.category) return true;
    if (cur.status != old.status) return true;
    if (cur.comment != old.comment) return true;
    if (cur.createdAt != old.createdAt) return true;

    final at = [...cur.tags]..sort();
    final bt = [...old.tags]..sort();
    if (!_listEq(at, bt)) return true;

    return false;
  }

  void _updateEditingFromDirty() {
    final d = _isDirty;
    if (_isEditing != d) setState(() => _isEditing = d);
  }

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

  void _setPhoneFromModel(String raw) {
    final d = _digitsOnly(raw);
    String masked = '';
    if (d.length >= 10) {
      final ten = d.substring(d.length - 10);
      masked = '+7 (${ten.substring(0, 3)}) ${ten.substring(3, 6)}-${ten.substring(6, 8)}-${ten.substring(8, 10)}';
    }
    _phoneMask.clear();
    final formatted = _phoneMask.formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(text: masked),
    );
    _phoneController.value = formatted;
  }

  bool get _phoneValid => _phoneMask.getUnmaskedText().length == 10;
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
          _phoneValid &&
          (_category ?? _categoryController.text.trim()).isNotEmpty &&
          (_status ?? _statusController.text.trim()).isNotEmpty &&
          _addedController.text.trim().isNotEmpty;

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
          children: const [
            ListTile(leading: Icon(Icons.cake_outlined), title: Text('Выбрать дату рождения'), dense: true),
            ListTile(leading: Icon(Icons.numbers), title: Text('Указать возраст'), dense: true),
          ],
        ),
      ),
    );
    setState(() => _birthOpen = false);

    if (choice == null) return;

    if (choice == 'date') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: now,
        initialDate: _birthDate ?? now,
        locale: const Locale('ru'),
      );
      if (picked != null && picked != _birthDate) {
        _birthDate = picked;
        _ageManual = null;
        final age = _calcAge(picked);
        _birthController.text = '${DateFormat('dd.MM.yyyy').format(picked)} (${_formatAge(age)})';
        setState(_updateEditingFromDirty);
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
            decoration: const InputDecoration(hintText: 'Количество лет', prefixIcon: Icon(Icons.numbers)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)), child: const Text('OK')),
          ],
        ),
      );
      if (age != null && age != _ageManual) {
        _ageManual = age;
        _birthDate = null;
        _birthController.text = 'Возраст: ${_formatAge(age)}';
        setState(_updateEditingFromDirty);
      }
    }
  }

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
                  ListTile(leading: _brandIcon('Telegram'), title: const Text('Telegram'), onTap: () => Navigator.pop(context, 'Telegram')),
                  ListTile(leading: _brandIcon('VK'), title: const Text('VK'), onTap: () => Navigator.pop(context, 'VK')),
                  ListTile(leading: _brandIcon('Instagram'), title: const Text('Instagram'), onTap: () => Navigator.pop(context, 'Instagram')),
                  ListTile(leading: _brandIcon('Facebook'), title: const Text('Facebook'), onTap: () => Navigator.pop(context, 'Facebook')),
                  ListTile(leading: _brandIcon('WhatsApp'), title: const Text('WhatsApp'), onTap: () => Navigator.pop(context, 'WhatsApp')),
                  ListTile(leading: _brandIcon('TikTok'), title: const Text('TikTok'), onTap: () => Navigator.pop(context, 'TikTok')),
                  ListTile(leading: _brandIcon('Одноклассники'), title: const Text('Одноклассники'), onTap: () => Navigator.pop(context, 'Одноклассники')),
                  ListTile(leading: _brandIcon('Twitter'), title: const Text('Twitter'), onTap: () => Navigator.pop(context, 'Twitter')),
                ],
              ),
            ),
          ),
        );
      },
    );

    setState(() => _socialOpen = false);

    if (result != null && result != _socialType) {
      _socialType = result;
      _socialController.text = result;
      setState(_updateEditingFromDirty);
    }
  }

  Future<void> _pickCategory() async {
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

    if (result != null && result != _category) {
      setState(() {
        _category = result;
        _categoryController.text = result;
        _status = null;
        _statusController.text = '';
      });
      await _pickStatus();
      _updateEditingFromDirty();
    }
  }

  Future<void> _pickStatus() async {
    if ((_category ?? '').isEmpty) {
      await _ensureVisible(_categoryKey);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала выберите категорию')));
      return;
    }

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

    if (result != null && result != _status) {
      setState(() {
        _status = result;
        _statusController.text = result;
      });
      _updateEditingFromDirty();
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

    if (picked != null && picked != _addedDate) {
      setState(() {
        _addedDate = picked;
        _addedController.text = DateFormat('dd.MM.yyyy').format(picked);
      });
      _updateEditingFromDirty();
    }
  }

  // ==================== save / delete ====================

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
    if (!_canSave) {
      if ((_category ?? '').isEmpty) {
        await _ensureVisible(_categoryKey);
      } else if ((_status ?? '').isEmpty) {
        await _ensureVisible(_statusKey);
      } else {
        await _ensureVisible(_addedKey);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите дату добавления')),
        );
      }
      return;
    }

    final updated = _snapshot();

    await ContactDatabase.instance.update(updated);
    if (!mounted) return;
    setState(() {
      _contact = updated;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Изменения сохранены')));
  }

  // SnackBar с Undo — тот же, что в списке
  Timer? _snackTimer;

  Future<void> _deleteWithUndo(Contact c) async {
    if (c.id == null) return;

    final db = ContactDatabase.instance;

    final notesSnapshot = await db.deleteContactWithSnapshot(c.id!);

    final ctx = App.navigatorKey.currentContext ?? context;
    final messenger = ScaffoldMessenger.of(ctx);

    const duration = Duration(seconds: 4);
    messenger.clearSnackBars();
    _snackTimer?.cancel();

    final endTime = DateTime.now().add(duration);
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: _UndoSnackContent(endTime: endTime, duration: duration),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            _snackTimer?.cancel();
            messenger.hideCurrentSnackBar();

            final newId = await db.restoreContactWithNotes(c.copyWith(id: null), notesSnapshot);

            await _goToRestored(c, newId);
          },
        ),
      ),
    );

    _snackTimer = Timer(endTime.difference(DateTime.now()), () => controller.close());

    if (mounted) Navigator.pop(context, true);
  }

  String _titleForCategory(String cat) {
    switch (cat) {
      case 'Партнёр':
        return 'Партнёры';
      case 'Клиент':
        return 'Клиенты';
      case 'Потенциальный':
        return 'Потенциальные';
      default:
        return cat;
    }
  }

  Future<void> _goToRestored(Contact restored, int restoredId) async {
    final title = _titleForCategory(restored.category);
    App.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ContactListScreen(
          category: restored.category,
          title: title,
          scrollToId: restoredId,
        ),
      ),
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
    if (ok == true) await _deleteWithUndo(_contact);
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
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon ??
          (showClear && controller.text.isNotEmpty
              ? IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.close),
            onPressed: () {
              controller.clear();
              setState(_updateEditingFromDirty);
            },
          )
              : null),
      helperText: requiredField ? 'Обязательное поле' : 'Необязательное поле',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _borderedTile({required Widget child}) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
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

  Widget _sectionCard({required String title, required List<Widget> children}) {
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
    List<Widget> headerActions = const [],
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
          tilePadding: const EdgeInsets.only(left: 16, right: 0),
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 16, 16),
          onExpansionChanged: onChanged,
          maintainState: true,
          trailing: const SizedBox.shrink(),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                ],
              ),
              ...headerActions,
            ],
          ),
          children: children,
        ),
      ),
    );
  }

  // ===== Новые «поля-пикеры» как в AddContact =====

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
        // компактная иконка бренда слева
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: t.isEmpty ? const Icon(Icons.public, size: 20) : _brandIcon(t, size: 20),
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
            _updateEditingFromDirty();
          });
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: _isEditing
            ? IconButton(
          tooltip: 'Отмена',
          icon: const Icon(Icons.close),
          onPressed: () {
            _loadFromContact();
            setState(() => _isEditing = false);
          },
        )
            : const BackButton(),
        title: Text(_isEditing ? 'Редактирование' : 'Детали контакта'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Сохранить',
              icon: const Icon(Icons.check),
              onPressed: (_isDirty && _canSave) ? _save : null,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: ListView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      onChanged: (_) => _updateEditingFromDirty(),
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
                      onChanged: (_) => _updateEditingFromDirty(),
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
                    hint: (_category ?? '').isEmpty ? 'Сначала выберите категорию' : 'Выберите статус',
                    isOpen: _statusOpen,
                    focusNode: _focusStatus,
                    onTap: _pickStatus,
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
                              _updateEditingFromDirty();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),

              // ===== Блок: Дополнительно =====
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
                      onChanged: (_) => _updateEditingFromDirty(),
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
                      onChanged: (_) => _updateEditingFromDirty(),
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
                      onChanged: (_) => _updateEditingFromDirty(),
                    ),
                    const SizedBox(height: 12),

                    // Соцсеть — как в AddContact (однострочное поле-пикер)
                    _socialPickerField(),
                  ],
                ),
              ),

              // ===== Блок: Заметки =====
              KeyedSubtree(
                key: _notesCardKey,
                child: _collapsibleSectionCard(
                  title: 'Заметки',
                  expanded: _notesExpanded,
                  onChanged: (v) {
                    setState(() => _notesExpanded = v);
                    if (v) _scrollToCard(_notesCardKey);
                  },
                  headerActions: [
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        if (_contact.id == null) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotesListScreen(contact: _contact),
                          ),
                        );
                        await _loadNotes();
                      },
                      child: const Text('Все заметки'),
                    ),
                  ],
                  children: _notes.isEmpty
                      ? const [
                    Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(Icons.sticky_note_2_outlined),
                        title: Text('Нет заметок'),
                      ),
                    ),
                  ]
                      : [
                    Card(
                      elevation: 0,
                      child: Column(
                        children: ListTile.divideTiles(
                          context: context,
                          tiles: _notes.map((n) => ListTile(
                            leading:
                            const Icon(Icons.sticky_note_2_outlined),
                            title: Text(n.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(DateFormat('dd.MM.yyyy')
                                .format(n.createdAt)),
                            onTap: () => _openNote(n),
                          )),
                        ).toList(),
                      ),
                    ),
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
                    onChanged: (_) => _updateEditingFromDirty(),
                  ),
                ],
              ),

              // ===== Блок: Дата добавления =====
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
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isEditing ? Theme.of(context).colorScheme.primary : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isEditing ? (_canSave ? _save : null) : _delete,
                  child: Text(_isEditing ? 'Сохранить' : 'Удалить контакт'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Инициализация из модели =====

  void _loadFromContact() {
    final c = _contact;

    _nameController.text = c.name;

    if (c.birthDate != null) {
      _birthDate = c.birthDate;
      _ageManual = null;
      final age = _calcAge(c.birthDate!);
      _birthController.text = '${DateFormat('dd.MM.yyyy').format(c.birthDate!)} (${_formatAge(age)})';
    } else if (c.ageManual != null) {
      _ageManual = c.ageManual;
      _birthDate = null;
      _birthController.text = 'Возраст: ${_formatAge(c.ageManual!)}';
    } else {
      _birthDate = null;
      _ageManual = null;
      _birthController.clear();
    }

    _professionController.text = c.profession ?? '';
    _cityController.text = c.city ?? '';
    _setPhoneFromModel(c.phone);
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

/// Контент SnackBar с обратным отсчётом и прогресс-баром (как в списке).
class _UndoSnackContent extends StatefulWidget {
  final DateTime endTime;
  final Duration duration;
  const _UndoSnackContent({required this.endTime, required this.duration});

  @override
  State<_UndoSnackContent> createState() => _UndoSnackContentState();
}

class _UndoSnackContentState extends State<_UndoSnackContent> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  double _fractionRemaining(DateTime now) {
    final total = widget.duration.inMilliseconds;
    final left = widget.endTime.difference(now).inMilliseconds;
    if (total <= 0) return 0;
    return left <= 0 ? 0 : (left / total).clamp(0.0, 1.0);
  }

  void _syncAndRun() {
    final now = DateTime.now();
    final frac = _fractionRemaining(now); // 0..1
    final msLeft = (widget.duration.inMilliseconds * frac).round();

    _ctrl.stop();
    _ctrl.value = frac;
    if (msLeft > 0) {
      _ctrl.animateTo(0.0, duration: Duration(milliseconds: msLeft), curve: Curves.linear);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, value: 1.0, lowerBound: 0.0, upperBound: 1.0)
      ..addListener(() { if (mounted) setState(() {}); });
    _syncAndRun();
  }

  @override
  void didUpdateWidget(covariant _UndoSnackContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime || oldWidget.duration != widget.duration) {
      _syncAndRun();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _ctrl.value; // 1.0 -> 0.0
    final secondsLeft = (value * widget.duration.inSeconds).ceil().clamp(0, 999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Expanded(child: Text('Контакт удалён')), Text('$secondsLeft c')]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value),
      ],
    );
  }
}
