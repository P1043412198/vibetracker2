import React, { useRef, useState } from 'react';
import {
  Download, Upload, Database, AlertTriangle, Bot, Key, Bell, Lock,
  ShieldCheck, ShieldAlert, LayoutDashboard, Target, CheckSquare, Activity,
  Dumbbell, Wallet, Home, Rocket, Calendar, BarChart3, Droplets,
  Briefcase, BookOpen, Settings as SettingsIcon, Cog,
} from 'lucide-react';
import { useStore } from '../store/useStore';
import { get, set } from 'idb-keyval';
import { cn } from '../lib/utils';

type SectionId =
  | 'modules'
  | 'widgets'
  | 'security'
  | 'notifications'
  | 'ai'
  | 'finance'
  | 'data'
  | 'about';

const SECTIONS: {
  id: SectionId;
  label: string;
  description: string;
  icon: React.ComponentType<{ className?: string }>;
  accent: string;
}[] = [
  { id: 'modules', label: 'Модули', description: 'Какие разделы видны', icon: LayoutDashboard, accent: 'orange' },
  { id: 'widgets', label: 'Дашборд', description: 'Виджеты на главной', icon: Cog, accent: 'indigo' },
  { id: 'finance', label: 'Финансы', description: 'Валюта, налоги, удержания', icon: Wallet, accent: 'emerald' },
  { id: 'security', label: 'Безопасность', description: 'PIN-код, генератор паролей', icon: Lock, accent: 'emerald' },
  { id: 'notifications', label: 'Уведомления', description: 'Напоминания и оповещения', icon: Bell, accent: 'blue' },
  { id: 'ai', label: 'ИИ', description: 'Ключи Gemini, OpenAI', icon: Bot, accent: 'purple' },
  { id: 'data', label: 'Данные', description: 'Резервная копия, импорт', icon: Database, accent: 'blue' },
  { id: 'about', label: 'О приложении', description: 'Версия, помощь', icon: BookOpen, accent: 'zinc' },
];

const ACCENT_BG: Record<string, string> = {
  orange: 'bg-orange-500/10 text-orange-500',
  indigo: 'bg-indigo-500/10 text-indigo-500',
  emerald: 'bg-emerald-500/10 text-emerald-600',
  blue: 'bg-blue-500/10 text-blue-500',
  purple: 'bg-purple-500/10 text-purple-500',
  zinc: 'bg-zinc-500/10 text-zinc-500',
};

const MODULE_LIST: { id: string; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
  { id: 'spheres', label: 'Сферы жизни', icon: Target },
  { id: 'tasks', label: 'Задачи и списки', icon: CheckSquare },
  { id: 'habits', label: 'Привычки', icon: Activity },
  { id: 'workouts', label: 'Тренировки и спорт', icon: Dumbbell },
  { id: 'finance', label: 'Финансы и бюджет', icon: Wallet },
  { id: 'household', label: 'Быт и дом', icon: Home },
  { id: 'goals', label: 'Развитие и книги', icon: Rocket },
  { id: 'schedule', label: 'График работы', icon: Calendar },
  { id: 'passwords', label: 'Пароли', icon: Key },
  { id: 'analytics', label: 'Аналитика', icon: BarChart3 },
  { id: 'water', label: 'Вода', icon: Droplets },
];

