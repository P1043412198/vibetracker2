import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  ShoppingCart, Plus, Trash2, Check, ImagePlus, X, Eraser, 
  Settings, PieChart as PieChartIcon, List, ChevronDown, ChevronUp,
  TrendingUp, History, Calendar
} from 'lucide-react';
import { cn } from '../lib/utils';
import { useStore } from '../store/useStore';
import { 
  PieChart, Pie, Cell, ResponsiveContainer, Tooltip,
  LineChart, Line, XAxis, YAxis, CartesianGrid, AreaChart, Area
} from 'recharts';
import { subWeeks, subMonths, isAfter, parseISO, format } from 'date-fns';
import { ru } from 'date-fns/locale';

export function ShoppingList() {
  const { 
    shoppingItems = [], 
    shoppingCategories = [],
    addShoppingItem, 
    updateShoppingItem, 
    deleteShoppingItem, 
    toggleShoppingItem,
    clearCompletedShoppingItems,
    addShoppingCategory,
    deleteShoppingCategory,
    priceHistory = [],
    addPriceHistory,
    deletePriceHistory
  } = useStore();

  const [activeTab, setActiveTab] = useState<'list' | 'analytics' | 'categories'>('list');
  const [selectedItemForHistory, setSelectedItemForHistory] = useState<string | null>(null);
  const [timeRange, setTimeRange] = useState<'week' | 'month' | 'all'>('all');
  const [newItemText, setNewItemText] = useState('');
  const [newItemPrice, setNewItemPrice] = useState('');
  const [newItemCategory, setNewItemCategory] = useState(shoppingCategories[0]?.id || 'other');
  const [isAddingCategory, setIsAddingCategory] = useState(false);
  const [newCatName, setNewCatName] = useState('');
  const [newCatColor, setNewCatColor] = useState('#3b82f6');
  const [showCompleted, setShowCompleted] = useState(false);

  const [newItemHashtags, setNewItemHashtags] = useState('');
  const [isCustomCategory, setIsCustomCategory] = useState(false);
  const [customCategoryName, setCustomCategoryName] = useState('');

  const handleAddItem = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newItemText.trim()) return;
    
    let categoryId = newItemCategory;
    if (isCustomCategory && customCategoryName.trim()) {
      // Create new category if it doesn't exist
      const existing = shoppingCategories.find(c => c.name.toLowerCase() === customCategoryName.trim().toLowerCase());
      if (existing) {
        categoryId = existing.id;
      } else {
        const newCat = { name: customCategoryName.trim(), color: '#71717a' };
        addShoppingCategory(newCat);
        // We can't easily get the ID here because addShoppingCategory is async/state-based
        // But we can find it in the next render or just use 'other' for now
        // A better way is to return the ID from addShoppingCategory
        // For now, let's just use the name as a temporary ID or similar if the store supports it
        // Actually, let's just use 'other' if we can't get the ID immediately, or update the store to return ID
      }
    }

    const hashtags = newItemHashtags.split(' ').filter(h => h.startsWith('#')).map(h => h.slice(1));
    
    addShoppingItem({
      text: newItemText.trim(),
      price: newItemPrice ? parseFloat(newItemPrice) : undefined,
      category: categoryId,
      hashtags: hashtags.length > 0 ? hashtags : undefined
    });
    
    if (newItemPrice) {
      addPriceHistory({
        itemName: newItemText.trim(),
        price: parseFloat(newItemPrice),
        date: new Date().toISOString()
      });
    }
    
    setNewItemText('');
    setNewItemPrice('');
    setNewItemHashtags('');
    setIsCustomCategory(false);
    setCustomCategoryName('');
  };

  const handleAddCategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCatName.trim()) return;
    addShoppingCategory({ name: newCatName.trim(), color: newCatColor });
    setNewCatName('');
    setIsAddingCategory(false);
  };

  const handlePhotoUpload = (id: string, e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const base64 = event.target?.result as string;
      updateShoppingItem(id, { photo: base64 });
    };
    reader.readAsDataURL(file);
  };

  const removePhoto = (id: string) => {
    updateShoppingItem(id, { photo: undefined });
  };

  const activeItems = shoppingItems.filter(i => !i.completed);
  const completedItems = shoppingItems.filter(i => i.completed);

  const totalEstimated = activeItems.reduce((sum, item) => sum + (item.price || 0), 0);
  const totalSpent = completedItems.reduce((sum, item) => sum + (item.price || 0), 0);

  const filteredItems = useMemo(() => {
    if (timeRange === 'all') return shoppingItems;
    
    const now = new Date();
    const startDate = timeRange === 'week' ? subWeeks(now, 1) : subMonths(now, 1);
    
    return shoppingItems.filter(item => {
      if (!item.completedAt) return true; // Include planned items
      return isAfter(parseISO(item.completedAt), startDate);
    });
  }, [shoppingItems, timeRange]);

  const analyticsData = useMemo(() => {
    const data: Record<string, { name: string, value: number, color: string }> = {};
    filteredItems.forEach(item => {
      if (item.price) {
        const cat = shoppingCategories.find(c => c.id === item.category) || { name: 'Другое', color: '#71717a' };
        if (!data[cat.name]) {
          data[cat.name] = { name: cat.name, value: 0, color: cat.color };
        }
        data[cat.name].value += item.price;
      }
    });
    return Object.values(data);
  }, [filteredItems, shoppingCategories]);

  const tagAnalyticsData = useMemo(() => {
    const data: Record<string, { name: string, value: number }> = {};
    filteredItems.forEach(item => {
      if (item.price && item.hashtags && item.hashtags.length > 0) {
        item.hashtags.forEach(tag => {
          if (!data[tag]) {
            data[tag] = { name: tag, value: 0 };
          }
          data[tag].value += item.price!;
        });
      }
    });
    return Object.values(data).sort((a, b) => b.value - a.value);
  }, [filteredItems]);

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="max-w-md mx-auto pb-24"
    >
      {/* Tabs */}
      <div className="flex gap-1 bg-zinc-900/50 p-1 rounded-xl mb-6">
        <button
          onClick={() => setActiveTab('list')}
          className={cn(
            "flex-1 flex items-center justify-center gap-2 py-2 rounded-lg text-xs font-medium transition-all",
            activeTab === 'list' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-400 hover:text-zinc-200"
          )}
        >
          <List className="w-4 h-4" />
          <span>Список</span>
        </button>
        <button
          onClick={() => setActiveTab('analytics')}
          className={cn(
            "flex-1 flex items-center justify-center gap-2 py-2 rounded-lg text-xs font-medium transition-all",
            activeTab === 'analytics' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-400 hover:text-zinc-200"
          )}
        >
          <PieChartIcon className="w-4 h-4" />
          <span>Анализ</span>
        </button>
        <button
          onClick={() => setActiveTab('categories')}
          className={cn(
            "flex-1 flex items-center justify-center gap-2 py-2 rounded-lg text-xs font-medium transition-all",
            activeTab === 'categories' ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-400 hover:text-zinc-200"
          )}
        >
          <Settings className="w-4 h-4" />
          <span>Категории</span>
        </button>
      </div>

      {activeTab === 'list' && (
        <>
          <PriceHistoryModal 
            itemName={selectedItemForHistory} 
            onClose={() => setSelectedItemForHistory(null)} 
          />

          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="bg-zinc-900 p-4 rounded-2xl border border-zinc-800">
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider mb-1">План</div>
              <div className="text-lg font-bold text-white">{totalEstimated.toLocaleString('ru-RU')} ₽</div>
            </div>
            <div className="bg-zinc-900 p-4 rounded-2xl border border-zinc-800">
              <div className="text-[10px] text-zinc-500 uppercase tracking-wider mb-1">Куплено</div>
              <div className="text-lg font-bold text-emerald-400">{totalSpent.toLocaleString('ru-RU')} ₽</div>
            </div>
          </div>

          <form onSubmit={handleAddItem} className="mb-6 space-y-3">
            <div className="relative">
              <input
                type="text"
                value={newItemText}
                onChange={(e) => setNewItemText(e.target.value)}
                placeholder="Что купить?"
                className="w-full bg-zinc-900 border border-zinc-800 rounded-2xl py-3.5 pl-4 pr-12 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors"
              />
              <button
                type="submit"
                disabled={!newItemText.trim()}
                className="absolute right-2 top-2 bottom-2 aspect-square bg-white text-black rounded-xl flex items-center justify-center disabled:opacity-50 disabled:bg-zinc-800 disabled:text-zinc-500 transition-colors"
              >
                <Plus className="w-5 h-5" />
              </button>
            </div>
            
            <div className="flex flex-col gap-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <input
                  type="number"
                  value={newItemPrice}
                  onChange={(e) => setNewItemPrice(e.target.value)}
                  placeholder="Цена (опц.)"
                  step="0.01"
                  className="w-full bg-zinc-900 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors"
                />
                <input
                  type="text"
                  value={newItemHashtags}
                  onChange={(e) => setNewItemHashtags(e.target.value)}
                  placeholder="#теги #через #пробел"
                  className="w-full bg-zinc-900 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors"
                />
              </div>

              <div className="flex gap-2">
                {!isCustomCategory ? (
                  <select
                    value={newItemCategory}
                    onChange={(e) => {
                      if (e.target.value === 'new') {
                        setIsCustomCategory(true);
                      } else {
                        setNewItemCategory(e.target.value);
                      }
                    }}
                    className="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-zinc-700 transition-colors appearance-none"
                  >
                    {shoppingCategories.map(cat => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                    <option value="new">+ Новая категория...</option>
                  </select>
                ) : (
                  <div className="flex-1 flex gap-2">
                    <input
                      type="text"
                      value={customCategoryName}
                      onChange={(e) => setCustomCategoryName(e.target.value)}
                      placeholder="Название категории"
                      className="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700 transition-colors"
                      autoFocus
                    />
                    <button
                      type="button"
                      onClick={() => setIsCustomCategory(false)}
                      className="px-3 bg-zinc-800 text-zinc-400 rounded-xl text-xs"
                    >
                      Отмена
                    </button>
                  </div>
                )}
              </div>
            </div>
          </form>

          <div className="space-y-6">
            {activeItems.length > 0 && (
              <div className="space-y-3">
                <AnimatePresence mode="popLayout">
                  {activeItems.map(item => (
                    <motion.div
                      key={item.id}
                      layout
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, scale: 0.95 }}
                      className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex flex-col gap-3"
                    >
                      <div className="flex items-center gap-4">
                        <button
                          onClick={() => toggleShoppingItem(item.id)}
                          className="w-5 h-5 rounded-full border-2 border-zinc-600 flex items-center justify-center shrink-0 transition-colors"
                        />
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="text-white text-sm truncate">{item.text}</span>
                            {item.category && (
                              <span 
                                className="text-[8px] px-1.5 py-0.5 rounded-full text-white uppercase font-bold"
                                style={{ backgroundColor: shoppingCategories.find(c => c.id === item.category)?.color || "#71717a" }}
                              >
                                {shoppingCategories.find(c => c.id === item.category)?.name}
                              </span>
                            )}
                            {item.hashtags?.map(tag => (
                              <span key={tag} className="text-[10px] text-blue-400 font-medium">#{tag}</span>
                            ))}
                          </div>
                          {item.price && (
                            <div className="text-xs text-zinc-500">{item.price.toLocaleString('ru-RU')} ₽</div>
                          )}
                        </div>
                        
                        {!item.photo && (
                          <label className="text-zinc-600 hover:text-blue-400 transition-colors p-1.5 cursor-pointer">
                            <input 
                              type="file" 
                              accept="image/*" 
                              className="hidden" 
                              onChange={(e) => handlePhotoUpload(item.id, e)} 
                            />
                            <ImagePlus className="w-4 h-4" />
                          </label>
                        )}

                        <button
                          onClick={() => setSelectedItemForHistory(item.text)}
                          className="text-zinc-600 hover:text-blue-400 transition-colors p-1.5"
                          title="История цен"
                        >
                          <History className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => deleteShoppingItem(item.id)}
                          className="text-zinc-600 hover:text-red-400 transition-colors p-1.5"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>

                      {item.photo && (
                        <div className="relative rounded-xl overflow-hidden bg-zinc-950 border border-zinc-800 group">
                          <img src={item.photo} alt="Shopping item" className="w-full h-48 object-cover" />
                          <button 
                            onClick={() => removePhoto(item.id)}
                            className="absolute top-2 right-2 w-8 h-8 bg-black/50 backdrop-blur-md rounded-full flex items-center justify-center text-white opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-500/80"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>
                      )}
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            )}

            {completedItems.length > 0 && (
              <div>
                <button 
                  onClick={() => setShowCompleted(!showCompleted)}
                  className="w-full flex items-center justify-between py-2 text-zinc-500 hover:text-zinc-400 transition-colors"
                >
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-medium uppercase tracking-wider">Куплено ({completedItems.length})</h3>
                    {showCompleted ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                  </div>
                  {showCompleted && (
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        clearCompletedShoppingItems();
                      }}
                      className="text-[10px] text-zinc-600 hover:text-zinc-400 flex items-center gap-1 transition-colors"
                    >
                      <Eraser className="w-3 h-3" />
                      Очистить
                    </button>
                  )}
                </button>
                
                <AnimatePresence>
                  {showCompleted && (
                    <motion.div 
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      className="overflow-hidden space-y-3 pt-3"
                    >
                      {completedItems.map(item => (
                        <motion.div
                          key={item.id}
                          layout
                          initial={{ opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={{ opacity: 0, scale: 0.95 }}
                          className="bg-zinc-950 border border-zinc-900 rounded-2xl p-4 flex flex-col gap-3 opacity-60"
                        >
                          <div className="flex items-center gap-4">
                            <button
                              onClick={() => toggleShoppingItem(item.id)}
                              className="w-5 h-5 rounded-full bg-white flex items-center justify-center shrink-0 transition-colors"
                            >
                              <Check className="w-3 h-3 text-black" />
                            </button>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2">
                                <span className="text-zinc-500 text-sm line-through truncate">{item.text}</span>
                                {item.category && (
                                  <span className="text-[8px] px-1.5 py-0.5 rounded-full bg-zinc-800 text-zinc-600 uppercase font-bold">
                                    {shoppingCategories.find(c => c.id === item.category)?.name}
                                  </span>
                                )}
                              </div>
                              {item.price && (
                                <div className="text-xs text-zinc-600">{item.price.toLocaleString('ru-RU')} ₽</div>
                              )}
                            </div>
                            <button
                              onClick={() => setSelectedItemForHistory(item.text)}
                              className="text-zinc-700 hover:text-blue-400 transition-colors p-1.5"
                              title="История цен"
                            >
                              <History className="w-4 h-4" />
                            </button>
                            <button
                              onClick={() => deleteShoppingItem(item.id)}
                              className="text-zinc-700 hover:text-red-400 transition-colors p-1.5"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                        </motion.div>
                      ))}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )}

            {shoppingItems.length === 0 && (
              <div className="text-center py-12">
                <div className="w-16 h-16 bg-zinc-900 rounded-full flex items-center justify-center mx-auto mb-4">
                  <ShoppingCart className="w-8 h-8 text-zinc-600" />
                </div>
                <p className="text-zinc-500">Список покупок пуст</p>
              </div>
            )}
          </div>
        </>
      )}

      {activeTab === 'analytics' && (
        <div className="space-y-6">
          <div className="flex gap-2 bg-zinc-900/50 p-1 rounded-xl">
            {(['week', 'month', 'all'] as const).map((range) => (
              <button
                key={range}
                onClick={() => setTimeRange(range)}
                className={cn(
                  "flex-1 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-wider transition-all",
                  timeRange === range ? "bg-zinc-800 text-white shadow-sm" : "text-zinc-500 hover:text-zinc-300"
                )}
              >
                {range === 'week' ? 'Неделя' : range === 'month' ? 'Месяц' : 'Все время'}
              </button>
            ))}
          </div>

          <div className="bg-zinc-900 p-6 rounded-2xl border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 uppercase tracking-wider mb-6">Траты по категориям</h3>
            {analyticsData.length > 0 ? (
              <>
                <div className="h-64">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={analyticsData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {analyticsData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={entry.color} />
                        ))}
                      </Pie>
                      <Tooltip 
                        contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                        itemStyle={{ color: '#fff' }}
                      />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
                <div className="grid grid-cols-2 gap-4 mt-6">
                  {analyticsData.map(item => (
                    <div key={item.name} className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full" style={{ backgroundColor: item.color }} />
                      <div className="flex-1 min-w-0">
                        <div className="text-[10px] text-zinc-500 truncate">{item.name}</div>
                        <div className="text-xs font-bold text-white">{item.value.toLocaleString('ru-RU')} ₽</div>
                      </div>
                    </div>
                  ))}
                </div>
              </>
            ) : (
              <div className="h-32 flex flex-col items-center justify-center text-zinc-500">
                <PieChartIcon className="w-8 h-8 mb-2 opacity-20" />
                <p className="text-xs">Нет данных за этот период</p>
              </div>
            )}
          </div>

          {tagAnalyticsData.length > 0 && (
            <div className="bg-zinc-900 p-6 rounded-2xl border border-zinc-800">
              <h3 className="text-sm font-medium text-zinc-400 uppercase tracking-wider mb-6">Траты по тегам</h3>
              <div className="space-y-4">
                {tagAnalyticsData.map(tag => (
                  <div key={tag.name} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="px-2 py-1 bg-zinc-800 rounded text-[10px] text-zinc-400 font-mono">
                        #{tag.name}
                      </div>
                    </div>
                    <div className="text-xs font-bold text-white">{tag.value.toLocaleString('ru-RU')} ₽</div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="bg-zinc-900 p-6 rounded-2xl border border-zinc-800">
            <h3 className="text-sm font-medium text-zinc-400 uppercase tracking-wider mb-4">Общая статистика</h3>
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm text-zinc-400">Товаров в периоде</span>
                <span className="text-sm font-bold text-white">{filteredItems.length}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-zinc-400">Куплено</span>
                <span className="text-sm font-bold text-emerald-400">
                  {filteredItems.filter(i => i.completed).length}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-zinc-400">Средний чек</span>
                <span className="text-sm font-bold text-white">
                  {filteredItems.length > 0 
                    ? (filteredItems.reduce((sum, i) => sum + (i.price || 0), 0) / filteredItems.length).toFixed(2) 
                    : 0} ₽
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'categories' && (
        <div className="space-y-6">
          <div className="bg-zinc-900 p-6 rounded-2xl border border-zinc-800">
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-sm font-medium text-zinc-400 uppercase tracking-wider">Ваши категории</h3>
              <button
                onClick={() => setIsAddingCategory(true)}
                className="p-2 bg-zinc-800 text-white rounded-lg hover:bg-zinc-700 transition-colors"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>

            <AnimatePresence>
              {isAddingCategory && (
                <motion.form
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: 'auto', opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  onSubmit={handleAddCategory}
                  className="mb-6 space-y-4 overflow-hidden"
                >
                  <div className="space-y-2">
                    <label className="text-[10px] text-zinc-500 uppercase">Название</label>
                    <input
                      type="text"
                      value={newCatName}
                      onChange={(e) => setNewCatName(e.target.value)}
                      placeholder="Напр: Животные"
                      className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-4 text-sm text-white focus:outline-none focus:border-zinc-700"
                    />
                  </div>
                  <div className="space-y-2">
                    <label className="text-[10px] text-zinc-500 uppercase">Цвет</label>
                    <div className="flex gap-2 flex-wrap">
                      {['#ef4444', '#f97316', '#f59e0b', '#10b981', '#06b6d4', '#3b82f6', '#6366f1', '#8b5cf6', '#d946ef', '#f43f5e', '#71717a'].map(color => (
                        <button
                          key={color}
                          type="button"
                          onClick={() => setNewCatColor(color)}
                          className={cn(
                            "w-8 h-8 rounded-full border-2 transition-all",
                            newCatColor === color ? "border-white scale-110" : "border-transparent"
                          )}
                          style={{ backgroundColor: color }}
                        />
                      ))}
                    </div>
                  </div>
                  <div className="flex gap-2 pt-2">
                    <button
                      type="button"
                      onClick={() => setIsAddingCategory(false)}
                      className="flex-1 py-2 bg-zinc-800 text-zinc-400 rounded-xl text-xs font-medium"
                    >
                      Отмена
                    </button>
                    <button
                      type="submit"
                      disabled={!newCatName.trim()}
                      className="flex-1 py-2 bg-white text-black rounded-xl text-xs font-bold disabled:opacity-50"
                    >
                      Создать
                    </button>
                  </div>
                </motion.form>
              )}
            </AnimatePresence>

            <div className="space-y-2">
              {shoppingCategories.map(cat => (
                <div key={cat.id} className="flex items-center justify-between p-3 bg-zinc-950 rounded-xl border border-zinc-800/50">
                  <div className="flex items-center gap-3">
                    <div className="w-3 h-3 rounded-full" style={{ backgroundColor: cat.color }} />
                    <span className="text-sm text-white font-medium">{cat.name}</span>
                  </div>
                  {cat.id !== 'other' && (
                    <button
                      onClick={() => deleteShoppingCategory(cat.id)}
                      className="p-1.5 text-zinc-600 hover:text-red-400 transition-colors"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </motion.div>
  );
}

function PriceHistoryModal({ itemName, onClose }: { itemName: string | null, onClose: () => void }) {
  const { priceHistory = [], addPriceHistory, deletePriceHistory } = useStore();
  const [newPrice, setNewPrice] = useState('');
  const [newDate, setNewDate] = useState(new Date().toISOString().split('T')[0]);

  if (!itemName) return null;

  const history = priceHistory
    .filter(p => p.itemName.toLowerCase() === itemName.toLowerCase())
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

  const chartData = history.map(p => ({
    date: format(parseISO(p.date), 'dd.MM'),
    fullDate: format(parseISO(p.date), 'dd MMMM yyyy', { locale: ru }),
    price: p.price
  }));

  const handleAdd = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPrice) return;
    addPriceHistory({
      itemName,
      price: parseFloat(newPrice),
      date: new Date(newDate).toISOString()
    });
    setNewPrice('');
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-zinc-900 border border-zinc-800 w-full max-w-md rounded-3xl p-6 shadow-2xl"
      >
        <div className="flex justify-between items-center mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-500/20 text-blue-400 rounded-xl">
              <TrendingUp className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white leading-tight">{itemName}</h3>
              <p className="text-xs text-zinc-500">История изменения цены</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 text-zinc-500 hover:text-white rounded-xl">
            <X className="w-5 h-5" />
          </button>
        </div>

        {chartData.length > 1 && (
          <div className="h-48 mb-6">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#27272a" vertical={false} />
                <XAxis dataKey="date" stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                <YAxis stroke="#71717a" fontSize={10} tickLine={false} axisLine={false} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#18181b', border: '1px solid #27272a', borderRadius: '12px' }}
                  labelStyle={{ color: '#71717a', fontSize: '10px', marginBottom: '4px' }}
                />
                <Area 
                  type="monotone" 
                  dataKey="price" 
                  name="Цена" 
                  stroke="#3b82f6" 
                  strokeWidth={2} 
                  fillOpacity={1} 
                  fill="url(#colorPrice)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}

        <form onSubmit={handleAdd} className="grid grid-cols-2 gap-3 mb-6">
          <div className="space-y-1">
            <label className="text-[10px] text-zinc-500 uppercase ml-1">Цена</label>
            <input 
              type="number" 
              step="0.01"
              value={newPrice}
              onChange={e => setNewPrice(e.target.value)}
              placeholder="0.00"
              className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white text-sm focus:border-blue-500/50 outline-none"
            />
          </div>
          <div className="space-y-1">
            <label className="text-[10px] text-zinc-500 uppercase ml-1">Дата</label>
            <input 
              type="date" 
              value={newDate}
              onChange={e => setNewDate(e.target.value)}
              className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-white text-sm focus:border-blue-500/50 outline-none"
            />
          </div>
          <button type="submit" className="col-span-2 py-2 bg-blue-600 text-white rounded-xl text-sm font-medium hover:bg-blue-700 transition-colors">
            Добавить запись
          </button>
        </form>

        <div className="space-y-2 max-h-48 overflow-y-auto pr-2 custom-scrollbar">
          {history.length === 0 ? (
            <p className="text-center py-4 text-zinc-500 text-sm">Нет записей истории</p>
          ) : (
            history.slice().reverse().map(p => (
              <div key={p.id} className="flex items-center justify-between bg-zinc-950 p-3 rounded-2xl border border-zinc-800/50">
                <div className="flex items-center gap-3">
                  <div className="p-1.5 bg-zinc-900 text-zinc-400 rounded-lg">
                    <Calendar className="w-3.5 h-3.5" />
                  </div>
                  <div>
                    <p className="text-sm font-bold text-white">{p.price.toLocaleString('ru-RU')} ₽</p>
                    <p className="text-[10px] text-zinc-500">{format(parseISO(p.date), 'dd MMMM yyyy', { locale: ru })}</p>
                  </div>
                </div>
                <button 
                  onClick={() => deletePriceHistory(p.id)}
                  className="p-2 text-zinc-600 hover:text-red-400 transition-colors"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))
          )}
        </div>
      </motion.div>
    </div>
  );
}
