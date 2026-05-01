import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'main_shell.dart';

class WelcomeScreen extends StatefulWidget {
  final AppState state;

  const WelcomeScreen({super.key, required this.state});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final name = _nameController.text.trim();
    await widget.state.setOnboarded(true, name: name.isEmpty ? 'Друг' : name);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(state: widget.state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Финансовая\nграмотность —\nтвой путь к свободе',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Учись. Планируй. Достигай.\nКонтролируй финансы\nи исполняй мечты.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: _HeroIllustration(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Как тебя зовут?',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _start,
                child: const Text('Начать путь'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _start,
                  child: const Text(
                    'Уже есть аккаунт? Войти',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(painter: _HeroPainter()),
    );
  }
}

class _HeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final book = Paint()..color = AppColors.primary;
    final bookShade = Paint()..color = AppColors.primaryLight;
    final coin = Paint()..color = AppColors.accent;
    final leaf = Paint()..color = const Color(0xFF6FB37D);
    final stem = Paint()
      ..color = const Color(0xFF3D7A4E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pot = Paint()..color = const Color(0xFFE6CFA0);

    // book
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(20, size.height * 0.5, size.width - 40, 50),
      const Radius.circular(8),
    );
    canvas.drawRRect(r, book);

    // chart on book
    final chartRect = Rect.fromLTWH(
      40,
      size.height * 0.5 + 8,
      size.width - 80,
      36,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(4)),
      bookShade,
    );

    // coins
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.2 + i * 22, size.height * 0.78),
        12,
        coin,
      );
    }

    // pot
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.4, 80, 60),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      ),
      pot,
    );

    // stem
    canvas.drawLine(
      Offset(size.width * 0.6 + 30, size.height * 0.4),
      Offset(size.width * 0.6 + 30, size.height * 0.18),
      stem,
    );

    // leaves
    final leafPath = Path()
      ..moveTo(size.width * 0.6 + 30, size.height * 0.25)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.18,
          size.width * 0.45, size.height * 0.22)
      ..quadraticBezierTo(size.width * 0.55, size.height * 0.3,
          size.width * 0.6 + 30, size.height * 0.25);
    canvas.drawPath(leafPath, leaf);

    final leafPath2 = Path()
      ..moveTo(size.width * 0.6 + 30, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.1,
          size.width * 0.92, size.height * 0.18)
      ..quadraticBezierTo(size.width * 0.78, size.height * 0.24,
          size.width * 0.6 + 30, size.height * 0.2);
    canvas.drawPath(leafPath2, leaf);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
