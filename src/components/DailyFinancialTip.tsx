import React, { useEffect, useState } from 'react';
import { Lightbulb, RefreshCw } from 'lucide-react';
import { useStore } from '../store/useStore';
import { GoogleGenAI } from '@google/genai';

export function DailyFinancialTip() {
  const { dailyTip, setDailyTip } = useStore();
  const [isLoading, setIsLoading] = useState(false);

  const generateTip = async (force = false) => {
    const today = new Date().toISOString().split('T')[0];
    if (!force && dailyTip?.date === today) return;

    setIsLoading(true);
    try {
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        console.error('Gemini API key is missing');
        setIsLoading(false);
        return;
      }
      
      const ai = new GoogleGenAI({ apiKey });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: 'Сгенерируй один короткий, интересный и практичный совет по финансовой грамотности, экономике, инвестициям или психологии денег. Максимум 2-3 предложения. Без приветствий и лишних слов. Только сам совет.',
      });
      
      if (response.text) {
        setDailyTip({ date: today, text: response.text });
      }
    } catch (error) {
      console.error('Failed to generate tip:', error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    generateTip();
  }, []);

  if (!dailyTip && !isLoading) return null;

  return (
    <div className="bg-gradient-to-r from-indigo-500/10 to-purple-500/10 border border-indigo-500/20 rounded-3xl p-5 mb-6 flex gap-4 items-start relative overflow-hidden">
      <div className="p-2.5 bg-indigo-500/20 rounded-2xl shrink-0">
        <Lightbulb className="w-6 h-6 text-indigo-400" />
      </div>
      <div className="flex-1">
        <h3 className="text-sm font-bold text-indigo-300 mb-1 flex items-center gap-2 uppercase tracking-wider">
          Финансовая мудрость дня
        </h3>
        <p className="text-sm text-zinc-300 leading-relaxed font-medium">
          {isLoading ? (
            <span className="animate-pulse">Генерирую совет...</span>
          ) : (
            dailyTip?.text
          )}
        </p>
      </div>
      <button 
        onClick={() => generateTip(true)}
        disabled={isLoading}
        className="p-2 text-zinc-500 hover:text-indigo-400 transition-colors disabled:opacity-50 shrink-0"
        title="Получить другой совет"
      >
        <RefreshCw className={`w-5 h-5 ${isLoading ? 'animate-spin' : ''}`} />
      </button>
    </div>
  );
}
