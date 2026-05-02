import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_service.dart';
import '../../services/storage.dart';
import '../../state/settings_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(defaultCurrencyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Внешний вид',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('Авто'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Светлая'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Тёмная'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (s) =>
                    ref.read(themeModeProvider.notifier).set(s.first),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Финансы', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Валюта по умолчанию'),
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
          Text('AI (Gemini)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: _GeminiKeyTile(),
          ),
          const SizedBox(height: 24),
          Text('Данные', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: Color(0xFFEF4444)),
                  title: const Text('Удалить все данные'),
                  subtitle: const Text(
                      'Сбрасывает локальное хранилище. Действие необратимо.'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Удалить все данные?'),
                        content: const Text(
                            'Все задачи, привычки, транзакции и прочие записи будут удалены безвозвратно.'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Удалить'),
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
            'Используется AI-генератором тренировок. Ключ хранится локально, '
            'на устройстве (Hive). Получить: aistudio.google.com/apikey',
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
