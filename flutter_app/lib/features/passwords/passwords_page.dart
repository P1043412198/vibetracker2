import 'package:flutter/material.dart';

import '../../widgets/coming_soon.dart';

class PasswordsPage extends StatelessWidget {
  const PasswordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPage(
      title: 'Пароли',
      summary:
          'Хранилище паролей и TOTP-кодов. Перед портом нужно подобрать flutter-аналог otpauth и продумать шифрование локального стора.',
      icon: Icons.lock_outline,
    );
  }
}
