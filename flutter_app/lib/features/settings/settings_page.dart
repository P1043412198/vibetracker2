import '../../widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/backup_service.dart';
import '../../services/claude_service.dart';
import '../../services/storage.dart';
import '../../state/providers.dart';
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
        leading: const AppBackButton(),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _ClaudeDataAccessBanner(),
          const SizedBox(height: 8),
          Card(
            child: _ClaudeKeyTile(),
          ),
          const SizedBox(height: 8),
          Card(
            child: _ClaudeToolsToggleTile(),
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
          Text('Сброс статистики',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: const Text('Сбросить статистику тренировок'),
                  subtitle: const Text(
                      'Очистит журнал подходов (аналитика, объём, рекорды). Программы, цели, замеры и фото останутся.'),
                  onTap: () => _confirmReset(
                    context,
                    title: 'Сбросить статистику тренировок?',
                    body:
                        'Будет удалён весь журнал подходов. Это действие необратимо. Программы, цели, замеры и фото прогресса сохранятся.',
                    onConfirm: () async {
                      await ref
                          .read(exerciseLogsProvider.notifier)
                          .replaceAll(const []);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Сбросить статистику привычек'),
                  subtitle: const Text(
                      'Очистит отметки выполнения и серии. Сами привычки останутся.'),
                  onTap: () => _confirmReset(
                    context,
                    title: 'Сбросить статистику привычек?',
                    body:
                        'Будут удалены все отметки выполнения и серии (стрики). Список привычек сохранится.',
                    onConfirm: () async {
                      await ref
                          .read(habitLogsProvider.notifier)
                          .replaceAll(const []);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.checklist_outlined),
                  title: const Text('Сбросить статистику задач'),
                  subtitle: const Text(
                      'Снимет отметку «выполнено» со всех задач. Сами задачи останутся.'),
                  onTap: () => _confirmReset(
                    context,
                    title: 'Сбросить статистику задач?',
                    body:
                        'Со всех задач будет снята отметка «выполнено». Задачи не удаляются.',
                    onConfirm: () async {
                      final notifier = ref.read(tasksProvider.notifier);
                      final reset = ref
                          .read(tasksProvider)
                          .map((t) => t.completed
                              ? t.copyWith(completed: false)
                              : t)
                          .toList();
                      await notifier.replaceAll(reset);
                    },
                  ),
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

  Future<void> _confirmReset(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await onConfirm();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статистика сброшена.')),
      );
    }
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
    final hasKey = (ref.watch(claudeKeyProvider) ?? '').isNotEmpty;
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
                ? 'Классификатор инбокса, финкоуч, парсер чеков, сводки'
                : 'Выключены — AI не вызывается')
            : 'Задай ключ Claude ниже',
      ),
      value: enabled && hasKey,
      onChanged: hasKey
          ? (v) => ref.read(aiEnabledProvider.notifier).set(v)
          : null,
    );
  }
}

/// Warning banner shown in Settings so the user understands that enabling
/// Claude tools gives the assistant full read/write access to all of their
/// app data. Visible right above the Claude key tile.
class _ClaudeDataAccessBanner extends ConsumerWidget {
  const _ClaudeDataAccessBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final toolsOn = ref.watch(claudeToolsEnabledProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: toolsOn
            ? scheme.tertiaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                toolsOn
                    ? Icons.shield_outlined
                    : Icons.lock_outline,
                size: 18,
                color: toolsOn
                    ? scheme.onTertiaryContainer
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toolsOn
                      ? 'Claude управляет приложением'
                      : 'Claude отвечает только текстом',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: toolsOn
                        ? scheme.onTertiaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            toolsOn
                ? 'У Claude есть полный доступ к чтению и записи всех твоих '
                    'данных: задачи, привычки, финансы (включая транзакции '
                    'и кредиты), цели, тренировки, сон, вода, сферы и '
                    'заметки. Он может создавать, изменять и удалять записи '
                    'из чата. Отключить можно тумблером ниже.'
                : 'Tool-use выключен — Claude видит только то, что ты пишешь '
                    'в чате, и НЕ имеет доступа к локальным данным.',
            style: TextStyle(
              fontSize: 12,
              color: toolsOn
                  ? scheme.onTertiaryContainer.withValues(alpha: 0.92)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle that turns the entire tool-use system on/off. When off the chat
/// behaves like a plain LLM conversation (no CRUD against local data).
class _ClaudeToolsToggleTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(claudeToolsEnabledProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.bolt_outlined),
      title: const Text('Разрешить Claude управлять приложением'),
      subtitle: const Text(
        'Tool-use: задачи, привычки, финансы, цели, тренировки, сон, вода, '
        'сферы и заметки. По умолчанию включено.',
      ),
      value: enabled,
      onChanged: (v) =>
          ref.read(claudeToolsEnabledProvider.notifier).set(v),
    );
  }
}

