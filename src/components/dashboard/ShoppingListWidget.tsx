import React, { useState } from 'react';
import { ShoppingCart, ArrowRight, ChevronUp, ChevronDown } from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion } from 'motion/react';

interface ShoppingListWidgetProps {
  shoppingItems: any[];
  shoppingCategories: any[];
}

export const ShoppingListWidget: React.FC<ShoppingListWidgetProps> = ({ shoppingItems, shoppingCategories }) => {
  const [showMoreShopping, setShowMoreShopping] = useState(false);

  return (
    <div className="bg-zinc-900/50 border border-zinc-800 rounded-2xl p-6">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-emerald-500/10 rounded-lg">
            <ShoppingCart className="w-5 h-5 text-emerald-500" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-white">Список покупок</h3>
            <p className="text-sm text-zinc-400">Актуальные пункты</p>
          </div>
        </div>
        <Link to="/shopping-list" className="p-2 hover:bg-zinc-800 rounded-lg text-zinc-400 hover:text-white transition-colors">
          <ArrowRight className="w-5 h-5" />
        </Link>
      </div>

      {shoppingItems.length > 0 && (
        <div className="mb-6 space-y-4">
          <div className="space-y-2">
            <div className="flex justify-between text-[10px] uppercase tracking-wider">
              <span className="text-zinc-500">Общий прогресс</span>
              <span className="text-white font-bold">
                {shoppingItems.filter(i => i.completed).length}/{shoppingItems.length}
              </span>
            </div>
            <div className="w-full bg-zinc-800 h-2 rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${(shoppingItems.filter(i => i.completed).length / shoppingItems.length) * 100}%` }}
                className="bg-emerald-500 h-full rounded-full" 
              />
            </div>
          </div>

          {/* Progress by Category */}
          <div className="grid grid-cols-2 gap-3">
            {shoppingCategories.slice(0, 4).map(cat => {
              const catItems = shoppingItems.filter(i => i.category === cat.id);
              if (catItems.length === 0) return null;
              const completed = catItems.filter(i => i.completed).length;
              const progress = (completed / catItems.length) * 100;
              return (
                <div key={cat.id} className="space-y-1">
                  <div className="flex justify-between text-[8px] uppercase tracking-tighter text-zinc-400">
                    <span className="truncate max-w-[60px]">{cat.name}</span>
                    <span>{completed}/{catItems.length}</span>
                  </div>
                  <div className="w-full bg-zinc-800 h-1 rounded-full overflow-hidden">
                    <div 
                      style={{ width: `${progress}%`, backgroundColor: cat.color || '#10b981' }}
                      className="h-full rounded-full opacity-80" 
                    />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
      <div className="space-y-3">
        {(showMoreShopping ? shoppingItems.filter(i => !i.completed) : shoppingItems.filter(i => !i.completed).slice(0, 3)).map(item => (
          <div key={item.id} className="flex items-center gap-3 p-3 bg-zinc-800/30 rounded-xl border border-zinc-700/50">
            <div className="w-2 h-2 rounded-full bg-emerald-500" />
            <span className="text-sm text-zinc-300 flex-1 truncate">{item.text}</span>
            {item.price && <span className="text-xs font-medium text-emerald-400">{item.price} ₽</span>}
          </div>
        ))}
        {shoppingItems.filter(i => !i.completed).length === 0 && (
          <div className="text-center py-4">
            <p className="text-sm text-zinc-500 italic">Список пуст</p>
          </div>
        )}
        {shoppingItems.filter(i => !i.completed).length > 3 && (
          <button 
            onClick={() => setShowMoreShopping(!showMoreShopping)}
            className="w-full py-2 text-xs text-center text-zinc-500 hover:text-zinc-400 flex items-center justify-center gap-1 transition-colors"
          >
            {showMoreShopping ? (
              <>Скрыть <ChevronUp className="w-3 h-3" /></>
            ) : (
              <>И еще {shoppingItems.filter(i => !i.completed).length - 3} пунктов... <ChevronDown className="w-3 h-3" /></>
            )}
          </button>
        )}
      </div>
    </div>
  );
};
