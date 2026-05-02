/**
 * Импорт CSV-выписок белорусских банков в раздел «Финансы».
 *
 * Этапы:
 *   1. Выбираем счёт назначения и (опционально) банк-парсер.
 *   2. Парсим текст файла → массив `ParsedTxn` (autoCategorize применяется
 *      сразу).
 *   3. Показываем превью с возможностью отметить/снять галочку и поправить
 *      категорию.
 *   4. По клику «Импортировать» вызываем `addTransaction` для отмеченных
 *      строк.
 */
import React, { useMemo, useRef, useState } from 'react';
import { Upload, X, Loader2, Check, AlertCircle } from 'lucide-react';
import { useStore } from '../store/useStore';
import {
  autoCategorize,
  parseAlfaBYCsv,
  parseBelarusbankCsv,
  parseGenericCsv,
  parseMtbankCsv,
  parsePriorbankCsv,
  type ParsedTxn,
  type ParseResult,
} from '../lib/belarus/csvParsers';
import { detectBankFromCsv } from '../lib/belarus/banks';
import { formatCurrency, formatDateBY } from '../lib/format';

interface Props {
  open: boolean;
  onClose: () => void;
}

const PARSERS: { id: string; label: string; run: (text: string) => ParseResult }[] = [
  { id: 'auto', label: 'Авто (попробовать угадать)', run: parseGenericCsv },
  { id: 'belarusbank', label: 'Беларусбанк (M-Banking)', run: parseBelarusbankCsv },
  { id: 'priorbank', label: 'Приорбанк', run: parsePriorbankCsv },
  { id: 'alfa-by', label: 'Альфа-Банк РБ', run: parseAlfaBYCsv },
  { id: 'mtbank', label: 'МТБанк (Халва)', run: parseMtbankCsv },
  { id: 'generic', label: 'Универсальный CSV', run: parseGenericCsv },
];

export function BankCsvImportModal({ open, onClose }: Props) {
  const { accounts = [], addTransaction, baseCurrency = 'BYN' } = useStore();
  const fileRef = useRef<HTMLInputElement>(null);
  const [selectedAccount, setSelectedAccount] = useState<string>(accounts[0]?.id ?? '');
  const [parserId, setParserId] = useState<string>('auto');
  const [parseResult, setParseResult] = useState<ParseResult | null>(null);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [busy, setBusy] = useState(false);
  const [imported, setImported] = useState<number | null>(null);

  const account = accounts.find((a) => a.id === selectedAccount);
  const accountCurrency = account?.currency ?? baseCurrency;

  const handleFile = async (file: File) => {
    setBusy(true);
    setImported(null);
    try {
      const text = await file.text();
      const detected = parserId === 'auto' ? detectBankFromCsv(text) : null;
      const detectedId = detected?.id;
      const parser =
        PARSERS.find((p) => p.id === parserId) ??
        (detectedId ? PARSERS.find((p) => p.id === detectedId) : null) ??
        PARSERS[0];
      const result = parser.run(text);
      result.rows = autoCategorize(result.rows);
      setParseResult(result);
      setSelected(new Set(result.rows.map((_, i) => i)));
    } catch (e) {
      setParseResult({ bank: '?', rows: [], errors: [String(e)] });
    } finally {
      setBusy(false);
    }
  };

  const onImport = () => {
    if (!parseResult || !selectedAccount) return;
    setBusy(true);
    let count = 0;
    for (let i = 0; i < parseResult.rows.length; i++) {
      if (!selected.has(i)) continue;
      const row = parseResult.rows[i];
      addTransaction({
        type: row.type,
        amount: row.amount,
        category: row.category ?? (row.type === 'income' ? 'Доход' : 'Прочее'),
        date: row.date,
        accountId: selectedAccount,
        notes: row.description,
      });
      count++;
    }
    setImported(count);
    setBusy(false);
  };

  const totals = useMemo(() => {
    if (!parseResult) return { income: 0, expense: 0 };
    let income = 0;
    let expense = 0;
    for (let i = 0; i < parseResult.rows.length; i++) {
      if (!selected.has(i)) continue;
      const r = parseResult.rows[i];
      if (r.type === 'income') income += r.amount;
      else expense += r.amount;
    }
    return { income, expense };
  }, [parseResult, selected]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/30 flex items-center justify-center p-3">
      <div className="bg-white rounded-3xl w-full max-w-3xl max-h-[90vh] overflow-hidden flex flex-col">
        <header className="flex items-center justify-between p-4 border-b border-stone-200">
          <div>
            <h2 className="text-base font-bold text-zinc-900">Импорт банковской выписки</h2>
            <p className="text-xs text-zinc-500">
              Загрузите CSV/TXT из мобильного банка. Парсер угадает банк и заполнит категории.
            </p>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-stone-100 hover:bg-stone-200 flex items-center justify-center"
            aria-label="Закрыть"
          >
            <X className="w-4 h-4" />
          </button>
        </header>

        <div className="p-4 border-b border-stone-200 grid sm:grid-cols-2 gap-3">
          <label className="flex flex-col gap-1 text-xs">
            <span className="font-medium text-zinc-700">Счёт назначения</span>
            <select
              value={selectedAccount}
              onChange={(e) => setSelectedAccount(e.target.value)}
              className="border border-stone-200 rounded-lg px-3 py-2 bg-white text-sm"
            >
              {accounts.map((a) => (
                <option key={a.id} value={a.id}>
                  {a.name} ({a.currency})
                </option>
              ))}
            </select>
          </label>
          <label className="flex flex-col gap-1 text-xs">
            <span className="font-medium text-zinc-700">Парсер</span>
            <select
              value={parserId}
              onChange={(e) => setParserId(e.target.value)}
              className="border border-stone-200 rounded-lg px-3 py-2 bg-white text-sm"
            >
              {PARSERS.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.label}
                </option>
              ))}
            </select>
          </label>
          <input
            ref={fileRef}
            type="file"
            accept=".csv,.txt"
            className="hidden"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) handleFile(f);
            }}
          />
          <button
            onClick={() => fileRef.current?.click()}
            disabled={!selectedAccount || busy}
            className="sm:col-span-2 inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-emerald-500 text-white text-sm font-semibold disabled:opacity-60"
          >
            {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Upload className="w-4 h-4" />}
            Выбрать файл выписки
          </button>
        </div>

        <div className="flex-1 overflow-auto p-4">
          {!parseResult && (
            <div className="text-center text-xs text-zinc-500 py-12">
              Поддерживаются CSV выписки 8+ белорусских банков. Файл не загружается на сервер —
              всё парсится в браузере.
            </div>
          )}

          {parseResult && (
            <>
              <div className="flex flex-wrap items-center gap-3 text-xs text-zinc-600 mb-3">
                <span className="px-2 py-1 rounded-md bg-stone-100">
                  Банк: <strong>{parseResult.bank}</strong>
                </span>
                <span>Найдено: {parseResult.rows.length}</span>
                <span className="text-emerald-600">
                  + {formatCurrency(totals.income, accountCurrency)}
                </span>
                <span className="text-rose-600">
                  − {formatCurrency(totals.expense, accountCurrency)}
                </span>
              </div>

              {parseResult.errors.length > 0 && (
                <div className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-2 mb-3 flex items-start gap-2">
                  <AlertCircle className="w-3.5 h-3.5 mt-0.5 shrink-0" />
                  <div>
                    <strong>Ошибки парсинга:</strong>
                    <ul className="list-disc pl-5 mt-1 space-y-0.5">
                      {parseResult.errors.slice(0, 5).map((e, i) => (
                        <li key={i}>{e}</li>
                      ))}
                      {parseResult.errors.length > 5 && (
                        <li>… и ещё {parseResult.errors.length - 5}</li>
                      )}
                    </ul>
                  </div>
                </div>
              )}

              <Preview
                rows={parseResult.rows}
                selected={selected}
                setSelected={setSelected}
                accountCurrency={accountCurrency}
              />
            </>
          )}
        </div>

        {parseResult && (
          <footer className="p-4 border-t border-stone-200 flex items-center justify-between gap-2">
            <button
              onClick={() => {
                if (selected.size === parseResult.rows.length) setSelected(new Set());
                else setSelected(new Set(parseResult.rows.map((_, i) => i)));
              }}
              className="text-xs text-zinc-500 hover:text-zinc-800"
            >
              {selected.size === parseResult.rows.length ? 'Снять выбор' : 'Выбрать все'}
            </button>
            {imported !== null ? (
              <div className="flex items-center gap-2 text-emerald-600 text-sm">
                <Check className="w-4 h-4" /> Импортировано: {imported}
              </div>
            ) : (
              <button
                disabled={selected.size === 0 || busy}
                onClick={onImport}
                className="px-4 py-2 rounded-xl bg-zinc-900 text-white text-sm font-semibold disabled:opacity-60"
              >
                Импортировать ({selected.size})
              </button>
            )}
          </footer>
        )}
      </div>
    </div>
  );
}

