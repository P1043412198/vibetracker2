import React, { useState, useEffect, useRef } from 'react';
import { Bot, Send, Loader2, Sparkles, TrendingUp, AlertTriangle, Lightbulb } from 'lucide-react';
import { useStore } from '../store/useStore';
import { GoogleGenAI } from "@google/genai";
import OpenAI from 'openai';
import { cn } from '../lib/utils';
import Markdown from 'react-markdown';

export function AIFinanceAssistant({ initialPrompt }: { initialPrompt?: string }) {
  const { 
    transactions = [], 
    loans = [], 
    accounts = [],
    savingsGoals = [],
    budgetLimits = [],
    regularPayments = [],
    customGeminiKey, 
    customOpenAIKey, 
    preferredAiProvider,
    rates = {},
    baseCurrency = 'BYN'
  } = useStore();
  const [shoppingItems, setShoppingItems] = useState<any[]>([]);
  
  const [messages, setMessages] = useState<{role: 'user' | 'model', text: string}[]>([
    {
      role: 'model',
      text: 'Привет! Я твой финансовый ассистент. Я проанализировал все твои счета, транзакции, долги и цели. Спрашивай, что тебя интересует, или попроси составить план на основе твоих текущих данных.'
    }
  ]);
  const [input, setInput] = useState(initialPrompt || '');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (initialPrompt) {
      setInput(initialPrompt);
      // Small delay to allow state to settle, then send
      setTimeout(() => {
        handleSend(initialPrompt);
      }, 100);
    }
  }, [initialPrompt]);

  useEffect(() => {
    const saved = localStorage.getItem('shopping_items');
    if (saved) {
      setShoppingItems(JSON.parse(saved));
    }
  }, []);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = async (overrideInput?: string) => {
    const textToSend = overrideInput || input;
    if (!textToSend.trim() || isLoading) return;

    const userMessage = textToSend.trim();
    setMessages(prev => [...prev, { role: 'user', text: userMessage }]);
    setInput('');
    setIsLoading(true);

    try {
      const cleanTransactions = transactions.slice(0, 100).map(({ photoUrl, ...rest }) => rest);
      const cleanShoppingItems = shoppingItems.map(({ photoUrl, ...rest }) => rest);
      
      // Calculate current balances for accounts to give AI real context
      const accountsWithBalances = accounts.map(acc => {
        const accountTransactions = transactions.filter(t => t.accountId === acc.id || t.toAccountId === acc.id);
        const balance = accountTransactions.reduce((s, t) => {
          if (t.type === 'income') return s + t.amount;
          if (t.type === 'expense') return s - t.amount;
          if (t.type === 'transfer') {
            if (t.accountId === acc.id) return s - t.amount;
            if (t.toAccountId === acc.id) return s + t.amount;
          }
          return s;
        }, acc.initialBalance);
        return { name: acc.name, type: acc.type, balance, currency: acc.currency || baseCurrency };
      });

      const systemInstruction = `
Ты — ИИ-ассистент по финансовой грамотности. Твоя задача — анализировать финансовые данные пользователя, составлять финансовый план и давать советы по тотальной экономии во всех сферах жизни.
Контекст: Пользователь живет в Беларуси. Основная валюта пользователя — ${baseCurrency}. Твои ответы должны быть на русском языке. Учитывай, что у пользователя могут быть счета, транзакции, долги и цели в разных валютах.
Твой характер: ты очень экономный, прагматичный, выступаешь за разумное потребление. Ты говоришь прямо, иногда с легкой иронией над транжирством, но всегда с заботой о кошельке пользователя.

Твои советы должны охватывать все аспекты быта:
1. Экономия на коммуналке: советы по сбережению света, воды, тепла.
2. Разумные покупки: не покупать пакеты на кассе (носить шопер), проверять чеки, использовать скидочные карты РБ, искать акции.
3. Траты: избегание импульсивных покупок, кофе навынос (лучше в термосе).
4. Кредиты: стратегии быстрого погашения (метод лавины или снежного кома).
5. Общая финансовая грамотность: формирование подушки безопасности, учет каждой копейки.

АКТУАЛЬНЫЕ ДАННЫЕ ПОЛЬЗОВАТЕЛЯ:
Текущие курсы валют: ${JSON.stringify(rates)}
Базовая валюта: ${baseCurrency}
Счета и остатки (с указанием валюты): ${JSON.stringify(accountsWithBalances)}
Транзакции (последние 100, с указанием валюты): ${JSON.stringify(cleanTransactions)}
Кредиты и долги (с указанием валюты): ${JSON.stringify(loans)}
Цели накопления (с указанием валюты): ${JSON.stringify(savingsGoals)}
Лимиты бюджета по категориям (с указанием валюты): ${JSON.stringify(budgetLimits)}
Регулярные платежи и подписки (с указанием валюты): ${JSON.stringify(regularPayments)}
Список покупок: ${JSON.stringify(cleanShoppingItems)}

Используй эти данные для ГЛУБОКОГО анализа. Если пользователь спрашивает "как дела?", проанализируй его баланс, долги и темп трат, учитывая курсы валют. Если просит план — рассчитай его на основе реальных цифр, приводя все к базовой валюте ${baseCurrency} для наглядности, но упоминая оригинальные валюты.
Отвечай в формате Markdown. Используй таблицы и списки для наглядности.
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

        responseText = completion.choices[0]?.message?.content || '';
      } else {
        const apiKey = customGeminiKey || process.env.GEMINI_API_KEY;
        if (!apiKey) throw new Error('API key is missing');
        
        const ai = new GoogleGenAI({ apiKey });
        
        const contents = messages.map(m => ({
          role: m.role,
          parts: [{ text: m.text }]
        }));
        
        contents.push({
          role: 'user',
          parts: [{ text: userMessage }]
        });

        const response = await ai.models.generateContent({
          model: "gemini-3-flash-preview",
          contents,
          config: {
            systemInstruction,
          }
        });
        
        responseText = response.text || '';
      }

      setMessages(prev => [...prev, { role: 'model', text: responseText }]);
    } catch (error) {
      console.error("AI Error:", error);
      setMessages(prev => [...prev, { role: 'model', text: 'Ой, что-то пошло не так. Мои счеты сломались, попробуй еще раз. Проверь API ключи в настройках.' }]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-220px)] bg-white rounded-2xl border border-stone-200 overflow-hidden">
      <div className="p-4 bg-stone-50 border-b border-stone-200 flex items-center gap-3">
        <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400">
          <Bot className="w-6 h-6" />
        </div>
        <div>
          <h3 className="font-bold text-zinc-900">Финансовый Ассистент</h3>
          <p className="text-xs text-zinc-500">На страже вашего кошелька</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg, idx) => (
          <div
            key={idx}
            className={cn(
              "flex w-full",
              msg.role === 'user' ? "justify-end" : "justify-start"
            )}
          >
            <div
              className={cn(
                "max-w-[85%] rounded-2xl p-3 text-sm",
                msg.role === 'user'
                  ? "bg-emerald-600 text-zinc-900 rounded-tr-sm"
                  : "bg-stone-100 text-zinc-800 rounded-tl-sm"
              )}
            >
              {msg.role === 'model' ? (
                <div className="markdown-body prose prose-invert prose-sm max-w-none">
                  <Markdown>{msg.text}</Markdown>
                </div>
              ) : (
                <p className="whitespace-pre-wrap">{msg.text}</p>
              )}
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-stone-100 text-zinc-800 rounded-2xl rounded-tl-sm p-3 flex items-center gap-2">
              <Loader2 className="w-4 h-4 animate-spin text-emerald-500" />
              <span className="text-sm">Считаю копеечки...</span>
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      <div className="p-3 bg-stone-50 border-t border-stone-200">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            handleSend();
          }}
          className="flex gap-2"
        >
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Спроси меня о финансах..."
            className="flex-1 bg-white border border-stone-200 rounded-xl px-4 py-2 text-sm text-zinc-900 focus:outline-none focus:border-emerald-500 transition-colors"
          />
          <button
            type="submit"
            disabled={!input.trim() || isLoading}
            className="p-2 bg-emerald-600 text-zinc-900 rounded-xl hover:bg-emerald-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center"
          >
            <Send className="w-5 h-5" />
          </button>
        </form>
      </div>
    </div>
  );
}
