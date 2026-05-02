import React, { useRef, useState } from 'react';
import { Download, Upload, Database, AlertTriangle, Bot, Key, Bell, Lock, ShieldCheck, ShieldAlert, LayoutDashboard, Target, CheckSquare, Activity, Dumbbell, Wallet, Home, Rocket, Calendar, BarChart3, Droplets } from 'lucide-react';
import { useStore } from '../store/useStore';
import { get, set } from 'idb-keyval';

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
    updateDashboardConfig
  } = useStore();

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
    // Get the whole state from IndexedDB
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
        
        // Basic validation
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
    
    // Reset input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  const confirmImport = async () => {
    if (importFileContent) {
      await set('vibesight-storage', importFileContent);
      localStorage.setItem('vibesight-storage', importFileContent); // Keep fallback
      window.location.reload(); // Reload to apply the new state
    }
  };

  return (
    <div className="space-y-6 pb-24">
      <header>
        <h1 className="text-xl font-bold text-zinc-900 mb-2">Настройки</h1>
        <p className="text-zinc-500">Управление данными и приложением</p>
      </header>

      <div className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-stone-200">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-orange-500/10 flex items-center justify-center">
              <LayoutDashboard className="w-5 h-5 text-orange-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Модули приложения</h2>
              <p className="text-sm text-zinc-500">Включите или отключите разделы, которыми вы не пользуетесь</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {[
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
            ].map((module) => (
              <div key={module.id} className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <module.icon className="w-4 h-4 text-zinc-500" />
                  <span className="text-sm font-medium text-zinc-900">{module.label}</span>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input 
                    type="checkbox" 
                    className="sr-only peer"
                    checked={enabledModules?.[module.id as keyof typeof enabledModules] ?? true}
                    onChange={(e) => updateModuleSettings({ [module.id]: e.target.checked })}
                  />
                  <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
                </label>
              </div>
            ))}
          </div>
        </div>
        
        <div className="p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-indigo-500/10 flex items-center justify-center">
              <LayoutDashboard className="w-5 h-5 text-indigo-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Видимость виджетов</h2>
              <p className="text-sm text-zinc-500">Выберите, какие виджеты отображать на дашборде</p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {[
              { id: 'overview', label: 'Обзор дня' },
              { id: 'efficiency', label: 'Эффективность' },
              { id: 'trends', label: 'Тренды' },
              { id: 'stats_grid', label: 'Статистика' },
              { id: 'spheres_charts', label: 'Графики сфер' },
              { id: 'spheres_progress', label: 'Прогресс сфер' },
              { id: 'goals', label: 'Цели' },
              { id: 'tasks_habits', label: 'Задачи и привычки' },
              { id: 'water', label: 'Вода' },
              { id: 'activity_trends', label: 'Тренды активности' },
              { id: 'habit_stories', label: 'Истории привычек' },
              { id: 'activity_calendar', label: 'Календарь активности' },
              { id: 'finance_summary', label: 'Финансы' },
              { id: 'monthly_budget', label: 'Бюджет месяца' },
              { id: 'upcoming_deadlines', label: 'Дедлайны' },
              { id: 'habit_matrix', label: 'Матрица привычек' },
              { id: 'pomodoro', label: 'Помодоро' },
              { id: 'inbox', label: 'Входящие' },
              { id: 'next_workout', label: 'Следующая тренировка' },
              { id: 'sleep_recovery', label: 'Сон' },
              { id: 'discipline_score', label: 'Дисциплина' },
              { id: 'net_worth', label: 'Чистый капитал' },
              { id: 'stoic_quote', label: 'Цитата' },
              { id: 'shopping_list', label: 'Список покупок' },
              { id: 'piggy_bank', label: 'Копилка' },
            ].map((widget) => (
              <div key={widget.id} className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between">
                <span className="text-sm font-medium text-zinc-900">{widget.label}</span>
                <div className="flex items-center gap-2">
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input 
                      type="checkbox" 
                      className="sr-only peer"
                      checked={dashboardConfig?.visibleWidgets?.includes(widget.id as any) ?? true}
                      onChange={(e) => {
                        const isVisible = dashboardConfig?.visibleWidgets?.includes(widget.id as any) ?? true;
                        let newVisibleWidgets;
                        if (isVisible) {
                          newVisibleWidgets = dashboardConfig?.visibleWidgets?.filter(w => w !== widget.id) ?? [];
                        } else {
                          newVisibleWidgets = [...(dashboardConfig?.visibleWidgets ?? []), widget.id as any];
                        }
                        updateDashboardConfig({ visibleWidgets: newVisibleWidgets });
                      }}
                    />
                    <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
                  </label>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-stone-200">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
              <Database className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Резервное копирование</h2>
              <p className="text-sm text-zinc-500">Экспорт и импорт всех ваших данных</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2">Экспорт данных</h3>
              <p className="text-sm text-zinc-500 mb-4">
                Скачайте все ваши данные (сферы, задачи, привычки, тренировки) в один JSON файл.
              </p>
              <button
                onClick={handleExport}
                className="flex items-center gap-2 px-4 py-2 bg-stone-100 hover:bg-stone-200 text-zinc-900 rounded-lg transition-colors text-sm font-medium"
              >
                <Download className="w-4 h-4" />
                Скачать резервную копию
              </button>
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2">Импорт данных</h3>
              <p className="text-sm text-zinc-500 mb-4">
                Восстановите данные из ранее скачанного файла резервной копии.
              </p>
              
              <div className="flex items-center gap-2 p-3 bg-amber-500/10 border border-amber-500/20 rounded-lg mb-4">
                <AlertTriangle className="w-5 h-5 text-amber-500 shrink-0" />
                <p className="text-xs text-amber-200/70">
                  Внимание: импорт полностью перезапишет ваши текущие данные. Рекомендуется сначала сделать экспорт.
                </p>
              </div>

              {importError && (
                <div className="mb-4 p-3 bg-red-500/10 border border-red-500/20 rounded-lg text-sm text-red-400">
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
                <div className="flex items-center gap-2">
                  <button
                    onClick={confirmImport}
                    className="flex items-center gap-2 px-4 py-2 bg-red-500 hover:bg-red-600 text-zinc-900 rounded-lg transition-colors text-sm font-medium"
                  >
                    <Upload className="w-4 h-4" />
                    Подтвердить импорт
                  </button>
                  <button
                    onClick={() => {
                      setImportFileContent(null);
                      setImportError(null);
                    }}
                    className="px-4 py-2 bg-stone-100 text-zinc-700 hover:bg-stone-200 rounded-lg text-sm font-medium transition-colors"
                  >
                    Отмена
                  </button>
                </div>
              ) : (
                <button
                  onClick={() => fileInputRef.current?.click()}
                  className="flex items-center gap-2 px-4 py-2 bg-white hover:bg-zinc-200 text-black rounded-lg transition-colors text-sm font-medium"
                >
                  <Upload className="w-4 h-4" />
                  Загрузить резервную копию
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-stone-200">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-purple-500/10 flex items-center justify-center">
              <Bot className="w-5 h-5 text-purple-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">ИИ Ассистенты</h2>
              <p className="text-sm text-zinc-500">Настройка API ключей для ИИ</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2">Провайдер по умолчанию</h3>
              <p className="text-sm text-zinc-500 mb-4">
                Выберите, какую нейросеть использовать для генерации планов и ответов ассистентов.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={() => setPreferredAiProvider('gemini')}
                  className={`flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                    preferredAiProvider === 'gemini' 
                      ? 'bg-blue-600 text-zinc-900' 
                      : 'bg-stone-100 text-zinc-500 hover:bg-stone-200 hover:text-zinc-900'
                  }`}
                >
                  Google Gemini
                </button>
                <button
                  onClick={() => setPreferredAiProvider('openai')}
                  className={`flex-1 py-2 px-4 rounded-lg text-sm font-medium transition-colors ${
                    preferredAiProvider === 'openai' 
                      ? 'bg-green-600 text-zinc-900' 
                      : 'bg-stone-100 text-zinc-500 hover:bg-stone-200 hover:text-zinc-900'
                  }`}
                >
                  OpenAI (ChatGPT)
                </button>
              </div>
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2 flex items-center gap-2">
                <Key className="w-4 h-4 text-zinc-500" />
                Ключ Gemini API
              </h3>
              <p className="text-sm text-zinc-500 mb-4">
                Если оставить пустым, будет использоваться системный ключ по умолчанию.
              </p>
              <input
                type="password"
                value={customGeminiKey || ''}
                onChange={(e) => setCustomGeminiKey(e.target.value || null)}
                placeholder="AIzaSy..."
                className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-blue-500 transition-colors"
              />
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2 flex items-center gap-2">
                <Key className="w-4 h-4 text-zinc-500" />
                Ключ OpenAI API
              </h3>
              <p className="text-sm text-zinc-500 mb-4">
                Необходим для использования ChatGPT.
              </p>
              <input
                type="password"
                value={customOpenAIKey || ''}
                onChange={(e) => setCustomOpenAIKey(e.target.value || null)}
                placeholder="sk-..."
                className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-green-500 transition-colors"
              />
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-stone-200">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/10 flex items-center justify-center">
              <Lock className="w-5 h-5 text-emerald-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Безопасность</h2>
              <p className="text-sm text-zinc-500">Защита приложения PIN-кодом</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-medium text-zinc-900 flex items-center gap-2">
                    {pinCode ? <ShieldCheck className="w-4 h-4 text-emerald-400" /> : <ShieldAlert className="w-4 h-4 text-amber-400" />}
                    Блокировка приложения
                  </h3>
                  <p className="text-sm text-zinc-500">
                    {pinCode ? 'Приложение защищено PIN-кодом' : 'Установите PIN-код для защиты ваших данных'}
                  </p>
                </div>
                {pinCode ? (
                  <div className="flex items-center gap-2">
                    {showRemovePinConfirm ? (
                      <>
                        <button
                          onClick={handleRemovePin}
                          className="px-4 py-2 bg-red-500 text-zinc-900 hover:bg-red-600 rounded-lg text-sm font-medium transition-colors"
                        >
                          Точно?
                        </button>
                        <button
                          onClick={() => setShowRemovePinConfirm(false)}
                          className="px-4 py-2 bg-stone-100 text-zinc-700 hover:bg-stone-200 rounded-lg text-sm font-medium transition-colors"
                        >
                          Отмена
                        </button>
                      </>
                    ) : (
                      <button
                        onClick={() => setShowRemovePinConfirm(true)}
                        className="px-4 py-2 bg-red-500/10 text-red-400 hover:bg-red-500/20 rounded-lg text-sm font-medium transition-colors"
                      >
                        Отключить
                      </button>
                    )}
                  </div>
                ) : (
                  <button
                    onClick={() => setIsSettingPin(!isSettingPin)}
                    className="px-4 py-2 bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20 rounded-lg text-sm font-medium transition-colors"
                  >
                    {isSettingPin ? 'Отмена' : 'Включить'}
                  </button>
                )}
              </div>

              {isSettingPin && !pinCode && (
                <div className="mt-4 pt-4 border-t border-stone-200 space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <label className="text-xs text-zinc-500">Новый PIN-код (4 цифры)</label>
                      <input
                        type="password"
                        maxLength={4}
                        value={newPin}
                        onChange={e => setNewPin(e.target.value.replace(/\D/g, ''))}
                        className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-emerald-500 text-center tracking-[0.5em] font-mono"
                        placeholder="••••"
                      />
                    </div>
                    <div className="space-y-2">
                      <label className="text-xs text-zinc-500">Подтвердите PIN-код</label>
                      <input
                        type="password"
                        maxLength={4}
                        value={confirmPin}
                        onChange={e => setConfirmPin(e.target.value.replace(/\D/g, ''))}
                        className="w-full bg-white border border-stone-200 rounded-lg px-3 py-2 text-zinc-900 focus:outline-none focus:border-emerald-500 text-center tracking-[0.5em] font-mono"
                        placeholder="••••"
                      />
                    </div>
                  </div>
                  {pinError && <p className="text-xs text-red-400">{pinError}</p>}
                  <button
                    onClick={handleSavePin}
                    disabled={newPin.length !== 4 || confirmPin.length !== 4}
                    className="w-full py-2 bg-emerald-500 hover:bg-emerald-600 disabled:bg-stone-100 disabled:text-zinc-500 text-zinc-900 rounded-lg font-medium transition-colors"
                  >
                    Сохранить PIN-код
                  </button>
                </div>
              )}
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200">
              <h3 className="font-medium text-zinc-900 mb-2">Генератор паролей</h3>
              <p className="text-sm text-zinc-500 mb-4">
                Настройте секретное слово, которое будет добавляться во все генерируемые пароли.
              </p>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-zinc-500 mb-1">Секретное слово</label>
                  <input
                    type="text"
                    value={customPasswordWord || ''}
                    onChange={e => setCustomPasswordWord(e.target.value)}
                    placeholder="Например: vyesk"
                    className="w-full bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500 transition-colors"
                  />
                </div>

                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="text-sm font-medium text-zinc-900">Разбросать по паролю</h4>
                    <p className="text-xs text-zinc-500">
                      Если выключено, слово будет вставлено целиком в середину пароля.
                    </p>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input 
                      type="checkbox" 
                      className="sr-only peer"
                      checked={scatterPasswordWord}
                      onChange={(e) => setScatterPasswordWord(e.target.checked)}
                    />
                    <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white border border-stone-200 rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-stone-200">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-blue-500/10 flex items-center justify-center">
              <Bell className="w-5 h-5 text-blue-400" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-zinc-900">Оповещения</h2>
              <p className="text-sm text-zinc-500">Настройка уведомлений приложения</p>
            </div>
          </div>

          <div className="space-y-4">
            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between">
              <div>
                <h3 className="font-medium text-zinc-900">Задачи</h3>
                <p className="text-sm text-zinc-500">Напоминания о невыполненных задачах</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input 
                  type="checkbox" 
                  className="sr-only peer"
                  checked={notificationSettings?.tasks ?? true}
                  onChange={(e) => updateNotificationSettings({ tasks: e.target.checked })}
                />
                <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
              </label>
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between">
              <div>
                <h3 className="font-medium text-zinc-900">Привычки</h3>
                <p className="text-sm text-zinc-500">Напоминания об отметке привычек</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input 
                  type="checkbox" 
                  className="sr-only peer"
                  checked={notificationSettings?.habits ?? true}
                  onChange={(e) => updateNotificationSettings({ habits: e.target.checked })}
                />
                <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
              </label>
            </div>

            <div className="bg-stone-50 p-4 rounded-xl border border-stone-200 flex items-center justify-between">
              <div>
                <h3 className="font-medium text-zinc-900">Платежи</h3>
                <p className="text-sm text-zinc-500">Напоминания о регулярных платежах и кредитах</p>
              </div>
              <label className="relative inline-flex items-center cursor-pointer">
                <input 
                  type="checkbox" 
                  className="sr-only peer"
                  checked={notificationSettings?.payments ?? true}
                  onChange={(e) => updateNotificationSettings({ payments: e.target.checked })}
                />
                <div className="w-11 h-6 bg-stone-100 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
              </label>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
