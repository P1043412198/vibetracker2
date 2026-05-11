import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/ai_service.dart';
import '../../services/backup_service.dart';
import '../../services/storage.dart';
import '../../state/settings_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(defaultCurrencyProvider);
    final overrideLocale = ref.watch(localeProvider);
    final pinLock = ref.watch(pinLockProvider);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(t.navSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(t.settingsAppearance,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(t.settingsThemeAuto),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(t.settingsThemeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(t.settingsThemeDark),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(t.settingsLanguage),
                  subtitle: Text(_localeLabel(overrideLocale, t)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final entries = <_LocaleOption>[
                      _LocaleOption(null, t.settingsLanguageSystem),
                      _LocaleOption(
                          const Locale('ru'), t.settingsLanguageRu),
                      _LocaleOption(
                          const Locale('be'), t.settingsLanguageBe),
                      _LocaleOption(
                          const Locale('en'), t.settingsLanguageEn),
                    ];
                    final picked = await showModalBottomSheet<_LocaleOption>(
                      context: context,
                      builder: (sheetContext) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final e in entries)
                              ListTile(
                                title: Text(e.label),
                                selected: e.locale?.languageCode ==
                                    overrideLocale?.languageCode,
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(e),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (picked != null) {
                      await ref
                          .read(localeProvider.notifier)
                          .set(picked.locale);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_customize_outlined),
                  title: Text(t.settingsConfigureDashboard),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/dashboard-settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.settingsSecurity,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                pinLock.hasPin ? Icons.lock : Icons.lock_open_outlined,
                color: pinLock.hasPin
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(pinLock.hasPin ? t.pinChange : t.pinSet),
              subtitle: Text(
                  pinLock.hasPin ? t.settingsPinSet : t.settingsPinNotSet),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/pin-setup'),
            ),
          ),
          const SizedBox(height: 24),
          Text(t.settingsFinance, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: Text(t.settingsDefaultCurrency),
                  subtitle: Text(currency),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final next = await showModalBottomSheet<String>(
                      context: context,
                      builder: (sheetContext) {
                        const options = [
                          'BYN',
                          'USD',
                          'EUR',
                          'RUB',
                          'PLN',
                          'USDT'
                        ];
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: options
                                .map(
                                  (c) => ListTile(
                                    title: Text(c),
                                    selected: c == currency,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(c),
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
                    );
                    if (next != null) {
                      ref.read(defaultCurrencyProvider.notifier).state = next;
                      await AppStorage.writeString('defaultCurrency', next);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.settingsAi,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _AiEnabledTile(),
                const Divider(height: 1),
                _GeminiKeyTile(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(t.settingsData, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          const _BackupReminderBanner(),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Экспорт всех данных (ZIP)'),
                  subtitle: const Text(
                      'Полный бэкап: финансы, привычки, инбокс с картинками/видео, фото целей, чеки.'),
                  onTap: () async {
                    try {
                      final path = await BackupService.exportToFile();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Файл сохранён: $path')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Не удалось экспортировать: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Импорт из бэкапа (ZIP / JSON)'),
                  subtitle: const Text(
                      'Восстановить из резервной копии. ZIP вернёт и медиа, старый JSON — только данные.'),
                  onTap: () async {
                    final mode = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Импорт данных'),
                        content: const Text(
                            'Выбери, как обработать существующие данные. «Заменить» сначала удалит всё, «Слить» — наложит файл поверх (одинаковые ID будут перезаписаны).'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Отмена')),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Слить')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Заменить')),
                        ],
                      ),
                    );
                    if (mode == null) return;
                    try {
                      final n = await BackupService.importFromFile(
                          replace: mode);
                      if (n == null) return;
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Импортировано $n разделов. Перезапусти приложение.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Не удалось импортировать: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: Color(0xFFEF4444)),
                  title: Text(t.settingsDeleteAll),
                  subtitle: Text(t.settingsDeleteAllSubtitle),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('${t.settingsDeleteAll}?'),
                        content: Text(t.settingsDeleteAllSubtitle),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(t.commonCancel),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(t.commonDelete),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await AppStorage.box.clear();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Все данные удалены. Перезапусти приложение, чтобы увидеть пустое состояние.')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vibesight Tracker · Flutter port',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Полный план миграции с React+Capacitor описан в MIGRATION_PLAN.md в корне репозитория.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _localeLabel(Locale? locale, AppLocalizations t) {
  if (locale == null) return t.settingsLanguageSystem;
  switch (locale.languageCode) {
    case 'ru':
      return t.settingsLanguageRu;
    case 'be':
      return t.settingsLanguageBe;
    case 'en':
      return t.settingsLanguageEn;
  }
  return locale.languageCode;
}

class _LocaleOption {
  const _LocaleOption(this.locale, this.label);
  final Locale? locale;
  final String label;
}

class _AiEnabledTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(aiEnabledProvider);
    final hasKey = (ref.watch(geminiKeyProvider) ?? '').isNotEmpty;
    return SwitchListTile(
      secondary: Icon(
        Icons.auto_awesome,
        color: enabled && hasKey
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      title: const Text('AI-функции'),
      subtitle: Text(
        hasKey
            ? (enabled
                ? 'Классификатор, финкоуч, парсер чеков, сводки'
                : 'Выключены — AI не вызывается')
            : 'Задай ключ Gemini ниже',
      ),
      value: enabled && hasKey,
      onChanged: hasKey
          ? (v) => ref.read(aiEnabledProvider.notifier).set(v)
          : null,
    );
  }
}

class _GeminiKeyTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_GeminiKeyTile> createState() => _GeminiKeyTileState();
}

class _GeminiKeyTileState extends ConsumerState<_GeminiKeyTile> {
  late final TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: AiService.apiKey ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(geminiKeyProvider);
    final hasKey = stored != null && stored.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasKey ? 'Ключ сохранён' : 'Ключ Gemini API не задан',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hasKey
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Используется для AI-функций: классификатор инбокса, финкоуч, парсер '
            'чеков, сводки по сферам. Ключ хранится локально (Hive). '
            'Получить: aistudio.google.com/apikey',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'GEMINI_API_KEY',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: () async {
                    await ref
                        .read(geminiKeyProvider.notifier)
                        .save(_ctrl.text);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Ключ сохранён')),
                    );
                  },
                  label: const Text('Сохранить'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.delete_outline),
                onPressed: hasKey
                    ? () async {
                        _ctrl.clear();
                        await ref
                            .read(geminiKeyProvider.notifier)
                            .save(null);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackupReminderBanner extends StatefulWidget {
  const _BackupReminderBanner();

  @override
  State<_BackupReminderBanner> createState() => _BackupReminderBannerState();
}

class _BackupReminderBannerState extends State<_BackupReminderBanner> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final last = BackupService.lastExportAt();
    final now = DateTime.now();
    final daysSince = last == null ? null : now.difference(last).inDays;
    final overdue = daysSince == null || daysSince >= 14;

    final scheme = Theme.of(context).colorScheme;
    final cs = overdue ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = overdue ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    final String headline;
    final String subline;
    if (last == null) {
      headline = 'Сделай первый бэкап';
      subline =
          'Если телефон сломается или приложение удалится, без бэкапа данные пропадут.';
    } else if (overdue) {
      headline = 'Последний бэкап $daysSince дн. назад';
      subline = 'Стоит сделать новый — добавь привычку раз в 1–2 недели.';
    } else {
      headline = 'Бэкап в порядке';
      subline = 'Последний экспорт $daysSince дн. назад.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: cs,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.verified_outlined,
            color: fg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
                if (subline.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subline,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: fg.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await BackupService.exportToFile();
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Бэкап не удался: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сейчас'),
          ),
        ],
      ),
    );
  }
}
