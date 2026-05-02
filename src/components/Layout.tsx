import React, { useState, useEffect } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { LayoutDashboard, Target, CheckSquare, Activity, BarChart3, Wallet, Dumbbell, Settings as SettingsIcon, Key, Home, Rocket, Menu, X, Calendar, ShoppingCart, Calculator } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'framer-motion';
import { useStore } from '../store/useStore';

export function Layout() {
  const [isMoreOpen, setIsMoreOpen] = useState(false);
  const location = useLocation();
  const { enabledModules } = useStore();

  // Close more menu on route change
  useEffect(() => {
    setIsMoreOpen(false);
  }, [location.pathname]);

  const navItems = [
    { to: '/', icon: LayoutDashboard, label: 'Главная', shortLabel: 'Дом' },
    { to: '/spheres', icon: Target, label: 'Сферы', shortLabel: 'Сферы', module: 'spheres' },
    { to: '/tasks', icon: CheckSquare, label: 'Задачи', shortLabel: 'Задачи', module: 'tasks' },
    { to: '/habits', icon: Activity, label: 'Привычки', shortLabel: 'Навыки', module: 'habits' },
    { to: '/workouts', icon: Dumbbell, label: 'Занятия', shortLabel: 'Спорт', module: 'workouts' },
    { to: '/finance', icon: Wallet, label: 'Финансы', shortLabel: 'Деньги', module: 'finance' },
    { to: '/household', icon: Home, label: 'Быт', shortLabel: 'Быт', module: 'household' },
    { to: '/goals', icon: Rocket, label: 'Развитие', shortLabel: 'Рост', module: 'goals' },
    { to: '/work-schedule', icon: Calendar, label: 'График', shortLabel: 'Смена', module: 'schedule' },
    { to: '/passwords', icon: Key, label: 'Пароли', shortLabel: 'Пароли', module: 'passwords' },
    { to: '/analytics', icon: BarChart3, label: 'Аналитика', shortLabel: 'Анализ', module: 'analytics' },
    { to: '/shopping-list', icon: ShoppingCart, label: 'Покупки', shortLabel: 'Чек', module: 'household' },
    { to: '/tools', icon: Calculator, label: 'Инструменты', shortLabel: 'Инстр.' },
    { to: '/settings', icon: SettingsIcon, label: 'Настройки', shortLabel: 'Настройки' },
  ].filter(item => !item.module || enabledModules?.[item.module as keyof typeof enabledModules] !== false);

  const mainMobileNav = [
    { to: '/', icon: LayoutDashboard, label: 'Главная', shortLabel: 'Дом' },
    { to: '/tasks', icon: CheckSquare, label: 'Задачи', shortLabel: 'Задачи', module: 'tasks' },
    { to: '/finance', icon: Wallet, label: 'Финансы', shortLabel: 'Деньги', module: 'finance' },
    { to: '/goals', icon: Rocket, label: 'Развитие', shortLabel: 'Рост', module: 'goals' },
  ].filter(item => !item.module || enabledModules?.[item.module as keyof typeof enabledModules] !== false);

  const moreMobileNav = [
    { to: '/spheres', icon: Target, label: 'Сферы', shortLabel: 'Сферы', module: 'spheres' },
    { to: '/habits', icon: Activity, label: 'Привычки', shortLabel: 'Навыки', module: 'habits' },
    { to: '/workouts', icon: Dumbbell, label: 'Занятия', shortLabel: 'Спорт', module: 'workouts' },
    { to: '/household', icon: Home, label: 'Быт', shortLabel: 'Быт', module: 'household' },
    { to: '/work-schedule', icon: Calendar, label: 'График', shortLabel: 'Смена', module: 'schedule' },
    { to: '/passwords', icon: Key, label: 'Пароли', shortLabel: 'Пароли', module: 'passwords' },
    { to: '/analytics', icon: BarChart3, label: 'Аналитика', shortLabel: 'Анализ', module: 'analytics' },
    { to: '/shopping-list', icon: ShoppingCart, label: 'Покупки', shortLabel: 'Чек', module: 'household' },
    { to: '/tools', icon: Calculator, label: 'Инструменты', shortLabel: 'Инстр.' },
  ].filter(item => !item.module || enabledModules?.[item.module as keyof typeof enabledModules] !== false);

  return (
    <div className="flex flex-col md:flex-row h-screen bg-[var(--vs-bg)] text-zinc-900 font-sans">
      {/* Sidebar for Desktop */}
      <aside className="hidden md:flex w-64 bg-gradient-to-b from-white to-emerald-50/30 border-r border-stone-200 flex-col">
        <div className="p-6">
          <h1 className="text-xl font-extrabold tracking-tight text-emerald-900 flex items-center gap-2.5">
            <span className="inline-flex items-center justify-center w-9 h-9 rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-700 text-white shadow-md shadow-emerald-500/30">
              <Target className="w-5 h-5" />
            </span>
            Vibesight
          </h1>
        </div>

        <nav className="flex-1 px-3 space-y-0.5 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  'group relative flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all',
                  isActive
                    ? 'bg-gradient-to-r from-emerald-500 to-emerald-600 text-white shadow-md shadow-emerald-500/30'
                    : 'text-zinc-600 hover:bg-emerald-50/60 hover:text-emerald-800'
                )
              }
            >
              {({ isActive }) => (
                <>
                  <item.icon className={cn("w-[18px] h-[18px] shrink-0", isActive ? "text-white" : "text-zinc-400 group-hover:text-emerald-600")} />
                  <span className="truncate">{item.label}</span>
                </>
              )}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Mobile Header */}
      <header className="md:hidden flex items-center justify-between px-4 py-2.5 bg-white/95 backdrop-blur-xl border-b border-stone-200 pt-safe sticky top-0 z-40">
        <div className="flex items-center gap-2 text-emerald-900 font-extrabold text-lg">
          <span className="inline-flex items-center justify-center w-8 h-8 rounded-xl bg-gradient-to-br from-emerald-500 to-emerald-700 text-white shadow-md shadow-emerald-500/30">
            <Target className="w-4 h-4" />
          </span>
          Vibesight
        </div>
        <NavLink
          to="/settings"
          className={({ isActive }) =>
            cn(
              'p-2 rounded-full transition-colors',
              isActive ? 'bg-emerald-100 text-emerald-700' : 'text-zinc-500 hover:text-zinc-900 hover:bg-stone-100/60'
            )
          }
        >
          <SettingsIcon className="w-5 h-5" />
        </NavLink>
      </header>

      {/* Main Content */}
      <main className="flex-1 overflow-auto pb-24 md:pb-0">
        <div className="p-4 md:p-8 max-w-6xl mx-auto">
          <Outlet />
        </div>
      </main>

      {/* Mobile More Menu Overlay */}
      <AnimatePresence>
        {isMoreOpen && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setIsMoreOpen(false)}
              className="md:hidden fixed inset-0 bg-zinc-900/40 z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="md:hidden fixed bottom-[60px] left-0 right-0 bg-white border-t border-stone-200 rounded-t-2xl z-50 p-4 pb-safe shadow-2xl"
            >
              <div className="flex justify-between items-center mb-4 px-2">
                <h2 className="text-lg font-bold text-zinc-900">Меню</h2>
                <button onClick={() => setIsMoreOpen(false)} className="p-2 text-zinc-500 hover:text-zinc-900 bg-stone-100/60 rounded-full transition-colors">
                  <X className="w-5 h-5" />
                </button>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {moreMobileNav.map((item) => (
                  <NavLink
                    key={item.to}
                    to={item.to}
                    className={({ isActive }) =>
                      cn(
                        'flex flex-col items-center justify-center gap-2 p-3 rounded-xl transition-colors',
                        isActive
                          ? 'bg-stone-100 text-zinc-900'
                          : 'bg-stone-50/50 text-zinc-500 hover:bg-stone-100/60 hover:text-zinc-800'
                      )
                    }
                  >
                    <item.icon className="w-6 h-6" />
                    <span className="text-xs font-medium">{item.label}</span>
                  </NavLink>
                ))}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Bottom Navigation for Mobile */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white/95 backdrop-blur-xl border-t border-stone-200 z-50 pb-safe shadow-[0_-4px_20px_rgba(0,0,0,0.04)]">
        <div className="flex justify-around items-stretch px-1 pt-1.5 pb-1 w-full gap-0.5">
          {mainMobileNav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  'relative flex flex-col items-center justify-center gap-0.5 flex-1 py-1.5 rounded-2xl transition-all',
                  isActive && !isMoreOpen
                    ? 'text-emerald-700 bg-emerald-50'
                    : 'text-zinc-500 active:bg-stone-100'
                )
              }
            >
              {({ isActive }) => (
                <>
                  {isActive && !isMoreOpen && (
                    <span className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-1 rounded-b-full bg-emerald-600" />
                  )}
                  <item.icon className={cn("w-[22px] h-[22px] shrink-0 transition-transform", isActive && !isMoreOpen && "scale-110")} />
                  <span className="text-[10px] leading-none font-semibold truncate w-full text-center px-0.5">
                    {item.shortLabel}
                  </span>
                </>
              )}
            </NavLink>
          ))}
          <button
            onClick={() => setIsMoreOpen(!isMoreOpen)}
            className={cn(
              'relative flex flex-col items-center justify-center gap-0.5 flex-1 py-1.5 rounded-2xl transition-all',
              isMoreOpen || moreMobileNav.some(item => location.pathname === item.to)
                ? 'text-emerald-700 bg-emerald-50'
                : 'text-zinc-500 active:bg-stone-100'
            )}
          >
            {(isMoreOpen || moreMobileNav.some(item => location.pathname === item.to)) && (
              <span className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-1 rounded-b-full bg-emerald-600" />
            )}
            <Menu className={cn("w-[22px] h-[22px] shrink-0 transition-transform", isMoreOpen && "scale-110")} />
            <span className="text-[10px] leading-none font-semibold truncate w-full text-center px-0.5">
              Еще
            </span>
          </button>
        </div>
      </nav>
    </div>
  );
}
