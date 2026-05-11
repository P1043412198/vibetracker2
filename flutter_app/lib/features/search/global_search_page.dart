import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/sphere.dart';
import '../../services/ai_service.dart';
import '../../services/gemini_service.dart';
import '../../state/providers.dart';
import '../../state/settings_state.dart';
import '../../widgets/ai_response_sheet.dart';

/// Global cross-entity search page.
///
/// Searches tasks, habits, sphere notes, inbox items, household notes,
/// financial-plan sections/items, and transactions; tapping a hit
/// navigates to the owning page.
class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _query.trim().isEmpty
        ? const <_SearchHit>[]
        : _search(_query.trim().toLowerCase());

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Поиск по всему приложению…',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          if (_query.isNotEmpty && _isAiAvailable)
            IconButton(
              tooltip: 'Спросить AI',
              icon: Icon(Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary),
              onPressed: () => _aiSearch(),
            ),
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _controller.clear();
                  _query = '';
                });
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? _EmptyHint()
          : results.isEmpty
              ? const _NothingFound()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final hit = results[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            hit.color.withValues(alpha: 0.18),
                        child: Icon(hit.icon, color: hit.color, size: 20),
                      ),
                      title: Text(
                        hit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        hit.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hit.kind,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      onTap: () => context.go(hit.route),
                    ).animate().fadeIn(duration: 160.ms);
                  },
                ),
    );
  }

  List<_SearchHit> _search(String q) {
    final tasks = ref.read(tasksProvider);
    final habits = ref.read(habitsProvider);
    final spheres = ref.read(spheresProvider);
    final inbox = ref.read(inboxProvider);
    final household = ref.read(householdNotesProvider);
    final plans = ref.read(financialPlanMonthsProvider);
    final transactions = ref.read(transactionsProvider);

    final out = <_SearchHit>[];

    for (final t in tasks) {
      if (_matches(t.title, q) ||
          (t.context != null && _matches(t.context!, q))) {
        out.add(_SearchHit(
          title: t.title,
          subtitle: '${_dateLabel(t.date)} · ${t.period.name}',
          kind: 'Задача',
          icon: Icons.task_alt,
          color: const Color(0xFF6366F1),
          route: '/tasks',
        ));
      }
    }

    for (final h in habits) {
      if (_matches(h.title, q) ||
          (h.description != null && _matches(h.description!, q))) {
        out.add(_SearchHit(
          title: h.title,
          subtitle: 'Привычка · ${h.type.name}',
          kind: 'Привычка',
          icon: Icons.eco,
          color: const Color(0xFF22C55E),
          route: '/habits',
        ));
      }
    }

    for (final s in spheres) {
      if (_matches(s.title, q) ||
          _matches(s.notes, q) ||
          (s.description != null && _matches(s.description!, q))) {
        out.add(_SearchHit(
          title: s.title,
          subtitle: s.description ?? 'Сфера',
          kind: 'Сфера',
          icon: Icons.bubble_chart_outlined,
          color: const Color(0xFFA855F7),
          route: '/spheres/${s.id}',
        ));
      }
      for (final n in s.notesList ?? const <SphereNote>[]) {
        if (_matches(n.content, q)) {
          out.add(_SearchHit(
            title: n.content.split('\n').first,
            subtitle: 'В сфере: ${s.title}',
            kind: 'Заметка сферы',
            icon: Icons.note_alt_outlined,
            color: const Color(0xFFA855F7),
            route: '/spheres/${s.id}',
          ));
        }
      }
      for (final c in s.categories ?? const <SphereCategory>[]) {
        if (_matches(c.title, q)) {
          out.add(_SearchHit(
            title: c.title,
            subtitle: 'Категория в: ${s.title}',
            kind: 'Категория',
            icon: Icons.folder_outlined,
            color: const Color(0xFFA855F7),
            route: '/spheres/${s.id}',
          ));
        }
      }
    }

    for (final item in inbox) {
      if (_matches(item.content, q) ||
          (item.url != null && _matches(item.url!, q))) {
        out.add(_SearchHit(
          title: item.content.split('\n').first,
          subtitle: item.url ?? 'Инбокс',
          kind: 'Инбокс',
          icon: Icons.inbox_outlined,
          color: const Color(0xFFEAB308),
          route: '/inbox',
        ));
      }
    }

    for (final n in household) {
      if (_matches(n.title, q) || _matches(n.body, q)) {
        out.add(_SearchHit(
          title: n.title,
          subtitle: n.body.split('\n').first,
          kind: 'Заметка',
          icon: Icons.home_outlined,
          color: const Color(0xFF06B6D4),
          route: '/household-notes',
        ));
      }
    }

    for (final plan in plans) {
      for (final scenario in plan.scenarios) {
        for (final section in scenario.sections) {
          if (_matches(section.title, q)) {
            out.add(_SearchHit(
              title: section.title,
              subtitle: '${plan.monthKey} · ${scenario.name}',
              kind: 'Секция плана',
              icon: Icons.dashboard_outlined,
              color: const Color(0xFF6D5CFF),
              route: '/financial-plan/${plan.id}',
            ));
          }
          for (final it in section.items) {
            if (_matches(it.label, q) ||
                (it.notes != null && _matches(it.notes!, q))) {
              out.add(_SearchHit(
                title: it.label,
                subtitle:
                    '${plan.monthKey} · ${section.title} · ${it.amount} ${it.currency}',
                kind: 'Статья плана',
                icon: Icons.list_alt_outlined,
                color: const Color(0xFF6D5CFF),
                route: '/financial-plan/${plan.id}',
              ));
            }
          }
        }
      }
    }

    for (final t in transactions) {
      if (_matches(t.category, q) ||
          (t.notes != null && _matches(t.notes!, q)) ||
          (t.merchant != null && _matches(t.merchant!, q))) {
        out.add(_SearchHit(
          title: '${t.category} · ${t.amount}',
          subtitle: '${t.date} · ${t.type.name}',
          kind: 'Транзакция',
          icon: Icons.payments_outlined,
          color: const Color(0xFF10B981),
          route: '/transactions',
        ));
      }
    }

    return out;
  }

  bool get _isAiAvailable {
    final key = AiService.apiKey;
    return key != null && key.isNotEmpty && ref.read(aiEnabledProvider);
  }

  void _aiSearch() {
    final q = _query.trim();
    if (q.isEmpty) return;

    final contextData = <String, dynamic>{
      'tasks': ref
          .read(tasksProvider)
          .take(20)
          .map((t) => {'title': t.title, 'date': t.date, 'done': t.completed})
          .toList(),
      'inbox': ref
          .read(inboxProvider)
          .take(20)
          .map((i) => {'content': i.content, 'date': i.createdAt})
          .toList(),
      'spheres': ref
          .read(spheresProvider)
          .map((s) => {'title': s.title, 'notes': s.notesList?.length ?? 0})
          .toList(),
      'transactions': ref
          .read(transactionsProvider)
          .take(30)
          .map((t) =>
              {'category': t.category, 'amount': t.amount, 'date': t.date})
          .toList(),
    };

    showAiResponseSheet(
      context: context,
      title: 'AI поиск: «$q»',
      icon: Icons.auto_awesome,
      future: GeminiService.naturalSearch(query: q, context: contextData),
    );
  }

  bool _matches(String haystack, String needle) =>
      haystack.toLowerCase().contains(needle);

  String _dateLabel(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _SearchHit {
  _SearchHit({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.icon,
    required this.color,
    required this.route,
  });
  final String title;
  final String subtitle;
  final String kind;
  final IconData icon;
  final Color color;
  final String route;
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Введите запрос для поиска',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Ищем по задачам, привычкам, сферам, инбоксу, заметкам, статьям плана и транзакциям',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Ничего не найдено'),
          ],
        ),
      ),
    );
  }
}
