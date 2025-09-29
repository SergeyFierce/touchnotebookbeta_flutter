import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';
import 'package:overlay_support/overlay_support.dart';

import '../models/contact.dart';
import '../models/note.dart';
import '../models/reminder.dart';
import '../services/contact_database.dart';
import '../services/push_notifications.dart';
import '../widgets/system_notifications.dart';
import 'notes_list_screen.dart';
import 'add_note_screen.dart';
import 'contact_list_screen.dart';

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
  final _remindersCardKey = GlobalKey();
  final _notesCardKey = GlobalKey();

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Активный':   return Icons.check_circle;
      case 'Пассивный':  return Icons.pause_circle;
      case 'Потерянный': return Icons.cancel;
      case 'Холодный':   return Icons.ac_unit;
      case 'Тёплый':     return Icons.local_fire_department;
      default:           return Icons.label_outline;
    }
  }

  Widget _reminderTile(Reminder reminder, {required bool completed}) {
    final theme = Theme.of(context);
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    final subtitle = completed
        ? reminder.completedAt != null
            ? 'Завершено: ${formatter.format(reminder.completedAt!)}'
            : 'Завершено'
        : 'Запланировано на ${formatter.format(reminder.remindAt)}';

    final actions = <Widget>[
      if (!completed)
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Отметить выполненным',
          color: theme.colorScheme.primary,
          onPressed: () => _completeReminder(reminder),
        ),
      if (!completed)
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Редактировать напоминание',
          onPressed: () => _editReminder(reminder),
        ),
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Удалить напоминание',
        onPressed: () => _confirmDeleteReminder(reminder),
      ),
    ];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        completed ? Icons.check_circle : Icons.notifications_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(reminder.text, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions,
      ),
    );
  }

  Widget _noteRow(Note note, {bool isLast = false}) {
    final theme = Theme.of(context);
    return _sheetRow(
      leading: const Icon(Icons.sticky_note_2_outlined),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd.MM.yyyy').format(note.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      onTap: null,
      isLast: isLast,
    );
  }

  Widget _sheetRow({
    required Widget leading,
    required Widget right,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    final leftCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Center(child: leading),
    );

    final rightCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: right,
    );

    final rightDivider = SizedBox(
      height: 0.5,
      child: ColoredBox(color: theme.dividerColor.withOpacity(0.25)),
    );

    return InkWell(
      onTap: onTap,
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(), // узкая колонка с иконкой
          1: FlexColumnWidth(),      // правая — резиновая
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [leftCell, rightCell]),
          if (!isLast)
            TableRow(children: [
              const SizedBox(), // слева пусто
              rightDivider,     // линия только под правой колонкой
            ]),
        ],
      ),
    );
  }


  Widget _radioRow<T>({
    required T value,
    required T? groupValue,
    required String title,
    IconData? icon,
    Widget? leading,
    required VoidCallback onSelect,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    // Левая ячейка: центрируем иконку; ширина колонки будет равна её естественной ширине.
    final leftCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Center(child: leading ?? (icon != null ? Icon(icon) : const SizedBox())),
    );

    // Правая ячейка: текст тянется, радио справа.
    final rightCell = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          Radio<T>(
            value: value,
            groupValue: groupValue,
            onChanged: (_) => onSelect(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
        ],
      ),
    );

    // Делитель только под правой колонкой, на всю её ширину.
    final rightDivider = SizedBox(
      height: 0.5,
      child: ColoredBox(
        color: theme.dividerColor.withOpacity(0.25),
      ),
    );

    return InkWell(
      onTap: onSelect,
      child: Table(
        // Лево — естественная ширина (иконка), право — тянется.
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [leftCell, rightCell]),
          if (!isLast)
            TableRow(children: [
              const SizedBox(),   // пусто в левой колонке
              rightDivider,       // линия только под правой колонкой
            ]),
        ],
      ),
    );
  }




  Widget _sheetWrap({required String title, required Widget child}) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final maxH = c.maxHeight; // учитывает клавиатуру
          return Padding(
            padding: EdgeInsets.only(left:16, right:16, top:8, bottom: bottom > 0 ? bottom : 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    child,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }



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

  IconData _categoryIcon(String? c) {
    switch (c) {
      case 'Партнёр':       return Icons.handshake;
      case 'Клиент':        return Icons.people;
      case 'Потенциальный': return Icons.person_add_alt_1;
      default:              return Icons.person_outline;
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
  bool _remindersExpanded = true; // «Напоминания» открыто
  List<Reminder> _activeReminders = [];
  List<Reminder> _completedReminders = [];
  int _selectedRemindersTab = 0;
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
    _loadReminders();
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
    _undoBanner = null;
    _undoBanner?.dismiss();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final contactId = _contact.id;
    if (contactId == null) {
      if (mounted) {
        setState(() {
          _activeReminders = [];
          _completedReminders = [];
        });
      }
      return;
    }

    final db = ContactDatabase.instance;
    final active = await db.remindersByContact(contactId, onlyActive: true);
    final completed =
        await db.remindersByContact(contactId, onlyCompleted: true);

    if (mounted) {
      setState(() {
        _activeReminders = active;
        _completedReminders = completed;
      });
    }
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
      showSuccessBanner('Заметка добавлена');
    }
  }

  Future<void> _addReminder() async {
    if (_contact.id == null) {
      showErrorBanner('Сохраните контакт, чтобы добавить напоминание');
      return;
    }

    final result = await _showReminderDialog();
    if (result == null) return;

    final text = result.text.trim();
    final when = result.when;
    if (when.isBefore(DateTime.now())) {
      showErrorBanner('Выберите время в будущем');
      return;
    }

    final reminder = Reminder(
      contactId: _contact.id!,
      text: text,
      remindAt: when,
      createdAt: DateTime.now(),
    );

    try {
      final id = await ContactDatabase.instance.insertReminder(reminder);
      final saved = reminder.copyWith(id: id);

      await PushNotifications.scheduleOneTime(
        id: saved.id!,
        whenLocal: saved.remindAt,
        title: 'Напоминание: ${_contact.name}',
        body: saved.text,
      );

      await _loadReminders();
      if (!mounted) return;
      showSuccessBanner('Напоминание добавлено');
    } catch (e) {
      if (mounted) {
        showErrorBanner('Не удалось сохранить напоминание: $e');
      }
    }
  }

  Future<void> _editReminder(Reminder reminder) async {
    if (reminder.id == null || reminder.completedAt != null) return;

    final result = await _showReminderDialog(initial: reminder);
    if (result == null) return;

    final text = result.text.trim();
    final when = result.when;
    if (when.isBefore(DateTime.now())) {
      showErrorBanner('Выберите время в будущем');
      return;
    }

    final updated = reminder.copyWith(text: text, remindAt: when);

    try {
      await ContactDatabase.instance.updateReminder(updated);
      await PushNotifications.cancel(reminder.id!);
      await PushNotifications.scheduleOneTime(
        id: updated.id!,
        whenLocal: updated.remindAt,
        title: 'Напоминание: ${_contact.name}',
        body: updated.text,
      );

      await _loadReminders();
      if (!mounted) return;
      showSuccessBanner('Напоминание обновлено');
    } catch (e) {
      if (mounted) {
        showErrorBanner('Не удалось обновить напоминание: $e');
      }
    }
  }

  Future<void> _completeReminder(Reminder reminder) async {
    final reminderId = reminder.id;
    if (reminderId == null || reminder.completedAt != null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить напоминание?'),
        content: const Text('Напоминание будет отмечено как выполненное и уведомление отменится.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = reminder.copyWith(completedAt: DateTime.now());

    try {
      await ContactDatabase.instance.updateReminder(updated);
      await PushNotifications.cancel(reminderId);
      await _loadReminders();
      if (!mounted) return;
      showSuccessBanner('Напоминание завершено');
    } catch (e) {
      if (mounted) {
        showErrorBanner('Не удалось завершить напоминание: $e');
      }
    }
  }

  Future<void> _confirmDeleteReminder(Reminder reminder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text('Напоминание будет удалено и уведомление отменено.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final reminderId = reminder.id;
    if (reminderId == null) return;

    try {
      await ContactDatabase.instance.deleteReminder(reminderId);
      await PushNotifications.cancel(reminderId);
      await _loadReminders();
      if (!mounted) return;
      showSuccessBanner('Напоминание удалено');
    } catch (e) {
      if (mounted) {
        showErrorBanner('Не удалось удалить напоминание: $e');
      }
    }
  }

  Future<({String text, DateTime when})?> _showReminderDialog({Reminder? initial}) async {
    final controller = TextEditingController(text: initial?.text ?? '');
    var selected = initial?.remindAt ?? DateTime.now().add(const Duration(minutes: 5));

    final result = await showDialog<({String text, DateTime when})>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dateLabel = DateFormat('dd.MM.yyyy HH:mm').format(selected);

            return AlertDialog(
              title: Text(initial == null ? 'Новое напоминание' : 'Редактирование напоминания'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: null,
                    autofocus: true,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Текст напоминания',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(dateLabel),
                    subtitle: const Text('Дата и время'),
                    onTap: () async {
                      final picked = await _pickReminderDateTime(selected);
                      if (picked != null) {
                        setState(() => selected = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      showErrorBanner('Введите текст напоминания');
                      return;
                    }
                    Navigator.pop(context, (text: text, when: selected));
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<DateTime?> _pickReminderDateTime(DateTime initial) async {
    final now = DateTime.now();
    final minimumDate = initial.isBefore(now) ? initial : now;
    var temp = initial;

    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext, temp),
                        child: const Text('Готово'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    use24hFormat: true,
                    initialDateTime: initial,
                    minimumDate: minimumDate,
                    maximumDate: now.add(const Duration(days: 365 * 5)),
                    onDateTimeChanged: (value) => temp = value,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

    final mode = (_birthDate != null)
        ? 'date'
        : (_ageManual != null ? 'age' : null);

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => _sheetWrap(
        title: 'Дата рождения / возраст',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radioRow<String>(
              value: 'date',
              groupValue: mode,
              title: 'Выбрать дату рождения',
              icon: Icons.cake_outlined,
              onSelect: () => Navigator.pop(context, 'date'),
            ),
            _radioRow<String>(
              value: 'age',
              groupValue: mode,
              title: 'Указать возраст',
              icon: Icons.numbers,
              onSelect: () => Navigator.pop(context, 'age'),
              isLast: true,
            ),
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
        _birthController.text =
        '${DateFormat('dd.MM.yyyy').format(picked)} (${_formatAge(age)})';
        setState(_updateEditingFromDirty);
      }
    } else if (choice == 'age') {
      final ctrl = TextEditingController();
      final age = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // мягкие углы
          ),
          title: const Text('Возраст'),
          content: SizedBox(
            width: double.maxFinite, // растягиваем по ширине диалога
            child: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Возраст',
                hintText: 'Количество лет',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
              child: const Text('OK'),
            ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        final maxH = MediaQuery.of(context).size.height * 0.8;
        final items = [
          'Telegram','VK','Instagram','Facebook','WhatsApp','TikTok','Одноклассники','Twitter',
        ];
        return _sheetWrap(
          title: 'Соцсеть',
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < items.length; i++)
                    _radioRow<String>(
                      value: items[i],
                      groupValue: _socialType,
                      title: items[i],
                      leading: _brandIcon(items[i]),
                      onSelect: () => Navigator.pop(context, items[i]),
                      isLast: i == items.length - 1,
                    ),
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => _sheetWrap(
        title: 'Категория',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _radioRow<String>(
              value: 'Партнёр',
              groupValue: _category,
              title: 'Партнёр',
              icon: Icons.handshake,
              onSelect: () => Navigator.pop(context, 'Партнёр'),
            ),
            _radioRow<String>(
              value: 'Клиент',
              groupValue: _category,
              title: 'Клиент',
              icon: Icons.people,
              onSelect: () => Navigator.pop(context, 'Клиент'),
            ),
            _radioRow<String>(
              value: 'Потенциальный',
              groupValue: _category,
              title: 'Потенциальный',
              icon: Icons.person_add_alt_1,
              onSelect: () => Navigator.pop(context, 'Потенциальный'),
              isLast: true,
            ),
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
      showInfoBanner('Сначала выберите категорию');
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => _sheetWrap(
        title: 'Статус',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < options.length; i++)
              _radioRow<String>(
                value: options[i],
                groupValue: _status,
                title: options[i],
                icon: _statusIcon(options[i]),   // ← вот тут
                onSelect: () => Navigator.pop(context, options[i]),
                isLast: i == options.length - 1,
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
        showWarningBanner('Укажите дату добавления');
      }
      return;
    }

    final updated = _snapshot();
    await ContactDatabase.instance.update(updated);
    if (!mounted) return;

    // Обновляем локальный снапшот (без setState — мы всё равно уходим со страницы)
    _contact = updated;

    // Выходим с результатом
    Navigator.pop(context, updated);

    showSuccessBanner('Изменения сохранены');
  }


  // Баннер с Undo — тот же, что в списке
  OverlaySupportEntry? _undoBanner;

  Future<void> _deleteWithUndo(Contact c) async {
    if (c.id == null) return;

    final db = ContactDatabase.instance;

    // Удаляем контакт и забираем снапшот заметок/напоминаний для возможного Undo
    final snapshot = await db.deleteContactWithSnapshot(c.id!);
    final notesSnapshot = snapshot.notes;
    final remindersSnapshot = snapshot.reminders;

    for (final reminder in remindersSnapshot) {
      final reminderId = reminder.id;
      if (reminderId != null) {
        await PushNotifications.cancel(reminderId);
      }
    }

    // Показываем баннер с Undo
    _undoBanner?.dismiss();
    const duration = Duration(seconds: 4);
    _undoBanner = showUndoBanner(
      message: 'Контакт удалён',
      duration: duration,
      icon: Icons.delete_outline,
      onUndo: () async {
        _undoBanner = null;
        final newId = await db.restoreContactWithNotes(
          c.copyWith(id: null),
          notesSnapshot,
          remindersSnapshot,
        );

        // Сообщаем открытому списку: локально добавить и подсветить (без автоскролла)
        ContactListScreen.notifyRestoredIfMounted(c, newId);

        // Возвращаем напоминания
        final restoredReminders = await db.remindersByContact(newId);
        for (final reminder in restoredReminders) {
          if (reminder.remindAt.isAfter(DateTime.now()) && reminder.id != null) {
            await PushNotifications.scheduleOneTime(
              id: reminder.id!,
              whenLocal: reminder.remindAt,
              title: 'Напоминание: ${c.name}',
              body: reminder.text,
            );
          }
        }

        showSystemNotification(
          'Контакт восстановлен',
          style: SystemNotificationStyle.success,
          iconOverride: Icons.undo,
        );
      },
    );

    // Закрываем экран деталей и пробрасываем инфо об удалении
    if (mounted) Navigator.pop(context, {'deletedId': c.id});
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
        bool forceFloatingLabel = false, // <<< НОВОЕ: принудительно держать метку сверху
      }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior:
      forceFloatingLabel ? FloatingLabelBehavior.always : FloatingLabelBehavior.auto,
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          onExpansionChanged: onChanged,
          maintainState: true,

          // ← стрелка теперь внутри заголовка
          title: Row(
            mainAxisSize: MainAxisSize.min,
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

          // ← а actions (например «Все заметки») идут справа
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: headerActions,
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
    bool forceFloatingLabel = false,
    Widget? prefix, // ← ДОБАВЛЕНО
  }) {
    final dec = _outlinedDec(
      Theme.of(context),
      label: title,
      hint: hint,
      prefixIcon: null, // базовый не даём — переопределим ниже
      controller: controller,
      suffixIcon: Icon(isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down),
      showClear: false,
      requiredField: requiredField,
      forceFloatingLabel: forceFloatingLabel,
    ).copyWith(
      // если передан кастомный, используем его, иначе — обычный Icon(icon)
      prefixIcon: prefix ?? Icon(icon),
    );

    return TextFormField(
      key: key,
      controller: controller,
      readOnly: true,
      focusNode: focusNode,
      decoration: dec,
      onTap: () {
        FocusScope.of(context).requestFocus(focusNode);
        onTap();
      },
    );
  }


  Widget _socialPickerField() {
    final value = _socialController.text;
    final t = (_socialType ?? value).trim();
    final forceTop = t.isEmpty; // <<< верхний хинт показываем, если не выбрано
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
        forceFloatingLabel: forceTop,
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

    // вычисления для верхнего хинта у категории/статуса
    final _categoryEmpty = (_category ?? _categoryController.text.trim()).isEmpty;
    final _statusEmpty = (_status ?? _statusController.text.trim()).isEmpty;
    final catValue = (_category ?? _categoryController.text.trim());
    final statusValue = (_status ?? _statusController.text.trim());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface, // фиксированный фон
        elevation: 0,                      // без обычной тени
        shadowColor: Colors.transparent,   // на всякий
        scrolledUnderElevation: 0,         // отключить подъём при скролле
        surfaceTintColor: Colors.transparent, // убрать M3-тонку
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
                    icon: _categoryIcon(catValue),            // базовая, на всякий случай
                    title: 'Категория*',
                    controller: _categoryController,
                    hint: 'Выберите категорию',
                    isOpen: _categoryOpen,
                    focusNode: _focusCategory,
                    onTap: _pickCategory,
                    requiredField: true,
                    forceFloatingLabel: _categoryEmpty,
                    prefix: Icon(_categoryIcon(catValue)),    // ← ДИНАМИЧЕСКАЯ ИКОНКА
                  ),
                  const SizedBox(height: 12),
                  _pickerField(
                    key: _statusKey,
                    icon: _statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
                    title: 'Статус*',
                    controller: _statusController,
                    hint: (_category ?? '').isEmpty ? 'Сначала выберите категорию' : 'Выберите статус',
                    isOpen: _statusOpen,
                    focusNode: _focusStatus,
                    onTap: _pickStatus,
                    requiredField: true,
                    forceFloatingLabel: _statusEmpty,
                    prefix: Icon(
                      _statusIcon(statusValue.isEmpty ? 'Статус' : statusValue),
                      color: statusValue.isEmpty
                          ? Theme.of(context).hintColor
                          : _statusColor(statusValue),
                    ),
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
                    // Дата рождения / возраст — ВЕРХНИЙ хинт ВСЕГДА + внутренний хинт
                    _pickerField(
                      key: const ValueKey('birth'),
                      icon: Icons.cake_outlined,
                      title: 'Дата рождения / возраст',
                      controller: _birthController,
                      hint: 'Указать дату или возраст',
                      isOpen: _birthOpen,
                      focusNode: _focusBirth,
                      onTap: _pickBirthOrAge,
                      forceFloatingLabel: true, // <<< всегда сверху
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

                    // Соцсеть — верхний хинт показываем, если пусто
                    _socialPickerField(),
                  ],
                ),
              ),

              // ===== Блок: Напоминания =====
              KeyedSubtree(
                key: _remindersCardKey,
                child: _collapsibleSectionCard(
                  title: 'Напоминания',
                  expanded: _remindersExpanded,
                  onChanged: (v) {
                    setState(() => _remindersExpanded = v);
                    if (v) _scrollToCard(_remindersCardKey);
                  },
                  headerActions: [
                    IconButton(
                      onPressed: _contact.id == null ? null : _addReminder,
                      tooltip: 'Добавить напоминание',
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                  children: [
                    if (_contact.id == null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active_outlined,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Сохраните контакт, чтобы добавлять напоминания',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Center(
                        child: ToggleButtons(
                          isSelected: [
                            _selectedRemindersTab == 0,
                            _selectedRemindersTab == 1,
                          ],
                          borderRadius: BorderRadius.circular(20),
                          constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
                          onPressed: (index) {
                            setState(() => _selectedRemindersTab = index);
                          },
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Активные'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Завершённые'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final isCompletedTab = _selectedRemindersTab == 1;
                          final reminders =
                              isCompletedTab ? _completedReminders : _activeReminders;
                          final emptyText = isCompletedTab
                              ? 'Нет завершённых напоминаний'
                              : 'Нет активных напоминаний';

                          if (reminders.isEmpty)
                            return Card(
                              elevation: 0,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 32, 24, 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.notifications_active_outlined,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      emptyText,
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );

                          return Card(
                            elevation: 0,
                            child: Column(
                              children: [
                                for (var i = 0; i < reminders.length; i++) ...[
                                  _reminderTile(
                                    reminders[i],
                                    completed: isCompletedTab,
                                  ),
                                  if (i != reminders.length - 1)
                                    const Divider(height: 0),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
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
                    TextButton(
                      onPressed: _contact.id == null
                          ? null
                          : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotesListScreen(
                              contact: _contact,
                              onNoteRestored: (_) => _loadNotes(),
                            ),
                          ),
                        );
                        await _loadNotes();
                      },
                      child: const Text('Все заметки'),
                    ),
                  ],
                  children: _notes.isEmpty
                      ? [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Нет заметок',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _contact.id == null ? null : _addNote,
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить заметку'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                      : [
                    Card(
                      elevation: 0,
                      child: Column(
                        children: [
                          for (var i = 0; i < _notes.length; i++)
                            _noteRow(_notes[i], isLast: i == _notes.length - 1),
                        ],
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
                    forceFloatingLabel: _addedController.text.trim().isEmpty,
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
