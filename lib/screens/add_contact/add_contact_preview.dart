part of add_contact_screen;

class AddContactPreview extends StatelessWidget {
  final AddContactFormController controller;
  const AddContactPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewCaption(controller: controller),
        const SizedBox(height: 8),
        _PreviewCard(controller: controller),
      ],
    );
  }
}

class _PreviewCaption extends StatelessWidget {
  final AddContactFormController controller;
  const _PreviewCaption({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = 'Предпросмотр карточки';
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
}

class _PreviewCard extends StatelessWidget {
  final AddContactFormController controller;
  const _PreviewCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    const double statusReserve = 120;
    final scheme = Theme.of(context).colorScheme;
    final name = controller.nameController.text.trim().isEmpty
        ? 'Новый контакт'
        : controller.nameController.text.trim();
    final statusValue = (controller.status ?? controller.statusController.text).trim();
    final statusText = statusValue.isEmpty ? 'Статус' : statusValue;
    final statusBg =
        statusValue.isEmpty ? Colors.grey : controller.statusColor(statusValue);
    final onStatus = controller.onStatus(statusBg);
    final tags = controller.tags.toList();

    Widget avatar() {
      final bg = controller.avatarBgFor(name, scheme);
      final initials = controller.initials(name);
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
      label:
          'Превью контакта. Имя: $name. Статус: $statusText. Телефон: ${controller.previewPhoneMasked()}.',
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
                padding: const EdgeInsets.only(right: statusReserve),
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
                      controller.previewPhoneMasked(),
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
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: controller.tagTextColor(tag),
                                    ),
                              ),
                              backgroundColor: controller.tagColor(tag),
                              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10, color: onStatus),
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
}
