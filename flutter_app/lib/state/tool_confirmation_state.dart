import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// One pending destructive tool call awaiting user confirmation in the
/// chat UI. The chat controller awaits [completer.future] before deciding
/// whether to execute the underlying handler or short-circuit with a
/// "cancelled" tool_result.
class PendingToolConfirmation {
  PendingToolConfirmation({
    required this.id,
    required this.toolName,
    required this.input,
    required this.completer,
  });

  final String id;
  final String toolName;
  final Map<String, dynamic> input;
  final Completer<bool> completer;
}

/// Notifier that the chat controller pushes pending confirmations into,
/// and the chat page watches to surface a modal AlertDialog.
class ToolConfirmationController
    extends StateNotifier<PendingToolConfirmation?> {
  ToolConfirmationController() : super(null);

  /// Called from the chat controller before running a destructive tool.
  /// Returns a future that resolves once the user clicks confirm/cancel
  /// in the chat-page AlertDialog (or `false` if it gets superseded).
  Future<bool> request(String toolName, Map<String, dynamic> input) {
    // If another confirmation is already pending, reject it before
    // replacing — we never want to silently drop one.
    final prev = state;
    if (prev != null && !prev.completer.isCompleted) {
      prev.completer.complete(false);
    }
    final completer = Completer<bool>();
    state = PendingToolConfirmation(
      id: _uuid.v4(),
      toolName: toolName,
      input: input,
      completer: completer,
    );
    return completer.future;
  }

  /// Called from the chat-page dialog when the user picks an option.
  void resolve(bool confirmed) {
    final pending = state;
    if (pending == null) return;
    if (!pending.completer.isCompleted) {
      pending.completer.complete(confirmed);
    }
    state = null;
  }
}

final toolConfirmationProvider = StateNotifierProvider<
    ToolConfirmationController, PendingToolConfirmation?>((ref) {
  return ToolConfirmationController();
});