const WIDGET_GROUPS: { title: string; items: { id: string; label: string }[] }[] = [
  {
    title: 'Обзор',
    items: [
      { id: 'overview', label: 'Обзор дня' },
      { id: 'efficiency', label: 'Эффективность' },
      { id: 'trends', label: 'Тренды' },
      { id: 'stats_grid', label: 'Статистика' },
      { id: 'discipline_score', label: 'Дисциплина' },
      { id: 'stoic_quote', label: 'Цитата дня' },
    ],
  },
  {
    title: 'Сферы и цели',
    items: [
      { id: 'spheres_charts', label: 'Графики сфер' },
      { id: 'spheres_progress', label: 'Прогресс сфер' },
      { id: 'goals', label: 'Цели' },
      { id: 'tasks_habits', label: 'Задачи и привычки' },
      { id: 'habit_stories', label: 'Истории привычек' },
      { id: 'habit_matrix', label: 'Матрица привычек' },
      { id: 'upcoming_deadlines', label: 'Дедлайны' },
    ],
  },
  {
    title: 'Здоровье',
    items: [
      { id: 'water', label: 'Вода' },
      { id: 'activity_trends', label: 'Тренды активности' },
      { id: 'activity_calendar', label: 'Календарь активности' },
      { id: 'next_workout', label: 'Следующая тренировка' },
      { id: 'sleep_recovery', label: 'Сон' },
      { id: 'pomodoro', label: 'Помодоро' },
    ],
  },
  {
    title: 'Финансы и быт',
    items: [
      { id: 'finance_summary', label: 'Финансы' },
      { id: 'monthly_budget', label: 'Бюджет месяца' },
      { id: 'net_worth', label: 'Чистый капитал' },
      { id: 'piggy_bank', label: 'Копилка' },
      { id: 'shopping_list', label: 'Список покупок' },
      { id: 'inbox', label: 'Входящие' },
    ],
  },
];

