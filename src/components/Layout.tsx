import React, { useState, useEffect } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { LayoutDashboard, Target, CheckSquare, Activity, BarChart3, Wallet, Dumbbell, Settings as SettingsIcon, Key, Home, Rocket, Menu, X, Calendar, ShoppingCart } from 'lucide-react';
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
  ].filter(item => !item.module || enabledModules?.[item.module as keyof typeof enabledModules] !== false);

  return (
    <div className="flex flex-col md:flex-row h-screen bg-zinc-950 text-zinc-100 font-sans">
      {/* Sidebar for Desktop */}
      <aside className="hidden md:flex w-64 bg-zinc-900 border-r border-zinc-800 flex-col">
        <div className="p-6">
          <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
            <Target className="w-5 h-5 text-white" />
            Vibesight
          </h1>
        </div>
        
        <nav className="flex-1 px-4 space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-zinc-800 text-white'
                    : 'text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200'
                )
              }
            >
              <item.icon className="w-5 h-5" />
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Mobile Header */}
      <header className="md:hidden flex items-center justify-between px-4 py-3 bg-zinc-900/90 backdrop-blur-md border-b border-zinc-800 pt-safe sticky top-0 z-40">
        <div className="flex items-center gap-2 text-white font-bold text-lg">
          <Target className="w-5 h-5 text-white" />
          Vibesight
        </div>
        <NavLink
          to="/settings"
          className={({ isActive }) =>
            cn(
              'p-2 rounded-full transition-colors',
              isActive ? 'bg-zinc-800 text-white' : 'text-zinc-400 hover:text-white hover:bg-zinc-800/50'
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
              className="md:hidden fixed inset-0 bg-black/60 z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 25, stiffness: 200 }}
              className="md:hidden fixed bottom-[60px] left-0 right-0 bg-zinc-900 border-t border-zinc-800 rounded-t-2xl z-50 p-4 pb-safe shadow-2xl"
            >
              <div className="flex justify-between items-center mb-4 px-2">
                <h2 className="text-lg font-bold text-white">Меню</h2>
                <button onClick={() => setIsMoreOpen(false)} className="p-2 text-zinc-400 hover:text-white bg-zinc-800/50 rounded-full transition-colors">
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
                          ? 'bg-zinc-800 text-white'
                          : 'bg-zinc-950/50 text-zinc-400 hover:bg-zinc-800/50 hover:text-zinc-200'
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
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-zinc-900/90 backdrop-blur-md border-t border-zinc-800 z-50 pb-safe">
        <div className="flex justify-around items-center px-2 pt-2 pb-1.5 w-full">
          {mainMobileNav.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  'flex flex-col items-center justify-center gap-1 flex-1 py-1 rounded-lg transition-colors',
                  isActive && !isMoreOpen
                    ? 'text-white'
                    : 'text-zinc-500 hover:text-zinc-300'
                )
              }
            >
              <item.icon className="w-5 h-5 shrink-0" />
              <span className="text-[10px] leading-none tracking-tighter font-medium truncate w-full text-center px-0.5">
                {item.shortLabel}
              </span>
            </NavLink>
          ))}
          <button
            onClick={() => setIsMoreOpen(!isMoreOpen)}
            className={cn(
              'flex flex-col items-center justify-center gap-1 flex-1 py-1 rounded-lg transition-colors',
              isMoreOpen || moreMobileNav.some(item => location.pathname === item.to)
                ? 'text-white'
                : 'text-zinc-500 hover:text-zinc-300'
            )}
          >
            <Menu className="w-5 h-5 shrink-0" />
            <span className="text-[10px] leading-none tracking-tighter font-medium truncate w-full text-center px-0.5">
              Еще
            </span>
          </button>
        </div>
      </nav>
    </div>
  );
}
