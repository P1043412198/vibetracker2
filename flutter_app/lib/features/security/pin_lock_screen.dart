import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../state/settings_state.dart';

/// Numpad-style PIN lock screen — counterpart of React `PinLockScreen.tsx`.
/// Shown as a full-screen overlay whenever [pinLockProvider] reports a PIN is
/// set and the app is currently locked.
class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _input = '';
  bool _error = false;
  final _auth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAndPrompt();
  }

  Future<void> _checkBiometricAndPrompt() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!mounted) return;
      setState(() => _biometricAvailable = supported && canCheck);
      if (_biometricAvailable) {
        await _authenticateBiometric();
      }
    } catch (_) {
      // Plugin not available on this platform — silently fall back to PIN.
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Разблокируйте Vibesight Tracker',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) {
        HapticFeedback.lightImpact();
        ref.read(pinLockProvider.notifier).tryUnlockBiometric();
      }
    } catch (_) {
      // Authentication cancelled / unavailable — stay on PIN screen.
    }
  }

  void _press(int digit) {
    if (_input.length >= 4) return;
    setState(() {
      _input = '$_input$digit';
      _error = false;
    });
    if (_input.length == 4) {
      _attempt();
    }
  }

  void _delete() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = false;
    });
  }

  Future<void> _attempt() async {
    final ok = ref.read(pinLockProvider.notifier).tryUnlock(_input);
    if (!ok) {
      setState(() => _error = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _input = '';
        _error = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock, size: 32, color: scheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Введите PIN-код',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Приложение заблокировано для защиты данных',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = _input.length > i;
                      final color = _error
                          ? scheme.error
                          : (filled
                              ? scheme.primary
                              : scheme.outlineVariant);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (_biometricAvailable)
                    TextButton.icon(
                      onPressed: _authenticateBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Разблокировать отпечатком'),
                    ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 1; i <= 9; i++)
                        _PinKey(label: '$i', onPressed: () => _press(i)),
                      const SizedBox(),
                      _PinKey(label: '0', onPressed: () => _press(0)),
                      _PinKey(
                        icon: Icons.backspace_outlined,
                        onPressed: _delete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({this.label, this.icon, required this.onPressed});

  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 22)
                : Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