export function Settings() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const {
    customGeminiKey,
    customOpenAIKey,
    preferredAiProvider,
    setCustomGeminiKey,
    setCustomOpenAIKey,
    setPreferredAiProvider,
    notificationSettings,
    updateNotificationSettings,
    pinCode,
    setPinCode,
    customPasswordWord,
    scatterPasswordWord,
    setCustomPasswordWord,
    setScatterPasswordWord,
    enabledModules,
    updateModuleSettings,
    dashboardConfig,
    updateDashboardConfig,
    baseCurrency,
    setBaseCurrency,
    salaryDeductionPresets,
    upsertSalaryDeductionPreset,
    deleteSalaryDeductionPreset,
    toggleSalaryDeductionPreset,
  } = useStore();

  const [activeSection, setActiveSection] = useState<SectionId>('modules');

  const [newPin, setNewPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [pinError, setPinError] = useState('');
  const [isSettingPin, setIsSettingPin] = useState(false);
  const [showRemovePinConfirm, setShowRemovePinConfirm] = useState(false);
  const [importFileContent, setImportFileContent] = useState<string | null>(null);
  const [importError, setImportError] = useState<string | null>(null);

  const handleSavePin = () => {
    if (newPin.length !== 4 || confirmPin.length !== 4) {
      setPinError('PIN-код должен состоять из 4 цифр');
      return;
    }
    if (newPin !== confirmPin) {
      setPinError('PIN-коды не совпадают');
      return;
    }
    setPinCode(newPin);
    setIsSettingPin(false);
    setNewPin('');
    setConfirmPin('');
    setPinError('');
  };

  const handleRemovePin = () => {
    setPinCode(null);
    setShowRemovePinConfirm(false);
  };

  const handleExport = async () => {
    let data = await get('vibesight-storage');
    if (!data) {
      data = localStorage.getItem('vibesight-storage');
    }
    if (!data) return;

    const blob = new Blob([data], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `vibesight-backup-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
      try {
        const content = event.target?.result as string;
        const parsed = JSON.parse(content);
        if (parsed && parsed.state && typeof parsed.version === 'number') {
          setImportFileContent(content);
          setImportError(null);
        } else {
          setImportError('Неверный формат файла резервной копии.');
        }
      } catch (error) {
        console.error('Import error:', error);
        setImportError('Ошибка при чтении файла.');
      }
    };
    reader.readAsText(file);

    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const confirmImport = async () => {
    if (importFileContent) {
      await set('vibesight-storage', importFileContent);
      localStorage.setItem('vibesight-storage', importFileContent);
      window.location.reload();
    }
  };

  return (
    <div className="space-y-6 pb-24">
      <header>
        <h1 className="text-xl font-bold text-zinc-900 mb-1 flex items-center gap-2">
          <SettingsIcon className="w-5 h-5 text-emerald-600" />
          Настройки
        </h1>
        <p className="text-sm text-zinc-500">Разделы сгруппированы по темам — выбери нужный</p>
      </header>

      {/* Mobile: horizontal chip nav. Desktop: sidebar + content. */}
      <div className="md:grid md:grid-cols-[260px_1fr] md:gap-6">
        {/* Navigation */}
        <nav className="-mx-4 px-4 mb-4 md:mx-0 md:px-0 md:mb-0">
          {/* Mobile chips */}
          <div className="flex gap-2 overflow-x-auto pb-2 md:hidden">
            {SECTIONS.map(s => (
              <button
                key={s.id}
                onClick={() => setActiveSection(s.id)}
                className={cn(
                  'inline-flex items-center gap-2 px-3 py-2 rounded-2xl text-xs font-medium shrink-0 transition-colors',
                  activeSection === s.id
                    ? 'bg-emerald-600 text-white'
                    : 'bg-white border border-stone-200 text-zinc-700'
                )}
              >
                <s.icon className="w-3.5 h-3.5" />
                {s.label}
              </button>
            ))}
          </div>

          {/* Desktop sidebar */}
          <div className="hidden md:block bg-white border border-stone-200 rounded-2xl p-2 sticky top-4">
            {SECTIONS.map(s => (
              <button
                key={s.id}
                onClick={() => setActiveSection(s.id)}
                className={cn(
                  'w-full text-left flex items-center gap-3 px-3 py-2.5 rounded-xl transition-colors',
                  activeSection === s.id
                    ? 'bg-emerald-50 text-emerald-900'
                    : 'hover:bg-stone-50 text-zinc-700'
                )}
              >
                <span className={cn('w-8 h-8 rounded-lg flex items-center justify-center', ACCENT_BG[s.accent])}>
                  <s.icon className="w-4 h-4" />
                </span>
                <span className="flex-1 min-w-0">
                  <span className="block text-sm font-semibold">{s.label}</span>
                  <span className="block text-[11px] text-zinc-500 truncate">{s.description}</span>
                </span>
              </button>
            ))}
          </div>
        </nav>

        {/* Content */}
        <div className="space-y-6 min-w-0">
          {activeSection === 'modules' && (
            <SectionCard
              icon={LayoutDashboard}
              accent="orange"
              title="Модули приложения"
              description="Включите или отключите разделы, которыми вы не пользуетесь"
            >
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {MODULE_LIST.map((module) => (
                  <div key={module.id} className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between gap-2 min-w-0">
                    <div className="flex items-center gap-3 min-w-0">
                      <module.icon className="w-4 h-4 text-zinc-500 shrink-0" />
                      <span className="text-sm font-medium text-zinc-900 truncate">{module.label}</span>
                    </div>
                    <Toggle
                      checked={enabledModules?.[module.id as keyof typeof enabledModules] ?? true}
                      onChange={(v) => updateModuleSettings({ [module.id]: v })}
                    />
                  </div>
                ))}
              </div>
            </SectionCard>
          )}

          {activeSection === 'widgets' && (
            <SectionCard
              icon={Cog}
              accent="indigo"
              title="Виджеты дашборда"
              description="Что показывать на главной странице"
            >
              <div className="space-y-4">
                {WIDGET_GROUPS.map(group => (
                  <div key={group.title}>
                    <h3 className="text-[11px] uppercase tracking-wider font-bold text-zinc-500 mb-2">
                      {group.title}
                    </h3>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                      {group.items.map(widget => {
                        const visible = dashboardConfig?.visibleWidgets?.includes(widget.id as any) ?? true;
                        return (
                          <div key={widget.id} className="bg-stone-50 px-3 py-2.5 rounded-xl border border-stone-200 flex items-center justify-between gap-2 min-w-0">
                            <span className="text-sm font-medium text-zinc-900 truncate">{widget.label}</span>
                            <Toggle
                              checked={visible}
                              onChange={(v) => {
                                const next = v
                                  ? [...(dashboardConfig?.visibleWidgets ?? []), widget.id as any]
                                  : (dashboardConfig?.visibleWidgets ?? []).filter(w => w !== widget.id);
                                updateDashboardConfig({ visibleWidgets: next });
                              }}
                            />
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))}
              </div>
            </SectionCard>
          )}

          {activeSection === 'finance' && (
            <SectionCard
              icon={Wallet}
              accent="emerald"
              title="Финансы"
              description="Валюта, налоги и удержания по умолчанию"
            >
              <div className="space-y-4">
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="text-sm font-semibold text-zinc-900 mb-1">Базовая валюта</h3>
                  <p className="text-xs text-zinc-500 mb-3">В этой валюте считаются итоги по счетам и бюджету</p>
                  <select
                    value={baseCurrency}
                    onChange={(e) => setBaseCurrency(e.target.value as any)}
                    className="w-full bg-white border border-stone-200 rounded-xl px-3 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                  >
                    {['BYN', 'USD', 'EUR', 'RUB', 'PLN', 'USDT'].map(c => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>

                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 space-y-3">
                  <div className="flex items-start gap-3">
                    <Briefcase className="w-4 h-4 text-emerald-600 mt-0.5 shrink-0" />
                    <div className="flex-1 min-w-0">
                      <h3 className="text-sm font-semibold text-zinc-900">Удержания из зарплаты</h3>
                      <p className="text-xs text-zinc-500">
                        Профсоюз 1%, ДМС, благотворительность и т.д. Эти удержания применятся в калькуляторе «Зарплата на руки».
                      </p>
                    </div>
                  </div>

                  {(salaryDeductionPresets ?? []).length === 0 ? (
                    <p className="text-xs text-zinc-500 italic">
                      Нет удержаний. Добавь их в калькуляторе зарплаты (Инструменты → Зарплата на руки).
                    </p>
                  ) : (
                    <div className="space-y-1.5">
                      {(salaryDeductionPresets ?? []).map(p => (
                        <div key={p.id} className="bg-white border border-stone-200 rounded-xl p-2.5 flex items-center gap-2 min-w-0">
                          <Toggle checked={p.enabled} onChange={() => toggleSalaryDeductionPreset(p.id)} />
                          <div className="flex-1 min-w-0">
                            <div className="text-sm font-medium text-zinc-900 truncate">{p.label}</div>
                            <div className="text-[11px] text-zinc-500">
                              {p.kind === 'percent' ? `${p.value}%` : `${p.value} BYN`}
                              {' · '}
                              {p.taxable ? 'уменьшает базу' : 'после налога'}
                            </div>
                          </div>
                          <button
                            onClick={() => deleteSalaryDeductionPreset(p.id)}
                            className="text-rose-500 hover:bg-rose-50 px-2 py-1 rounded-lg text-xs"
                          >
                            Удалить
                          </button>
                        </div>
                      ))}
                    </div>
                  )}

                  <button
                    onClick={() =>
                      upsertSalaryDeductionPreset({
                        id: `union-${Date.now()}`,
                        label: 'Профсоюз',
                        kind: 'percent',
                        value: 1,
                        taxable: false,
                        enabled: true,
                      })
                    }
                    className="text-xs px-3 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                  >
                    + Добавить «Профсоюз 1%»
                  </button>
                </div>
              </div>
            </SectionCard>
          )}

          {activeSection === 'security' && (
            <SectionCard
              icon={Lock}
              accent="emerald"
              title="Безопасность"
              description="Защита приложения PIN-кодом и генератор паролей"
            >
              <div className="space-y-4">
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <div className="flex items-center justify-between gap-3 flex-wrap">
                    <div className="min-w-0">
                      <h3 className="font-medium text-zinc-900 flex items-center gap-2">
                        {pinCode ? <ShieldCheck className="w-4 h-4 text-emerald-500" /> : <ShieldAlert className="w-4 h-4 text-amber-500" />}
                        Блокировка приложения
                      </h3>
                      <p className="text-sm text-zinc-500">
                        {pinCode ? 'Приложение защищено PIN-кодом' : 'Установите PIN-код для защиты данных'}
                      </p>
                    </div>
                    {pinCode ? (
                      <div className="flex items-center gap-2">
                        {showRemovePinConfirm ? (
                          <>
                            <button
                              onClick={handleRemovePin}
                              className="px-3 py-1.5 bg-rose-500 text-white hover:bg-rose-600 rounded-lg text-xs font-medium"
                            >
                              Точно?
                            </button>
                            <button
                              onClick={() => setShowRemovePinConfirm(false)}
                              className="px-3 py-1.5 bg-stone-100 text-zinc-700 hover:bg-stone-200 rounded-lg text-xs font-medium"
                            >
                              Отмена
                            </button>
                          </>
                        ) : (
                          <button
                            onClick={() => setShowRemovePinConfirm(true)}
                            className="px-3 py-1.5 bg-rose-500/10 text-rose-600 hover:bg-rose-500/20 rounded-lg text-xs font-medium"
                          >
                            Отключить
                          </button>
                        )}
                      </div>
                    ) : (
                      <button
                        onClick={() => setIsSettingPin(!isSettingPin)}
                        className="px-3 py-1.5 bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 rounded-lg text-xs font-medium"
                      >
                        {isSettingPin ? 'Отмена' : 'Включить'}
                      </button>
                    )}
                  </div>

                  {isSettingPin && !pinCode && (
                    <div className="mt-4 pt-4 border-t border-stone-200 space-y-4">
                      <div className="grid grid-cols-2 gap-3">
                        <div className="space-y-1.5">
                          <label className="text-xs text-zinc-500">Новый PIN (4 цифры)</label>
                          <input
                            type="password"
                            maxLength={4}
                            value={newPin}
                            onChange={e => setNewPin(e.target.value.replace(/\D/g, ''))}
                            className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-emerald-500 text-center tracking-[0.4em] font-mono"
                            placeholder="••••"
                          />
                        </div>
                        <div className="space-y-1.5">
                          <label className="text-xs text-zinc-500">Подтвердите</label>
                          <input
                            type="password"
                            maxLength={4}
                            value={confirmPin}
                            onChange={e => setConfirmPin(e.target.value.replace(/\D/g, ''))}
                            className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-emerald-500 text-center tracking-[0.4em] font-mono"
                            placeholder="••••"
                          />
                        </div>
                      </div>
                      {pinError && <p className="text-xs text-rose-500">{pinError}</p>}
                      <button
                        onClick={handleSavePin}
                        disabled={newPin.length !== 4 || confirmPin.length !== 4}
                        className="w-full py-2 bg-emerald-600 hover:bg-emerald-700 disabled:bg-stone-200 disabled:text-zinc-400 text-white rounded-lg font-medium transition-colors"
                      >
                        Сохранить PIN-код
                      </button>
                    </div>
                  )}
                </div>

                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1">Генератор паролей</h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Секретное слово, которое будет добавляться во все генерируемые пароли.
                  </p>

                  <div className="space-y-3">
                    <div>
                      <label className="block text-xs font-medium text-zinc-500 mb-1">Секретное слово</label>
                      <input
                        type="text"
                        value={customPasswordWord || ''}
                        onChange={e => setCustomPasswordWord(e.target.value)}
                        placeholder="Например: vyesk"
                        className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div className="flex items-center justify-between gap-3">
                      <div className="min-w-0">
                        <h4 className="text-sm font-medium text-zinc-900">Разбросать по паролю</h4>
                        <p className="text-xs text-zinc-500">
                          Если выключено, слово вставится в середину пароля.
                        </p>
                      </div>
                      <Toggle checked={scatterPasswordWord} onChange={setScatterPasswordWord} />
                    </div>
                  </div>
                </div>
              </div>
            </SectionCard>
          )}

          {activeSection === 'notifications' && (
            <SectionCard
              icon={Bell}
              accent="blue"
              title="Уведомления"
              description="Напоминания приложения"
            >
              <div className="space-y-3">
                {[
                  { key: 'tasks' as const, title: 'Задачи', desc: 'Напоминания о невыполненных задачах' },
                  { key: 'habits' as const, title: 'Привычки', desc: 'Напоминания об отметке привычек' },
                  { key: 'payments' as const, title: 'Платежи', desc: 'Напоминания о регулярных платежах и кредитах' },
                ].map(item => (
                  <div key={item.key} className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="font-medium text-zinc-900">{item.title}</h3>
                      <p className="text-sm text-zinc-500">{item.desc}</p>
                    </div>
                    <Toggle
                      checked={notificationSettings?.[item.key] ?? true}
                      onChange={(v) => updateNotificationSettings({ [item.key]: v })}
                    />
                  </div>
                ))}
              </div>
            </SectionCard>
          )}

          {activeSection === 'ai' && (
            <SectionCard
              icon={Bot}
              accent="purple"
              title="ИИ Ассистенты"
              description="Настройка ключей API для интеллектуальных функций"
            >
              <div className="space-y-4">
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1">Провайдер по умолчанию</h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Какую модель использовать для ИИ-функций.
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setPreferredAiProvider('gemini')}
                      className={cn(
                        'flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-colors',
                        preferredAiProvider === 'gemini'
                          ? 'bg-blue-600 text-white'
                          : 'bg-white border border-stone-200 text-zinc-700 hover:bg-stone-100'
                      )}
                    >
                      Google Gemini
                    </button>
                    <button
                      onClick={() => setPreferredAiProvider('openai')}
                      className={cn(
                        'flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-colors',
                        preferredAiProvider === 'openai'
                          ? 'bg-emerald-600 text-white'
                          : 'bg-white border border-stone-200 text-zinc-700 hover:bg-stone-100'
                      )}
                    >
                      OpenAI ChatGPT
                    </button>
                  </div>
                </div>

                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1 flex items-center gap-2">
                    <Key className="w-4 h-4 text-zinc-500" />
                    Ключ Gemini API
                  </h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Если оставить пустым, будет использоваться системный ключ.
                  </p>
                  <input
                    type="password"
                    value={customGeminiKey || ''}
                    onChange={(e) => setCustomGeminiKey(e.target.value || null)}
                    placeholder="AIzaSy..."
                    className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-blue-500"
                  />
                </div>

                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1 flex items-center gap-2">
                    <Key className="w-4 h-4 text-zinc-500" />
                    Ключ OpenAI API
                  </h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Необходим для использования ChatGPT.
                  </p>
                  <input
                    type="password"
                    value={customOpenAIKey || ''}
                    onChange={(e) => setCustomOpenAIKey(e.target.value || null)}
                    placeholder="sk-..."
                    className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>
            </SectionCard>
          )}

          {activeSection === 'data' && (
            <SectionCard
              icon={Database}
              accent="blue"
              title="Резервное копирование"
              description="Экспорт и импорт всех данных приложения"
            >
              <div className="space-y-4">
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1">Экспорт данных</h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Скачайте все данные (сферы, задачи, привычки, тренировки, финансы) одним JSON-файлом.
                  </p>
                  <button
                    onClick={handleExport}
                    className="flex items-center gap-2 px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-sm font-medium"
                  >
                    <Download className="w-4 h-4" />
                    Скачать резервную копию
                  </button>
                </div>

                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h3 className="font-medium text-zinc-900 mb-1">Импорт данных</h3>
                  <p className="text-sm text-zinc-500 mb-3">
                    Восстановите данные из ранее скачанного файла.
                  </p>

                  <div className="flex items-start gap-2 p-3 bg-amber-100/60 border border-amber-200 rounded-lg mb-3">
                    <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                    <p className="text-xs text-amber-900">
                      Импорт полностью перезапишет ваши текущие данные. Сначала сделайте экспорт.
                    </p>
                  </div>

                  {importError && (
                    <div className="mb-3 p-3 bg-rose-100 border border-rose-200 rounded-lg text-sm text-rose-700">
                      {importError}
                    </div>
                  )}

                  <input
                    type="file"
                    accept=".json"
                    ref={fileInputRef}
                    onChange={handleImport}
                    className="hidden"
                  />

                  {importFileContent ? (
                    <div className="flex flex-wrap items-center gap-2">
                      <button
                        onClick={confirmImport}
                        className="flex items-center gap-2 px-4 py-2 bg-rose-500 hover:bg-rose-600 text-white rounded-lg text-sm font-medium"
                      >
                        <Upload className="w-4 h-4" />
                        Подтвердить импорт
                      </button>
                      <button
                        onClick={() => {
                          setImportFileContent(null);
                          setImportError(null);
                        }}
                        className="px-4 py-2 bg-stone-100 text-zinc-700 hover:bg-stone-200 rounded-lg text-sm font-medium"
                      >
                        Отмена
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => fileInputRef.current?.click()}
                      className="flex items-center gap-2 px-4 py-2 bg-white border border-stone-200 hover:bg-stone-100 text-zinc-900 rounded-lg text-sm font-medium"
                    >
                      <Upload className="w-4 h-4" />
                      Загрузить резервную копию
                    </button>
                  )}
                </div>
              </div>
            </SectionCard>
          )}

          {activeSection === 'about' && (
            <SectionCard
              icon={BookOpen}
              accent="zinc"
              title="О приложении"
              description="Версия и полезные ссылки"
            >
              <div className="space-y-3 text-sm text-zinc-700">
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <p><strong>VibeSight Tracker</strong> — личные финансы и привычки под Беларусь.</p>
                  <p className="text-xs text-zinc-500 mt-1">Учёт, бюджет, налоги, депозиты, FIRE, мини-курсы.</p>
                </div>
                <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
                  <h4 className="font-medium text-zinc-900 mb-1">Полезные ссылки</h4>
                  <ul className="text-xs text-zinc-600 space-y-1 list-disc list-inside">
                    <li>Курсы НБРБ: api.nbrb.by</li>
                    <li>Налоги-2026 РБ: nalog.gov.by</li>
                    <li>ФСЗН: ssf.gov.by</li>
                  </ul>
                </div>
              </div>
            </SectionCard>
          )}
        </div>
      </div>
    </div>
  );
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="relative inline-flex items-center cursor-pointer shrink-0">
      <input
        type="checkbox"
        className="sr-only peer"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
      />
      <div className="w-11 h-6 bg-stone-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
    </label>
  );
}

function SectionCard({
  icon: Icon,
  accent,
  title,
  description,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  accent: string;
  title: string;
  description: string;
  children: React.ReactNode;
}) {
  return (
    <section className="bg-white border border-stone-200 rounded-3xl p-5 sm:p-6">
      <header className="flex items-start gap-3 mb-4">
        <span className={cn('w-10 h-10 rounded-xl flex items-center justify-center shrink-0', ACCENT_BG[accent])}>
          <Icon className="w-5 h-5" />
        </span>
        <div className="min-w-0">
          <h2 className="text-lg font-bold text-zinc-900 leading-tight">{title}</h2>
          <p className="text-sm text-zinc-500">{description}</p>
        </div>
      </header>
      {children}
    </section>
  );
}