class _ClaudeKeyTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ClaudeKeyTile> createState() => _ClaudeKeyTileState();
}

class _ClaudeKeyTileState extends ConsumerState<_ClaudeKeyTile> {
  late final TextEditingController _ctrl;
  late final TextEditingController _systemCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ClaudeService.apiKey ?? '');
    _systemCtrl = TextEditingController(text: ClaudeService.systemPrompt);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _systemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(claudeKeyProvider);
    final hasKey = stored != null && stored.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  color: hasKey
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasKey
                      ? 'Ключ Claude сохранён'
                      : 'Ключ Anthropic Claude не задан',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: hasKey
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Открыть чат'),
                onPressed: hasKey ? () => context.go('/chat') : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Используется чатом с Claude. Ключ хранится локально (Hive) и '
            'отправляется напрямую на api.anthropic.com. '
            'Получить: console.anthropic.com → Settings → API Keys.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'CLAUDE_API_KEY',
              hintText: 'sk-ant-…',
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
                        .read(claudeKeyProvider.notifier)
                        .save(_ctrl.text);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ключ сохранён')),
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
                            .read(claudeKeyProvider.notifier)
                            .save(null);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _ClaudeModelPicker(),
          const SizedBox(height: 12),
          _ClaudeBaseUrlField(),
          const SizedBox(height: 12),
          TextField(
            controller: _systemCtrl,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'System prompt',
              helperText: 'Тон ответов Claude. Можно оставить по умолчанию.',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Сбросить prompt'),
                  onPressed: () async {
                    await ClaudeService.setSystemPrompt(null);
                    if (!mounted) return;
                    setState(() {
                      _systemCtrl.text = ClaudeService.systemPrompt;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.check),
                  label: const Text('Сохранить prompt'),
                  onPressed: () async {
                    await ClaudeService.setSystemPrompt(_systemCtrl.text);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('System prompt обновлён')),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClaudeBaseUrlField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ClaudeBaseUrlField> createState() =>
      _ClaudeBaseUrlFieldState();
}

class _ClaudeBaseUrlFieldState extends ConsumerState<_ClaudeBaseUrlField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final stored = ClaudeService.baseUrl;
    // Hide the default value so the field reads "empty = default", which
    // matches user expectations and avoids a wall of placeholder text.
    _ctrl = TextEditingController(
        text: stored == ClaudeService.defaultBaseUrl ? '' : stored);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(claudeBaseUrlProvider);
    final isDefault = current == ClaudeService.defaultBaseUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Base URL (proxy)',
            hintText: ClaudeService.defaultBaseUrl,
            helperText: isDefault
                ? 'По умолчанию запросы идут на api.anthropic.com. '
                    'Если ловишь HTTP 403 — пропиши сюда свой прокси '
                    '(Cloudflare Worker / nginx) — он будет проксировать на '
                    'api.anthropic.com.'
                : 'Сейчас запросы идут через ваш прокси.',
            helperMaxLines: 4,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить URL'),
                onPressed: () async {
                  await ref
                      .read(claudeBaseUrlProvider.notifier)
                      .save(_ctrl.text);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Base URL: ${ClaudeService.resolvedEndpoint}')),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Сбросить на api.anthropic.com',
              onPressed: !isDefault
                  ? () async {
                      _ctrl.clear();
                      await ref
                          .read(claudeBaseUrlProvider.notifier)
                          .save(null);
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ClaudeModelPicker extends ConsumerStatefulWidget {
  const _ClaudeModelPicker();

  @override
  ConsumerState<_ClaudeModelPicker> createState() =>
      _ClaudeModelPickerState();
}

class _ClaudeModelPickerState extends ConsumerState<_ClaudeModelPicker> {
  @override
  Widget build(BuildContext context) {
    final current = ref.watch(claudeModelProvider);
    final items = {...ClaudeService.availableModels, current}.toList();
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Модель Claude',
        border: OutlineInputBorder(),
        helperText:
            'По умолчанию claude-3-5-sonnet-latest. Anthropic иногда меняет '
            'имена моделей — обнови если ловишь 404.',
        helperMaxLines: 3,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: current,
          items: [
            for (final m in items)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) async {
            if (v == null) return;
            final messenger = ScaffoldMessenger.of(context);
            await ref.read(claudeModelProvider.notifier).save(v);
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text('Модель: $v')),
            );
          },
        ),
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
