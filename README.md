# FinFlow — Финансовая грамотность

Личный финансовый менеджер для Android.

- Учёт доходов и расходов с категориями
- Планирование бюджета на любой месяц
- Сравнение «План vs Факт» и «Свободно сегодня»
- Аналитика расходов: круговая диаграмма и динамика
- Обучение и привычки
- Локальное хранение через SharedPreferences (без облака)

## Сборка APK

```bash
flutter pub get
flutter build apk --release
```

APK будет в `build/app/outputs/flutter-apk/app-release.apk`.

## Запуск тестов

```bash
flutter analyze
flutter test
```
