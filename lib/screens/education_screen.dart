import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/section_card.dart';

class _Lesson {
  final String title;
  final String summary;
  final String body;
  final IconData icon;
  final Color color;
  const _Lesson({
    required this.title,
    required this.summary,
    required this.body,
    required this.icon,
    required this.color,
  });
}

const _lessons = <_Lesson>[
  _Lesson(
    title: 'Бюджет 50/30/20',
    summary: 'Простое правило для распределения дохода',
    body:
        'Подели весь доход на три части: 50% — нужды (еда, транспорт, аренда), 30% — желания (кафе, развлечения), 20% — накопления и инвестиции. Если какая-то категория «съедает» больше — пересмотри привычки.',
    icon: Icons.pie_chart_rounded,
    color: AppColors.primary,
  ),
  _Lesson(
    title: 'Финансовая подушка',
    summary: 'Сколько откладывать «на чёрный день»',
    body:
        'Цель — 3–6 месяцев расходов на ликвидном счёте. Считай по факту: возьми среднемесячные расходы за последние 3 месяца и умножь. Подушка — это страховка, не инвестиция.',
    icon: Icons.umbrella_rounded,
    color: AppColors.primaryLight,
  ),
  _Lesson(
    title: 'План vs факт',
    summary: 'Зачем планировать каждый месяц',
    body:
        'План показывает, чего ты хочешь достичь. Факт показывает, где ты сейчас. Сравнение помогает находить «дыры» и корректировать привычки. В FinFlow ты можешь спланировать любой месяц и сравнить с фактом по каждой категории.',
    icon: Icons.compare_arrows_rounded,
    color: AppColors.accent,
  ),
  _Lesson(
    title: 'Импульсивные покупки',
    summary: 'Как не покупать лишнего',
    body:
        'Правило 24 часов: добавь товар в избранное и подожди день. Если завтра ты всё ещё хочешь его — покупай. Так ты отделишь желания от мимолётных импульсов.',
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFFE07A5F),
  ),
  _Lesson(
    title: 'Цели и приоритеты',
    summary: 'SMART цели для денег',
    body:
        'Хорошая цель — конкретна, измерима, достижима, релевантна и ограничена во времени. «Накопить 200 000 ₽ на отпуск к маю» — да. «Стать богатым» — нет.',
    icon: Icons.flag_rounded,
    color: Color(0xFF9C7BD2),
  ),
];

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Обучение')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _HeaderBanner(),
          const SizedBox(height: 16),
          const SectionHeader(title: 'Уроки'),
          for (final l in _lessons) ...[
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () => _open(context, l),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: l.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(l.icon, color: l.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.summary,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, _Lesson lesson) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: lesson.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(lesson.icon, color: lesson.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    lesson.body,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
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

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Учись управлять деньгами',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Короткие уроки на 2–3 минуты\nо бюджетах, накоплениях и привычках',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}
