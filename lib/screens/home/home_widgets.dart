part of home_screen;

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          children: [
            Icon(Icons.person_off, size: 40),
            kGap8,
            Text(R.noContacts),
            kGap8,
            Text(
              R.emptyStateHelp,
              textAlign: TextAlign.center,
            ),
            kGap8,
            _AddContactButton(),
          ],
        ),
      ),
    );
  }
}

class _AddContactButton extends StatelessWidget {
  const _AddContactButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        final state = context.findAncestorStateOfType<_HomeScreenState>();
        state?._openAddContact();
      },
      icon: const Icon(Icons.person_add),
      label: const Text(R.addContact),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int knownTotal;
  final int unknownCount;

  const _SummaryCard({
    required this.knownTotal,
    required this.unknownCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final hasUnknown = unknownCount > 0;

    return Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(R.summaryTitle, style: textTheme.titleMedium),
            kGap8,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        R.summaryKnownLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homeNumberFormat.format(knownTotal),
                        style: textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (hasUnknown)
                  Semantics(
                    label: 'Есть неизвестные категории',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Icon(
                        Icons.info_outline,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            kGap8,
            Text(
              hasUnknown
                  ? R.summaryUnknown(unknownCount)
                  : R.summaryAllKnown,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  final Future<void> Function()? onRetry;
  const _ErrorCard({super.key, required this.onRetry});

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final onRetry = widget.onRetry;
    return Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(R.loadError, style: TextStyle(fontWeight: FontWeight.w600)),
            kGap8,
            const Text(R.checkNetwork),
            kGap8,
            FilledButton.icon(
              onPressed: _busy || onRetry == null
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await onRetry();
                      if (mounted) setState(() => _busy = false);
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_busy ? R.loading : R.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ContactCategory category;
  final String subtitle;
  final String? trailingCount;
  final VoidCallback onTap;
  final bool isLoading;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.subtitle,
    required this.onTap,
    required this.trailingCount,
    this.isLoading = false,
  });

  const _CategoryCard.loading({super.key, required ContactCategory category})
      : category = category,
        subtitle = R.loading,
        trailingCount = null,
        onTap = _noop,
        isLoading = true;

  static void _noop() {}

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.isLoading || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoading = widget.isLoading;

    Widget leadingIcon =
        Icon(widget.category.icon, size: 32, color: colorScheme.primary);

    if (!isLoading) {
      leadingIcon = Hero(
        tag: 'cat:${widget.category.dbKey}',
        transitionOnUserGestures: true,
        flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
          return ScaleTransition(
            scale: anim
                .drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut))),
            child: Icon(widget.category.icon, size: 32, color: colorScheme.primary),
          );
        },
        child: leadingIcon,
      );
    }

    final String? countStr = widget.trailingCount;
    final bool isUnknown = countStr == '—';

    final Widget trailingContent = countStr == null
        ? const Icon(Icons.chevron_right)
        : Row(
            key: ValueKey(countStr),
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: isUnknown
                    ? 'Количество неизвестно — данные обновятся автоматически'
                    : '${R.qtyLabel}: $countStr',
                child: Semantics(
                  label:
                      '${widget.category.titlePlural}: ${R.qtyLabel.toLowerCase()}',
                  value: isUnknown ? R.unknown : countStr,
                  hint: '${R.chipHintOpenList}: ${widget.category.titlePlural}',
                  child: Chip(
                    label: Text(
                      countStr,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: isUnknown
                        ? colorScheme.surfaceVariant
                        : colorScheme.primaryContainer,
                    side: BorderSide(
                      color: isUnknown
                          ? colorScheme.outline
                          : colorScheme.outlineVariant,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          );

    return Semantics(
      button: true,
      label: widget.category.titlePlural,
      value: widget.subtitle,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: kDurTap,
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          elevation: 2,
          borderRadius: kBr16,
          clipBehavior: Clip.antiAlias,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              focusColor: kIsWeb ? theme.focusColor : Colors.transparent,
              hoverColor: kIsWeb ? theme.hoverColor : Colors.transparent,
              borderRadius: kBr16,
              canRequestFocus: !isLoading,
              onTap: isLoading
                  ? null
                  : () {
                      if (!kIsWeb) HapticFeedback.selectionClick();
                      widget.onTap();
                    },
              onTapDown: (_) => _setPressed(true),
              onTapCancel: () => _setPressed(false),
              onTapUp: (_) => _setPressed(false),
              child: Padding(
                padding: kPad16,
                child: Row(
                  children: [
                    leadingIcon,
                    kGap16w,
                    Expanded(
                      child: _TitleAndSubtitle(
                        title: widget.category.titlePlural,
                        subtitle: widget.subtitle,
                        isLoading: isLoading,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: kDurFast,
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: trailingContent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleAndSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLoading;

  const _TitleAndSubtitle({
    required this.title,
    required this.subtitle,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(widthFactor: 0.5),
          kGap6,
          _SkeletonLine(widthFactor: 0.35),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: kDurFast,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
