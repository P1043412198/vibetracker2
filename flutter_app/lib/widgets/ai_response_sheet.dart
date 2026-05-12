import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// A reusable bottom sheet that shows a loading spinner while the AI
/// generates a response, then renders the result as Markdown.
///
/// Usage:
/// ```dart
/// showAiResponseSheet(
///   context: context,
///   title: 'Финансовый коуч',
///   future: GeminiService.coachMonth(...),
/// );
/// ```
Future<void> showAiResponseSheet({
  required BuildContext context,
  required String title,
  required Future<String> future,
  IconData icon = Icons.auto_awesome,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _AiResponseContent(
        title: title,
        icon: icon,
        future: future,
        scrollController: scrollController,
      ),
    ),
  );
}

class _AiResponseContent extends StatefulWidget {
  const _AiResponseContent({
    required this.title,
    required this.icon,
    required this.future,
    required this.scrollController,
  });

  final String title;
  final IconData icon;
  final Future<String> future;
  final ScrollController scrollController;

  @override
  State<_AiResponseContent> createState() => _AiResponseContentState();
}

class _AiResponseContentState extends State<_AiResponseContent> {
  String? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.future.then((value) {
      if (mounted) setState(() => _result = value);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Icon(widget.icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: scheme.error),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(color: scheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _result == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Gemini думает…'),
                        ],
                      ),
                    )
                  : Markdown(
                      controller: widget.scrollController,
                      data: _result!,
                      selectable: true,
                      onTapLink: (_, href, __) {
                        if (href != null) {
                          final uri = Uri.tryParse(href);
                          if (uri != null) {
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      padding: const EdgeInsets.all(16),
                    ),
        ),
      ],
    );
  }
}
