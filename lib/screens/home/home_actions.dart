part of home_screen;

class HomeActions {
  const HomeActions();

  Future<void> openSupport(BuildContext context) async {
    const group = 'touchnotebook';
    final tgUri = Uri.parse('tg://resolve?domain=$group');
    final webUri = Uri.parse('https://t.me/$group');
    try {
      if (kIsWeb) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
        return;
      }
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        showWarningBanner(R.telegramNotInstalled);
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      debugPrint('openSupport error: $e\n$s');
      showErrorBanner(R.telegramOpenFailed);
      await Clipboard.setData(
        const ClipboardData(text: 'https://t.me/touchnotebook'),
      );
      showInfoBanner(R.linkCopied);
    }
  }

  Future<void> openAddContact(BuildContext context) async {
    if (!kIsWeb) HapticFeedback.selectionClick();
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );
    if (saved == true) {
      showSuccessBanner(R.contactSaved);
    }
  }

  void openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void openCategoryList(BuildContext context, ContactCategory category) {
    if (!kIsWeb) HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactListScreen(
          category: category.dbKey,
          title: category.titlePlural,
        ),
      ),
    );
  }
}
