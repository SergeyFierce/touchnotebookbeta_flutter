part of add_contact_screen;

class AddContactFormController extends ChangeNotifier {
  AddContactFormController({String? initialCategory}) {
    if (initialCategory != null) {
      _category = initialCategory;
      categoryController.text = initialCategory;
    }
    _addedDate = DateTime.now();
    addedController.text = DateFormat('dd.MM.yyyy').format(_addedDate);
    _attachListeners();
  }

  final formKey = GlobalKey<FormState>();
  final scrollController = ScrollController();

  final GlobalKey nameKey = GlobalKey();
  final GlobalKey phoneKey = GlobalKey();
  final GlobalKey categoryKey = GlobalKey();
  final GlobalKey statusKey = GlobalKey();
  final GlobalKey addedKey = GlobalKey();
  final GlobalKey extraCardKey = GlobalKey();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthController = TextEditingController();
  final TextEditingController professionController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController socialController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController addedController = TextEditingController();

  final FocusNode focusBirth = FocusNode(skipTraversal: true);
  final FocusNode focusSocial = FocusNode(skipTraversal: true);
  final FocusNode focusCategory = FocusNode(skipTraversal: true);
  final FocusNode focusStatus = FocusNode(skipTraversal: true);
  final FocusNode focusAdded = FocusNode(skipTraversal: true);

  final MaskTextInputFormatter phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {'#': RegExp(r'[0-9]')},
  );

  bool submitted = false;
  bool saving = false;

  DateTime? _birthDate;
  int? _ageManual;
  String? _category;
  String? _status;
  DateTime _addedDate = DateTime.now();
  final Set<String> _tags = <String>{};

  bool birthOpen = false;
  bool socialOpen = false;
  bool categoryOpen = false;
  bool statusOpen = false;
  bool addedOpen = false;
  bool extraExpanded = false;

  DateTime? get birthDate => _birthDate;
  int? get ageManual => _ageManual;
  String? get category => _category;
  String? get status => _status;
  DateTime get addedDate => _addedDate;
  Set<String> get tags => _tags;

  bool get phoneValid => phoneMask.getUnmaskedText().length == 10;

  bool get canSave =>
      nameController.text.trim().isNotEmpty &&
      phoneValid &&
      _category != null &&
      _status != null &&
      addedController.text.trim().isNotEmpty &&
      !saving;

  void _attachListeners() {
    final listeners = [
      nameController,
      phoneController,
      emailController,
      professionController,
      cityController,
      commentController,
      socialController,
      categoryController,
      statusController,
      addedController,
      birthController,
    ];
    for (final c in listeners) {
      c.addListener(notifyListeners);
    }

    focusCategory.addListener(notifyListeners);
    focusStatus.addListener(notifyListeners);
    focusSocial.addListener(notifyListeners);
    focusBirth.addListener(notifyListeners);
    focusAdded.addListener(notifyListeners);
  }

  Future<void> scrollToCard(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  void setSubmitted(bool value) {
    if (submitted == value) return;
    submitted = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    if (saving == value) return;
    saving = value;
    notifyListeners();
  }

  void setBirthOpen(bool value) {
    if (birthOpen == value) return;
    birthOpen = value;
    notifyListeners();
  }

  void setSocialOpen(bool value) {
    if (socialOpen == value) return;
    socialOpen = value;
    notifyListeners();
  }

  void setCategoryOpen(bool value) {
    if (categoryOpen == value) return;
    categoryOpen = value;
    notifyListeners();
  }

  void setStatusOpen(bool value) {
    if (statusOpen == value) return;
    statusOpen = value;
    notifyListeners();
  }

  void setAddedOpen(bool value) {
    if (addedOpen == value) return;
    addedOpen = value;
    notifyListeners();
  }

  void toggleExtraExpanded() {
    setExtraExpanded(!extraExpanded);
  }

  void setExtraExpanded(bool value) {
    if (extraExpanded == value) return;
    extraExpanded = value;
    notifyListeners();
  }

  void setBirthDate(DateTime? value) {
    _birthDate = value;
    if (value != null) {
      final formatted = DateFormat('dd.MM.yyyy').format(value);
      final age = calcAge(value);
      birthController.text = '$formatted (${formatAge(age)})';
      _ageManual = null;
    } else {
      birthController.clear();
    }
    notifyListeners();
  }

  void setAgeManual(int? value) {
    _ageManual = value;
    if (value != null) {
      birthController.text = 'Возраст: ${formatAge(value)}';
      _birthDate = null;
    } else {
      birthController.clear();
    }
    notifyListeners();
  }

  void setCategory(String? value) {
    _category = value;
    categoryController.text = value ?? '';
    notifyListeners();
  }

  void setStatus(String? value) {
    _status = value;
    statusController.text = value ?? '';
    notifyListeners();
  }

  void updateAddedDate(DateTime value) {
    _addedDate = value;
    addedController.text = DateFormat('dd.MM.yyyy').format(value);
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_tags.contains(tag)) {
      _tags.remove(tag);
    } else {
      _tags.add(tag);
    }
    notifyListeners();
  }

  String previewPhoneMasked() {
    final digits = phoneMask.getUnmaskedText();
    const mask = '+7 (XXX) XXX-XX-XX';
    final buf = StringBuffer();
    var di = 0;
    for (var i = 0; i < mask.length; i++) {
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

  int calcAge(DateTime birth) {
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  String formatAge(int age) {
    final lastTwo = age % 100;
    final last = age % 10;
    if (lastTwo >= 11 && lastTwo <= 14) return '$age лет';
    if (last == 1) return '$age год';
    if (last >= 2 && last <= 4) return '$age года';
    return '$age лет';
  }

  String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.take(1).toString();
    final second = parts[1].characters.take(1).toString();
    return (first + second).toUpperCase();
  }

  Color avatarBgFor(String seed, ColorScheme scheme) {
    var h = 0;
    for (final r in seed.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55);
    return hsl.toColor();
  }

  IconData statusIcon(String status) {
    switch (status) {
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

  IconData categoryIcon(String? category) {
    switch (category) {
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

  Color statusColor(String status) {
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

  Color onStatus(Color bg) {
    final brightness = bg.computeLuminance();
    return brightness > 0.5 ? Colors.black : Colors.white;
  }

  Color tagColor(String tag) {
    switch (tag) {
      case 'Новый':
        return Colors.white;
      case 'Напомнить':
        return Colors.purple;
      case 'VIP':
        return Colors.yellow;
      default:
        return Colors.grey.shade200;
    }
  }

  Color tagTextColor(String tag) {
    switch (tag) {
      case 'Новый':
      case 'VIP':
        return Colors.black;
      case 'Напомнить':
        return Colors.white;
      default:
        return Colors.black;
    }
  }

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

  String brandAssetPath(String value) {
    final slug = _brandSlug[value];
    if (slug == null) return '';
    return 'assets/$slug.svg';
  }

  Widget brandIcon(String value, {double size = 24}) {
    final path = brandAssetPath(value);
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
  void dispose() {
    scrollController.dispose();
    nameController.dispose();
    birthController.dispose();
    professionController.dispose();
    cityController.dispose();
    phoneController.dispose();
    emailController.dispose();
    socialController.dispose();
    categoryController.dispose();
    statusController.dispose();
    commentController.dispose();
    addedController.dispose();

    focusBirth.dispose();
    focusSocial.dispose();
    focusCategory.dispose();
    focusStatus.dispose();
    focusAdded.dispose();
    super.dispose();
  }
}
