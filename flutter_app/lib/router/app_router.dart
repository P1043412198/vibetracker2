import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_page.dart';
import '../features/challenges/challenge_details_page.dart';
import '../features/challenges/challenges_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/dashboard/dashboard_settings_page.dart';
import '../features/finance/finance_page.dart';
import '../features/finance/loans_page.dart';
import '../features/finance/qr_receipt_scanner_page.dart';
import '../features/finance/receipt_gallery_page.dart';
import '../features/financial_plan/financial_plan_compare_page.dart';
import '../features/financial_plan/financial_plan_month_page.dart';
import '../features/financial_plan/financial_plan_page.dart';
import '../features/goals/goal_details_page.dart';
import '../features/goals/goals_page.dart';
import '../features/habits/habit_details_page.dart';
import '../features/habits/habits_page.dart';
import '../features/inbox/inbox_page.dart';
import '../features/household/household_notes_page.dart';
import '../features/household/household_page.dart';
import '../features/passwords/passwords_page.dart';
import '../features/search/global_search_page.dart';
import '../features/security/pin_setup_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shopping_list/shopping_list_page.dart';
import '../features/spheres/sphere_details_page.dart';
import '../features/spheres/spheres_page.dart';
import '../features/tasks/tasks_page.dart';
import '../features/pomodoro/pomodoro_page.dart';
import '../features/sleep/sleep_page.dart';
import '../features/tools/tools_page.dart';
import '../features/water/water_page.dart';
import '../features/work_schedule/work_schedule_page.dart';
import '../features/workouts/workout_history_page.dart';
import '../features/workouts/workouts_page.dart';
import '../widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DashboardPage()),
          ),
          GoRoute(
            path: '/spheres',
            name: 'spheres',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SpheresPage()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'sphere-details',
                builder: (context, state) =>
                    SphereDetailsPage(id: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          GoRoute(
            path: '/tasks',
            name: 'tasks',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: TasksPage()),
          ),
          GoRoute(
            path: '/habits',
            name: 'habits',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HabitsPage()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'habit-details',
                builder: (context, state) => HabitDetailsPage(
                  habitId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/inbox',
            name: 'inbox',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: InboxPage()),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: GlobalSearchPage()),
          ),
          GoRoute(
            path: '/finance',
            name: 'finance',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: FinancePage()),
          ),
          GoRoute(
            path: '/receipts',
            name: 'receipts',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ReceiptGalleryPage()),
          ),
          GoRoute(
            path: '/qr-receipt',
            name: 'qr-receipt',
            builder: (_, __) => const QrReceiptScannerPage(),
          ),
          GoRoute(
            path: '/loans',
            name: 'loans',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: LoansPage()),
          ),
          GoRoute(
            path: '/financial-plan',
            name: 'financial-plan',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: FinancialPlanPage()),
            routes: [
              GoRoute(
                path: 'month/:id',
                name: 'financial-plan-month',
                builder: (context, state) => FinancialPlanMonthPage(
                  id: state.pathParameters['id'] ?? '',
                ),
              ),
              GoRoute(
                path: 'compare/:id',
                name: 'financial-plan-compare',
                builder: (context, state) => FinancialPlanComparePage(
                  id: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/workouts',
            name: 'workouts',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: WorkoutsPage()),
          ),
          GoRoute(
            path: '/workouts-history',
            name: 'workouts-history',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: WorkoutHistoryPage()),
          ),
          GoRoute(
            path: '/household',
            name: 'household',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HouseholdPage()),
          ),
          GoRoute(
            path: '/household-notes',
            name: 'household-notes',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: HouseholdNotesPage()),
          ),
          GoRoute(
            path: '/goals',
            name: 'goals',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: GoalsPage()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'goal-details',
                builder: (context, state) => GoalDetailsPage(
                  goalId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/work-schedule',
            name: 'work-schedule',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: WorkSchedulePage()),
          ),
          GoRoute(
            path: '/challenges',
            name: 'challenges',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ChallengesPage()),
            routes: [
              GoRoute(
                path: ':id',
                name: 'challenge-details',
                builder: (context, state) => ChallengeDetailsPage(
                  challengeId: state.pathParameters['id'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/analytics',
            name: 'analytics',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AnalyticsPage()),
          ),
          GoRoute(
            path: '/shopping-list',
            name: 'shopping-list',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ShoppingListPage()),
          ),
          GoRoute(
            path: '/passwords',
            name: 'passwords',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: PasswordsPage()),
          ),
          GoRoute(
            path: '/pomodoro',
            name: 'pomodoro',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: PomodoroPage()),
          ),
          GoRoute(
            path: '/sleep',
            name: 'sleep',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SleepPage()),
          ),
          GoRoute(
            path: '/water',
            name: 'water',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: WaterPage()),
          ),
          GoRoute(
            path: '/tools',
            name: 'tools',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: ToolsPage()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: '/dashboard-settings',
            name: 'dashboard-settings',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: DashboardSettingsPage()),
          ),
          GoRoute(
            path: '/pin-setup',
            name: 'pin-setup',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: PinSetupPage()),
          ),
        ],
      ),
    ],
  );
});
