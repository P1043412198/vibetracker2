import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/claude_service.dart';
import '../../state/claude_chat_state.dart';

/// Full-screen chat with Claude.
///
/// User supplies their own Anthropic API key from Settings (or directly via
/// the inline banner shown when the key is missing). Conversation history is
/// stored locally in Hive — no server-side persistence.
class ClaudeChatPage extends ConsumerStatefulWidget {
  const ClaudeChatPage({super.key});

  @override
  ConsumerState<ClaudeChatPage> createState() => _ClaudeChatPageState();
}

class _ClaudeChatPageState extends ConsumerState<ClaudeChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(claudeChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(claudeChatProvider);
    final hasKey = ref.watch(claudeKeyProvider) != null;
    final model = ref.watch(claudeModelProvider);
    final scheme = Theme.of(context).colorScheme;

    ref.listen<ClaudeChatState>(claudeChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claude чат'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              switch (v) {
                case 'clear':
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Очистить чат?'),
                      content: const Text(
                          'Вся история диалога с Claude будет удалена. '
                          'Это действие не отменяется.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Очистить'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref.read(claudeChatProvider.notifier).clear();
                  }
                case 'settings':
                  if (mounted) context.go('/settings');
                case 'retry':
                  await ref.read(claudeChatProvider.notifier).retryLast();
                  _scrollToBottom();
              }
            },
            itemBuilder: (_) => [
              if (chat.messages.any((m) => m.isError))
                const PopupMenuItem(
                    value: 'retry',
                    child: ListTile(
                        leading: Icon(Icons.refresh),
                        title: Text('Повторить'),
                        contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'clear',
                  child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Очистить чат'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Настройки ключа'),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!hasKey) _NoKeyBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    chat.busy && chat.busyStatus != null
                        ? '$model — ${chat.busyStatus}'
                        : 'Модель: $model',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (chat.busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: chat.messages.isEmpty
                ? _EmptyState(onPickPreset: (q) {
                    _input.text = q;
                    _inputFocus.requestFocus();
                  })
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: chat.messages.length,
                    itemBuilder: (_, i) => _ChatBubble(
                      message: chat.messages[i],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _inputFocus,
                      enabled: !chat.busy,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: hasKey
                            ? 'Спроси Claude…'
                            : 'Сначала задайте API ключ в Настройках',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FloatingActionButton(
                    onPressed: (!hasKey || chat.busy) ? null : _send,
                    elevation: 0,
                    mini: true,
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    child: chat.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
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

class _NoKeyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      color: scheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.key_off_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API ключ Claude не задан',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer)),
                const SizedBox(height: 2),
                Text(
                  'Получить ключ: console.anthropic.com → Settings → API Keys',
                  style: TextStyle(
                      fontSize: 12,
                      color: scheme.onErrorContainer.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => context.go('/settings'),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPickPreset});
  final ValueChanged<String> onPickPreset;

  static const _presets = <String>[
    'Составь план тренировки на неделю под мою цель: похудеть 5 кг.',
    'Подскажи как откладывать 20% дохода — конкретный пошаговый план.',
    'Дай идеи новых полезных привычек на основе моих текущих.',
    'Помоги разбить большую задачу на подзадачи по методу SMART.',
    'Объясни сложный процент простыми словами и приведи пример.',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer,
                scheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: scheme.onPrimaryContainer, size: 22),
                  const SizedBox(width: 8),
                  Text('Поговори с Claude',
                      style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Личный коуч по финансам, спорту, привычкам и задачам. '
                'Ответы — прямо в этом чате. Ключ Anthropic API хранится только '
                'на устройстве.',
                style: TextStyle(
                    color:
                        scheme.onPrimaryContainer.withValues(alpha: 0.92)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Быстрые подсказки',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        for (final p in _presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onPickPreset(p),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p,
                            style: TextStyle(
                                fontSize: 13, color: scheme.onSurface)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ClaudeMessage message;

  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == 'user';
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = message.isError
        ? scheme.errorContainer
        : isUser
            ? scheme.primary
            : scheme.surfaceContainerHighest;
    final textColor = message.isError
        ? scheme.onErrorContainer
        : isUser
            ? scheme.onPrimary
            : scheme.onSurface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isUser ? 16 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 16),
    );
    DateTime? ts;
    try {
      ts = DateTime.parse(message.createdAt);
    } catch (_) {}
    final hasText = message.content.isNotEmpty;
    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (hasText)
                GestureDetector(
                  onLongPress: () async {
                    await Clipboard.setData(
                        ClipboardData(text: message.content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Сообщение скопировано')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: radius,
                    ),
                    child: SelectableText(
                      message.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              if (message.hasToolCalls)
                Padding(
                  padding: EdgeInsets.only(top: hasText ? 6 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final t in message.toolCalls) _ToolCallChip(call: t),
                    ],
                  ),
                ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  ts != null ? _timeFmt.format(ts.toLocal()) : '',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCallChip extends StatefulWidget {
  const _ToolCallChip({required this.call});
  final ChatToolCall call;

  @override
  State<_ToolCallChip> createState() => _ToolCallChipState();
}

class _ToolCallChipState extends State<_ToolCallChip> {
  bool _expanded = false;

  String _resultPreview(String raw) {
    if (raw.isEmpty) return '—';
    if (raw.length <= 64) return raw;
    return '${raw.substring(0, 64)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = widget.call;
    final accent = c.isError ? scheme.error : scheme.primary;
    final icon = c.isError ? Icons.error_outline : Icons.bolt_outlined;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _resultPreview(c.result),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 6),
                  _kv(context, 'args', c.input.toString()),
                  const SizedBox(height: 4),
                  _kv(context, 'result', c.result),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String key, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: scheme.onSurface),
          children: [
            TextSpan(
              text: '$key: ',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
