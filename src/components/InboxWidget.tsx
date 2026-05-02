import React, { useState } from 'react';
import { useStore } from '../store/useStore';
import { Inbox, Plus, Trash2, CheckCircle2 } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { motion, AnimatePresence } from 'motion/react';
import { cn } from '../lib/utils';

export function InboxWidget() {
  const { inboxItems, addInboxItem, deleteInboxItem, addTask } = useStore();
  const [newContent, setNewContent] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newContent.trim()) return;
    addInboxItem(newContent.trim());
    setNewContent('');
  };

  const handleConvertToTask = (item: { id: string, content: string }) => {
    addTask({
      title: item.content,
      period: 'day',
      date: format(new Date(), 'yyyy-MM-dd'),
    });
    deleteInboxItem(item.id);
  };

  return (
    <div className="bg-white p-4 rounded-3xl shadow-sm border border-stone-200">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-zinc-900 flex items-center gap-2">
          <Inbox className="w-4 h-4 text-indigo-500" />
          Входящие (Inbox)
        </h2>
        <span className="text-[10px] font-bold text-zinc-500 uppercase tracking-wider">
          {inboxItems.length} записей
        </span>
      </div>

      <form onSubmit={handleSubmit} className="mb-4 relative">
        <input
          type="text"
          value={newContent}
          onChange={(e) => setNewContent(e.target.value)}
          placeholder="Быстрая запись..."
          className="w-full bg-stone-50 border border-stone-200 rounded-2xl px-4 py-2.5 text-xs text-zinc-900 focus:outline-none focus:border-zinc-600 transition-colors pr-10"
        />
        <button
          type="submit"
          disabled={!newContent.trim()}
          className="absolute right-2 top-1/2 -translate-y-1/2 p-1.5 bg-white text-black rounded-xl hover:bg-zinc-200 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
        >
          <Plus className="w-4 h-4" />
        </button>
      </form>

      <div className="space-y-2 max-h-[200px] overflow-y-auto pr-1 scrollbar-hide">
        <AnimatePresence mode="popLayout">
          {inboxItems.map((item) => (
            <motion.div
              key={item.id}
              layout
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="group bg-stone-50 p-3 rounded-2xl border border-stone-200 flex items-center justify-between gap-3"
            >
              <div className="flex-1 min-w-0">
                <p className="text-xs text-zinc-800 truncate">{item.content}</p>
                <p className="text-[9px] text-zinc-600 mt-0.5">
                  {format(new Date(item.createdAt), 'HH:mm', { locale: ru })}
                </p>
              </div>
              <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  onClick={() => handleConvertToTask(item)}
                  className="p-1.5 text-zinc-500 hover:text-emerald-500 transition-colors"
                  title="Превратить в задачу"
                >
                  <CheckCircle2 className="w-4 h-4" />
                </button>
                <button
                  onClick={() => deleteInboxItem(item.id)}
                  className="p-1.5 text-zinc-500 hover:text-rose-500 transition-colors"
                  title="Удалить"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
        {inboxItems.length === 0 && (
          <div className="text-center py-6 text-zinc-600">
            <Inbox className="w-8 h-8 mx-auto mb-2 opacity-20" />
            <p className="text-[10px] italic">Входящие пусты. Запишите что-нибудь!</p>
          </div>
        )}
      </div>
    </div>
  );
}