function Preview({
  rows,
  selected,
  setSelected,
  accountCurrency,
}: {
  rows: ParsedTxn[];
  selected: Set<number>;
  setSelected: (s: Set<number>) => void;
  accountCurrency: string;
}) {
  const toggle = (i: number) => {
    const next = new Set(selected);
    if (next.has(i)) next.delete(i);
    else next.add(i);
    setSelected(next);
  };
  return (
    <div className="border border-stone-200 rounded-2xl overflow-hidden">
      <div className="grid grid-cols-[28px_72px_72px_1fr_120px] text-[11px] text-zinc-500 bg-stone-50 px-3 py-2 font-semibold uppercase tracking-wider">
        <div></div>
        <div>Дата</div>
        <div>Тип</div>
        <div>Описание / Категория</div>
        <div className="text-right">Сумма</div>
      </div>
      <ul className="max-h-80 overflow-auto">
        {rows.map((r, i) => (
          <li
            key={i}
            className="grid grid-cols-[28px_72px_72px_1fr_120px] text-xs px-3 py-2 border-t border-stone-100"
          >
            <input
              type="checkbox"
              checked={selected.has(i)}
              onChange={() => toggle(i)}
              className="self-center"
            />
            <span className="self-center text-zinc-700">{formatDateBY(r.date)}</span>
            <span className="self-center">
              <span
                className={
                  'inline-block px-1.5 py-0.5 rounded text-[10px] font-medium ' +
                  (r.type === 'income'
                    ? 'bg-emerald-100 text-emerald-700'
                    : 'bg-rose-100 text-rose-700')
                }
              >
                {r.type === 'income' ? 'дох' : 'расх'}
              </span>
            </span>
            <div className="self-center min-w-0">
              <div className="truncate text-zinc-800" title={r.description}>
                {r.description || '—'}
              </div>
              {r.category && (
                <div className="text-[10px] text-zinc-500">→ {r.category}</div>
              )}
            </div>
            <span
              className={
                'self-center text-right font-medium ' +
                (r.type === 'income' ? 'text-emerald-600' : 'text-rose-600')
              }
            >
              {r.type === 'income' ? '+' : '−'} {formatCurrency(r.amount, accountCurrency)}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
