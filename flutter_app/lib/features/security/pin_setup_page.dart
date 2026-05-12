import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings_state.dart';

/// Set / change / disable the PIN lock. Counterpart of the React PIN setup
/// dialog inside `Settings.tsx`.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();
  final _currentPin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin1.dispose();
    _pin2.dispose();
    _currentPin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = ref.read(pinLockProvider);
    setState(() => _error = null);
    if (state.hasPin) {
      if (_currentPin.text != state.pin) {
        setState(() => _error = 'Текущий PIN-код неверный');
        return;
      }
    }
    if (_pin1.text.length != 4) {
      setState(() => _error = 'PIN должен состоять из 4 цифр');
      return;
    }
    if (_pin1.text != _pin2.text) {
      setState(() => _error = 'PIN-коды не совпадают');
      return;
    }
    await ref.read(pinLockProvider.notifier).setPin(_pin1.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN-код сохранён')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _disable() async {
    final state = ref.read(pinLockProvider);
    if (state.hasPin && _currentPin.text != state.pin) {
      setState(() => _error = 'Текущий PIN-код неверный');
      return;
    }
    await ref.read(pinLockProvider.notifier).setPin(null);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN-код отключён')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pinLockProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(state.hasPin ? 'Сменить PIN-код' : 'Задать PIN-код'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.hasPin) ...[
              Text('Текущий PIN-код',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _PinField(controller: _currentPin),
              const SizedBox(height: 16),
            ],
            Text('Новый PIN-код',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _PinField(controller: _pin1),
            const SizedBox(height: 16),
            Text('Повторите PIN-код',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _PinField(controller: _pin2),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Сохранить PIN'),
            ),
            if (state.hasPin) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _disable,
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Отключить PIN'),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'PIN запрашивается при запуске и при возврате из фона. Хранится '
              'локально в Hive — это приватная защита от случайного доступа, '
              'не криптографическое хранилище.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: const InputDecoration(
        counterText: '',
        hintText: '4 цифры',
        border: OutlineInputBorder(),
      ),
    );
  }
}
