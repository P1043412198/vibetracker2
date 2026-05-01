import React, { useState, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Key, Plus, Search, Eye, EyeOff, Copy, Trash2, Edit2, Shield, Clock, X, Wand2, Check, Pin, FileText, Tag } from 'lucide-react';
import { useStore } from '../store/useStore';
import { PasswordEntry } from '../types';
import { cn } from '../lib/utils';
import * as OTPAuth from 'otpauth';

export function Passwords() {
  const { passwords = [], addPassword, updatePassword, deletePassword } = useStore();
  const [search, setSearch] = useState('');
  const [activeCategory, setActiveCategory] = useState<string>('all');
  const [isAdding, setIsAdding] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  const categories = useMemo(() => {
    const cats = new Set<string>();
    passwords.forEach(p => {
      if (p.category) cats.add(p.category);
    });
    return Array.from(cats).sort();
  }, [passwords]);

  const filteredPasswords = passwords
    .filter(p => {
      const matchesSearch = p.title.toLowerCase().includes(search.toLowerCase()) ||
        (p.username && p.username.toLowerCase().includes(search.toLowerCase())) ||
        (p.url && p.url.toLowerCase().includes(search.toLowerCase()));
      
      const matchesCategory = activeCategory === 'all' || p.category === activeCategory;
      
      return matchesSearch && matchesCategory;
    })
    .sort((a, b) => {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime();
    });

  return (
    <div className="space-y-6 pb-24">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white mb-1 flex items-center gap-2">
            <Shield className="w-6 h-6 text-indigo-400" />
            Пароли и 2FA
          </h1>
          <p className="text-sm text-zinc-400">Менеджер паролей и аутентификатор</p>
        </div>
        <button
          onClick={() => {
            setEditingId(null);
            setIsAdding(true);
          }}
          className="p-2.5 bg-indigo-500 text-white rounded-xl hover:bg-indigo-600 transition-colors shadow-lg shadow-indigo-500/20"
        >
          <Plus className="w-5 h-5" />
        </button>
      </header>

      {/* Search */}
      <div className="space-y-4">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-zinc-500" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Поиск паролей..."
            className="w-full bg-zinc-900/50 border border-zinc-800 rounded-xl pl-9 pr-4 py-2.5 text-sm text-white placeholder-zinc-500 focus:outline-none focus:border-indigo-500 transition-colors"
          />
        </div>

        {/* Categories */}
        <div className="flex flex-wrap gap-2 pb-2">
          <button
            onClick={() => setActiveCategory('all')}
            className={cn(
              "flex-1 sm:flex-none px-4 py-1.5 rounded-full text-xs font-medium transition-all whitespace-nowrap text-center border",
              activeCategory === 'all'
                ? "bg-indigo-500 border-indigo-500 text-white"
                : "bg-zinc-900/50 border-zinc-800 text-zinc-400 hover:border-zinc-700"
            )}
          >
            Все
          </button>
          {categories.map(cat => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={cn(
                "flex-1 sm:flex-none px-4 py-1.5 rounded-full text-xs font-medium transition-all whitespace-nowrap text-center border",
                activeCategory === cat
                  ? "bg-indigo-500 border-indigo-500 text-white"
                  : "bg-zinc-900/50 border-zinc-800 text-zinc-400 hover:border-zinc-700"
              )}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* List */}
      <div className="space-y-3">
        {filteredPasswords.map(entry => (
          <PasswordCard 
            key={entry.id} 
            entry={entry} 
            onEdit={() => {
              setEditingId(entry.id);
              setIsAdding(true);
            }}
            onDelete={() => deletePassword(entry.id)}
            onTogglePin={() => updatePassword(entry.id, { isPinned: !entry.isPinned })}
          />
        ))}
        {filteredPasswords.length === 0 && (
          <div className="text-center py-12 text-zinc-500">
            <Key className="w-12 h-12 mx-auto mb-4 opacity-20" />
            <p>Нет сохраненных паролей</p>
          </div>
        )}
      </div>

      <AnimatePresence>
        {isAdding && (
          <PasswordModal
            entry={editingId ? passwords.find(p => p.id === editingId) : undefined}
            onClose={() => {
              setIsAdding(false);
              setEditingId(null);
            }}
            onSave={(data) => {
              if (editingId) {
                updatePassword(editingId, data);
              } else {
                addPassword(data);
              }
              setIsAdding(false);
              setEditingId(null);
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

function PasswordCard({ entry, onEdit, onDelete, onTogglePin }: { entry: PasswordEntry, onEdit: () => void, onDelete: () => void, onTogglePin: () => void, key?: string }) {
  const [showPassword, setShowPassword] = useState(false);
  const [totpCode, setTotpCode] = useState<string | null>(null);
  const [totpProgress, setTotpProgress] = useState(0);

  useEffect(() => {
    if (!entry.totpSecret) return;

    let totp: OTPAuth.TOTP;
    try {
      // Handle both raw secret and otpauth URL
      if (entry.totpSecret.startsWith('otpauth://')) {
        totp = OTPAuth.URI.parse(entry.totpSecret) as OTPAuth.TOTP;
      } else {
        totp = new OTPAuth.TOTP({
          issuer: entry.title,
          label: entry.username || '',
          algorithm: 'SHA1',
          digits: 6,
          period: 30,
          secret: entry.totpSecret.replace(/\s+/g, '') // remove spaces
        });
      }
    } catch (e) {
      console.error('Invalid TOTP secret', e);
      return;
    }

    const updateTotp = () => {
      try {
        setTotpCode(totp.generate());
        const epoch = Math.floor(Date.now() / 1000);
        const period = totp.period;
        const remaining = period - (epoch % period);
        setTotpProgress((remaining / period) * 100);
      } catch (e) {
        // Ignore
      }
    };

    updateTotp();
    const interval = setInterval(updateTotp, 1000);
    return () => clearInterval(interval);
  }, [entry.totpSecret, entry.title, entry.username]);

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
  };

  return (
    <div className={`bg-zinc-900/50 border rounded-2xl p-4 space-y-4 transition-all duration-300 ${
      entry.isPinned 
        ? 'border-indigo-500/50 shadow-lg shadow-indigo-500/10 ring-1 ring-indigo-500/20' 
        : 'border-zinc-800/50'
    }`}>
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-3">
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center border transition-colors ${
            entry.isPinned ? 'bg-indigo-500/20 border-indigo-500/30' : 'bg-indigo-500/10 border-indigo-500/20'
          }`}>
            <Key className={`w-4 h-4 ${entry.isPinned ? 'text-indigo-300' : 'text-indigo-400'}`} />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="text-sm font-medium text-white">{entry.title}</h3>
              {entry.isPinned && <Pin className="w-3 h-3 text-indigo-400 fill-indigo-400" />}
              {entry.category && (
                <span className="px-1.5 py-0.5 rounded bg-zinc-800 text-[10px] text-zinc-400 border border-zinc-700 flex items-center gap-1">
                  <Tag className="w-2.5 h-2.5" />
                  {entry.category}
                </span>
              )}
            </div>
            {entry.username && <p className="text-xs text-zinc-400">{entry.username}</p>}
          </div>
        </div>
        <div className="flex items-center gap-1">
          <button 
            onClick={onTogglePin} 
            className={`p-1.5 rounded-lg transition-colors ${
              entry.isPinned 
                ? 'text-indigo-400 bg-indigo-500/10 hover:bg-indigo-500/20' 
                : 'text-zinc-400 hover:text-white hover:bg-zinc-800'
            }`}
            title={entry.isPinned ? "Открепить" : "Закрепить"}
          >
            <Pin className={`w-3.5 h-3.5 ${entry.isPinned ? 'fill-indigo-400' : ''}`} />
          </button>
          <button onClick={onEdit} className="p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors">
            <Edit2 className="w-3.5 h-3.5" />
          </button>
          <button onClick={onDelete} className="p-1.5 text-zinc-400 hover:text-red-400 hover:bg-zinc-800 rounded-lg transition-colors">
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {entry.password && (
        <div className="flex items-center gap-2 bg-zinc-950 p-1.5 rounded-lg border border-zinc-800/50">
          <div className="flex-1 font-mono text-xs text-zinc-300 px-2 tracking-wider">
            {showPassword ? entry.password : '••••••••••••'}
          </div>
          <button onClick={() => setShowPassword(!showPassword)} className="p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-md transition-colors">
            {showPassword ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
          </button>
          <button onClick={() => copyToClipboard(entry.password!)} className="p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-md transition-colors">
            <Copy className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {totpCode && (
        <div className="bg-indigo-500/5 border border-indigo-500/20 rounded-xl p-2.5 relative overflow-hidden">
          <div className="flex items-center justify-between relative z-10">
            <div className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-indigo-400" />
              <span className="text-[10px] font-medium text-indigo-400 uppercase tracking-wider">Код аутентификации</span>
            </div>
            <button onClick={() => copyToClipboard(totpCode)} className="p-1 text-indigo-400 hover:text-indigo-300 hover:bg-indigo-500/20 rounded-md transition-colors">
              <Copy className="w-3.5 h-3.5" />
            </button>
          </div>
          <div className="mt-1 font-mono text-xl font-bold text-white tracking-[0.2em] relative z-10">
            {totpCode.slice(0, 3)} {totpCode.slice(3)}
          </div>
          
          {/* Progress bar */}
          <div className="absolute bottom-0 left-0 h-1 bg-indigo-500/10 w-full">
            <div 
              className="h-full bg-indigo-500 transition-all duration-1000 ease-linear"
              style={{ width: `${totpProgress}%` }}
            />
          </div>
        </div>
      )}

      {entry.notes && (
        <div className="bg-zinc-950/50 border border-zinc-800/50 rounded-xl p-3">
          <div className="flex items-center gap-2 mb-1.5">
            <FileText className="w-3 h-3 text-zinc-500" />
            <span className="text-[10px] font-medium text-zinc-500 uppercase tracking-wider">Заметки</span>
          </div>
          <p className="text-xs text-zinc-400 whitespace-pre-wrap leading-relaxed">{entry.notes}</p>
        </div>
      )}
    </div>
  );
}

const PARANOIA_LEVELS = [
  { value: 1, label: 'Для форума', color: 'bg-emerald-500', textColor: 'text-emerald-500', length: 8, chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', desc: '8 символов, буквы и цифры' },
  { value: 2, label: 'Стандарт', color: 'bg-yellow-500', textColor: 'text-yellow-500', length: 12, chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*', desc: '12 символов, спецсимволы' },
  { value: 3, label: 'Секретный агент', color: 'bg-orange-500', textColor: 'text-orange-500', length: 16, chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?', desc: '16 символов, сложный микс' },
  { value: 4, label: 'Шапочка из фольги', color: 'bg-red-500', textColor: 'text-red-500', length: 32, chars: 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?~`', desc: '32 символа, полная жесть' }
];

function PasswordModal({ entry, onClose, onSave }: { entry?: PasswordEntry, onClose: () => void, onSave: (data: any) => void }) {
  const { customPasswordWord, scatterPasswordWord } = useStore();
  const [showGenerator, setShowGenerator] = useState(false);
  const [paranoiaLevel, setParanoiaLevel] = useState(2);
  const [copied, setCopied] = useState(false);
  const [formData, setFormData] = useState({
    title: entry?.title || '',
    username: entry?.username || '',
    password: entry?.password || '',
    url: entry?.url || '',
    totpSecret: entry?.totpSecret || '',
    category: entry?.category || '',
    notes: entry?.notes || ''
  });

  const handleGenerate = (level: number) => {
    const config = PARANOIA_LEVELS[level - 1];
    const target = customPasswordWord || "";
    
    const finalLength = Math.max(config.length, target.length);
    const randomCount = finalLength - target.length;
    
    let randomChars = '';
    const charactersLength = config.chars.length;
    
    if (randomCount > 0) {
      const randomArray = new Uint32Array(randomCount);
      crypto.getRandomValues(randomArray);
      for (let i = 0; i < randomCount; i++) {
        randomChars += config.chars[randomArray[i] % charactersLength];
      }
    }
    
    let result = '';
    
    if (!target) {
      result = randomChars;
    } else if (scatterPasswordWord) {
      let availablePositions = Array.from({ length: finalLength }, (_, i) => i);
      
      for (let i = availablePositions.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [availablePositions[i], availablePositions[j]] = [availablePositions[j], availablePositions[i]];
      }
      
      const targetPositions = availablePositions.slice(0, target.length).sort((a, b) => a - b);
      
      let targetIdx = 0;
      let randomIdx = 0;
      
      for (let i = 0; i < finalLength; i++) {
        if (targetPositions.includes(i)) {
          result += target[targetIdx++];
        } else {
          result += randomChars[randomIdx++];
        }
      }
    } else {
      const leftCount = Math.floor(randomCount / 2);
      const leftPart = randomChars.slice(0, leftCount);
      const rightPart = randomChars.slice(leftCount);
      result = leftPart + target + rightPart;
    }
    
    setFormData(prev => ({ ...prev, password: result }));
  };

  const handleCopy = () => {
    if (formData.password) {
      navigator.clipboard.writeText(formData.password);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.title.trim()) return;
    onSave(formData);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm">
      <motion.div
        initial={{ opacity: 0, y: "100%" }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: "100%" }}
        transition={{ type: "spring", damping: 25, stiffness: 200 }}
        className="bg-zinc-900 border-t sm:border border-zinc-800 rounded-t-3xl sm:rounded-2xl w-full max-w-md flex flex-col h-[88dvh] sm:h-auto sm:max-h-[90vh] overflow-hidden shadow-2xl"
      >
        <div className="w-12 h-1 bg-zinc-800 rounded-full mx-auto mt-2 mb-1 sm:hidden shrink-0" />
        <form onSubmit={handleSubmit} className="flex flex-col flex-1 min-h-0">
          {/* Header - Fixed */}
          <div className="px-4 py-2 border-b border-zinc-800 flex items-center justify-between bg-zinc-900 shrink-0">
            <h2 className="text-sm font-semibold text-white">
              {entry ? 'Редактировать пароль' : 'Новый пароль'}
            </h2>
            <button type="button" onClick={onClose} className="p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors">
              <X className="w-4 h-4" />
            </button>
          </div>

          {/* Content - Scrollable */}
          <div className="p-4 overflow-y-auto flex-1 min-h-0 space-y-4 scrollbar-thin scrollbar-thumb-zinc-800">
            <div className="space-y-3 pb-6">
              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">Название сервиса *</label>
                <input
                  type="text"
                  required
                  value={formData.title}
                  onChange={e => setFormData({ ...formData, title: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
                  placeholder="Google, GitHub, VK..."
                />
              </div>

              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">Логин / Email</label>
                <input
                  type="text"
                  value={formData.username}
                  onChange={e => setFormData({ ...formData, username: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
                  placeholder="user@example.com"
                />
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider">Пароль</label>
                  <button
                    type="button"
                    onClick={() => {
                      setShowGenerator(!showGenerator);
                      if (!showGenerator && !formData.password) {
                        handleGenerate(paranoiaLevel);
                      }
                    }}
                    className="text-[10px] text-indigo-400 hover:text-indigo-300 flex items-center gap-1 transition-colors font-medium"
                  >
                    <Wand2 className="w-3 h-3" />
                    Генератор
                  </button>
                </div>
                <div className="relative">
                  <input
                    type="text"
                    value={formData.password}
                    onChange={e => setFormData({ ...formData, password: e.target.value })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-xl pl-3 pr-10 py-2 text-sm text-white focus:outline-none focus:border-indigo-500 font-mono"
                    placeholder="••••••••••••"
                  />
                  <button
                    type="button"
                    onClick={handleCopy}
                    className="absolute right-1.5 top-1/2 -translate-y-1/2 p-1.5 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors"
                  >
                    {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
                  </button>
                </div>
                
                <AnimatePresence>
                  {showGenerator && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      className="overflow-hidden"
                    >
                      <div className="mt-3 p-3 bg-zinc-950 border border-zinc-800 rounded-xl space-y-3">
                        <div className="flex items-center justify-between">
                          <span className="text-[10px] font-medium text-zinc-400 uppercase tracking-wider">Уровень паранойи</span>
                          <span className={`text-[10px] font-bold ${PARANOIA_LEVELS[paranoiaLevel - 1].textColor}`}>
                            {PARANOIA_LEVELS[paranoiaLevel - 1].label}
                          </span>
                        </div>
                        
                        <input
                          type="range"
                          min="1"
                          max="4"
                          step="1"
                          value={paranoiaLevel}
                          onChange={(e) => {
                            const newLevel = parseInt(e.target.value);
                            setParanoiaLevel(newLevel);
                            handleGenerate(newLevel);
                          }}
                          className="w-full accent-indigo-500"
                        />
                        
                        <div className="flex justify-between text-[8px] text-zinc-600 font-bold uppercase tracking-widest">
                          <span>Простой</span>
                          <span>Жесть</span>
                        </div>
                        
                        <p className="text-[9px] text-zinc-500 text-center leading-tight">
                          {PARANOIA_LEVELS[paranoiaLevel - 1].desc}
                        </p>
                        
                        <button
                          type="button"
                          onClick={() => handleGenerate(paranoiaLevel)}
                          className="w-full py-1.5 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 text-[10px] font-bold uppercase tracking-wider rounded-lg transition-colors border border-zinc-800"
                        >
                          Сгенерировать другой
                        </button>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>

              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">Ключ 2FA (TOTP Secret)</label>
                <input
                  type="text"
                  value={formData.totpSecret}
                  onChange={e => setFormData({ ...formData, totpSecret: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-indigo-500 font-mono text-xs"
                  placeholder="JBSWY3DPEHPK3PXP"
                />
              </div>

              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">Категория</label>
                <input
                  type="text"
                  list="password-categories"
                  value={formData.category}
                  onChange={e => setFormData({ ...formData, category: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
                  placeholder="Работа, Личное, Финансы..."
                />
                <datalist id="password-categories">
                  {Array.from(new Set(useStore.getState().passwords?.map(p => p.category).filter(Boolean))).map(cat => (
                    <option key={cat} value={cat} />
                  ))}
                </datalist>
              </div>

              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">URL сайта</label>
                <input
                  type="text"
                  value={formData.url}
                  onChange={e => setFormData({ ...formData, url: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500"
                  placeholder="example.com"
                />
              </div>

              <div>
                <label className="block text-[10px] font-medium text-zinc-500 uppercase tracking-wider mb-1">Заметки</label>
                <textarea
                  value={formData.notes}
                  onChange={e => setFormData({ ...formData, notes: e.target.value })}
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-sm text-white focus:outline-none focus:border-indigo-500 min-h-[60px]"
                  placeholder="Дополнительная информация..."
                />
              </div>
            </div>
          </div>

          {/* Footer - Fixed */}
          <div className="p-3 pb-12 sm:pb-3 pb-safe border-t border-zinc-800 bg-zinc-900 shrink-0">
            <button
              type="submit"
              className="w-full py-2.5 text-xs bg-indigo-500 text-white rounded-xl font-bold uppercase tracking-wider hover:bg-indigo-600 transition-colors shadow-lg shadow-indigo-500/20 active:scale-[0.98]"
            >
              Сохранить
            </button>
          </div>
        </form>
      </motion.div>
    </div>
  );
}
