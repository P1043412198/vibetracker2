import React, { useState, useEffect, useRef } from 'react';
import { Bot, Send, Loader2, Home, Sparkles, Wrench, Droplets, Zap } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";
import OpenAI from 'openai';
import { cn } from '../lib/utils';
import Markdown from 'react-markdown';
import { useStore } from '../store/useStore';

export function HouseholdAssistant() {
  const { customGeminiKey, customOpenAIKey, preferredAiProvider } = useStore();
  const [messages, setMessages] = useState<{role: 'user' | 'model', text: string}[]>([
    {
      role: 'model',
      text: 'Привет! Я твой Бытовой Ассистент. Я эксперт по ведению домашнего хозяйства, уборке, мелкому ремонту, хранению продуктов и экономии на коммуналке. Спрашивай меня о чем угодно: как отмыть сложное пятно, как правильно хранить зелень, чтобы она не вяла, или как починить подтекающий кран!'
    }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage = input.trim();
    setMessages(prev => [...prev, { role: 'user', text: userMessage }]);
    setInput('');
    setIsLoading(true);

    try {
      const systemInstruction = `
Ты — ИИ-ассистент по быту и домашнему хозяйству (Бытовой Ассистент). 
Твоя задача — давать максимально полезные, практичные и безопасные советы по:
1. Хранению продуктов: как правильно замораживать, где хранить овощи/фрукты, сроки годности, товарное соседство в холодильнике.
2. Уборке и чистоте: как отмыть любые пятна, народные и профессиональные средства, организация пространства, расхламление.
3. Мелкому бытовому ремонту: как починить кран, розетку (с предупреждением о безопасности), скрипящую дверь, собрать мебель.
4. Коммуналке и экономии: как экономить воду, электричество, тепло в квартире.
5. Уюту: как улучшить атмосферу дома, избавиться от запахов.

Твой характер: ты заботливый, очень практичный, знаешь кучу "бабушкиных" лайфхаков, но при этом разбираешься в современных технологиях и химии. Ты всегда предупреждаешь о технике безопасности, если дело касается электричества, сантехники или едкой химии.
Отвечай структурировано, по делу, используй списки. Формат ответа — Markdown.
`;

      let responseText = '';

      if (preferredAiProvider === 'openai' && customOpenAIKey) {
        const openai = new OpenAI({ apiKey: customOpenAIKey, dangerouslyAllowBrowser: true });
        
        const openAiMessages: any[] = [
          { role: 'system', content: systemInstruction },
          ...messages.slice(1).map(m => ({
            role: m.role === 'user' ? 'user' : 'assistant',
            content: m.text
          })),
          { role: 'user', content: userMessage }
        ];

        const completion = await openai.chat.completions.create({
          messages: openAiMessages,
          model: 'gpt-4o-mini',
          temperature: 0.7,
        });

        responseText = completion.choices[0]?.message?.content || 'Извините, я не смог сгенерировать ответ.';
      } else {
        const apiKey = customGeminiKey || process.env.GEMINI_API_KEY;
        if (!apiKey) throw new Error('API key is missing');
        
        const ai = new GoogleGenAI({ apiKey });
        const chat = ai.chats.create({
          model: "gemini-3-flash-preview",
          config: {
            systemInstruction,
            temperature: 0.7,
          }
        });

        // Send chat history
        for (const msg of messages.slice(1)) {
          await chat.sendMessage({ message: msg.text });
        }

        const response = await chat.sendMessage({ message: userMessage });
        responseText = response.text || 'Извините, я не смог сгенерировать ответ.';
      }
      
      setMessages(prev => [...prev, { 
        role: 'model', 
        text: responseText 
      }]);
    } catch (error) {
      console.error('AI Error:', error);
      setMessages(prev => [...prev, { 
        role: 'model', 
        text: 'Произошла ошибка при обращении к ИИ. Пожалуйста, проверьте правильность API ключа в настройках и попробуйте еще раз.' 
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const suggestions = [
    "Как правильно хранить зелень?",
    "Как отмыть духовку от жира?",
    "Как экономить электричество?",
    "Капает кран на кухне, что делать?"
  ];

  return (
    <div className="flex flex-col h-[calc(100vh-12rem)] bg-white/60 rounded-2xl border border-stone-200 overflow-hidden">
      {/* Header */}
      <div className="p-3 border-b border-stone-200 bg-white/80 flex items-center gap-3">
        <div className="w-8 h-8 rounded-xl bg-blue-500/20 flex items-center justify-center">
          <Home className="w-4 h-4 text-blue-400" />
        </div>
        <div>
          <h2 className="text-sm font-bold text-zinc-900">Бытовой Ассистент</h2>
          <p className="text-[10px] text-zinc-500">Эксперт по дому, чистоте и ремонту</p>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 hide-scrollbar">
        {messages.map((msg, idx) => (
          <div
            key={idx}
            className={cn(
              "flex gap-3 max-w-[85%]",
              msg.role === 'user' ? "ml-auto flex-row-reverse" : ""
            )}
          >
            <div className={cn(
              "w-6 h-6 rounded-full flex items-center justify-center flex-shrink-0 mt-1",
              msg.role === 'user' ? "bg-stone-100" : "bg-blue-500/20"
            )}>
              {msg.role === 'user' ? (
                <div className="w-1.5 h-1.5 rounded-full bg-zinc-400" />
              ) : (
                <Home className="w-3 h-3 text-blue-400" />
              )}
            </div>
            <div className={cn(
              "p-2.5 rounded-2xl text-xs",
              msg.role === 'user' 
                ? "bg-blue-600 text-zinc-900 rounded-tr-sm" 
                : "bg-stone-100 text-zinc-800 rounded-tl-sm prose prose-invert prose-xs max-w-none"
            )}>
              {msg.role === 'user' ? (
                msg.text
              ) : (
                <Markdown>{msg.text}</Markdown>
              )}
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="flex gap-3 max-w-[80%]">
            <div className="w-6 h-6 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0 mt-1">
              <Home className="w-3 h-3 text-blue-400" />
            </div>
            <div className="p-3 rounded-2xl bg-stone-100 rounded-tl-sm flex items-center gap-2">
              <Loader2 className="w-3 h-3 animate-spin text-blue-400" />
              <span className="text-xs text-zinc-500">Ассистент печатает...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Suggestions */}
      {messages.length === 1 && (
        <div className="p-3 flex flex-wrap gap-1.5 border-t border-stone-200/70 bg-white/30">
          {suggestions.map((suggestion, idx) => (
            <button
              key={idx}
              onClick={() => {
                setInput(suggestion);
                setTimeout(() => handleSend(), 100);
              }}
              className="px-2.5 py-1 bg-stone-100 hover:bg-stone-200 text-zinc-700 rounded-lg text-[10px] transition-colors flex items-center gap-1"
            >
              <Sparkles className="w-2.5 h-2.5 text-blue-400" />
              {suggestion}
            </button>
          ))}
        </div>
      )}

      {/* Input */}
      <div className="p-3 border-t border-stone-200 bg-white/80">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Спроси, как отмыть плиту или починить кран..."
            className="flex-1 bg-stone-50 border border-stone-200 rounded-xl px-3 py-1.5 text-xs text-zinc-900 focus:outline-none focus:border-blue-500 transition-colors"
          />
          <button
            onClick={handleSend}
            disabled={!input.trim() || isLoading}
            className="p-1.5 bg-blue-600 text-zinc-900 rounded-xl hover:bg-blue-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center w-8 h-8"
          >
            <Send className="w-3 h-3" />
          </button>
        </div>
      </div>
    </div>
  );
}
