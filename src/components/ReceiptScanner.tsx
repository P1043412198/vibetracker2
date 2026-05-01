import React, { useEffect, useRef, useState } from 'react';
import { Html5QrcodeScanner, Html5QrcodeScanType } from 'html5-qrcode';
import { Camera, X, CheckCircle2, AlertCircle, Upload, FileText } from 'lucide-react';
import { useStore } from '../store/useStore';
import { v4 as uuidv4 } from 'uuid';
import Tesseract from 'tesseract.js';

interface ReceiptScannerProps {
  onClose: () => void;
}

export function ReceiptScanner({ onClose }: ReceiptScannerProps) {
  const [scanMode, setScanMode] = useState<'qr' | 'ocr'>('qr');
  const [scanResult, setScanResult] = useState<string | null>(null);
  const [extractedAmount, setExtractedAmount] = useState<number | null>(null);
  const [extractedNotes, setExtractedNotes] = useState<string>('');
  const [error, setError] = useState<string | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { addTransaction, accounts, baseCurrency } = useStore();

  useEffect(() => {
    if (scanMode !== 'qr') {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(console.error);
        scannerRef.current = null;
      }
      return;
    }

    const scanner = new Html5QrcodeScanner(
      'qr-reader',
      { 
        fps: 10, 
        qrbox: { width: 250, height: 250 },
        supportedScanTypes: [Html5QrcodeScanType.SCAN_TYPE_CAMERA]
      },
      false
    );
    
    scannerRef.current = scanner;

    scanner.render(
      (decodedText) => {
        setScanResult(decodedText);
        scanner.clear();
      },
      (errorMessage) => {
        // Ignore normal scanning errors
      }
    );

    return () => {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(console.error);
      }
    };
  }, [scanMode]);

  const parseReceiptWithOCR = async (base64Image: string) => {
    setIsProcessing(true);
    setError(null);
    try {
      const result = await Tesseract.recognize(
        base64Image,
        'rus+eng',
        { logger: m => console.log(m) }
      );
      const text = result.data.text;
      
      // Simple heuristic to find amount
      const lines = text.split('\n');
      let foundAmount = 0;
      
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].toLowerCase();
        if (line.includes('итог') || line.includes('сумма') || line.includes('к оплате') || line.includes('total')) {
          const match = line.match(/\d+[.,]\d{2}/);
          if (match) {
            foundAmount = parseFloat(match[0].replace(',', '.'));
            break;
          } else if (i + 1 < lines.length) {
            const nextMatch = lines[i+1].match(/\d+[.,]\d{2}/);
            if (nextMatch) {
              foundAmount = parseFloat(nextMatch[0].replace(',', '.'));
              break;
            }
          }
        }
      }
      
      if (foundAmount > 0) {
        setExtractedAmount(foundAmount);
      } else {
        throw new Error('Не удалось найти сумму в чеке (OCR)');
      }
      
      const cleanText = lines.filter(l => l.trim().length > 3).slice(0, 5).join(', ');
      setExtractedNotes(cleanText.substring(0, 100) + (cleanText.length > 100 ? '...' : ''));
      setScanResult('ocr_success');
      
    } catch (err: any) {
      console.error('Error parsing receipt with OCR:', err);
      setError(err.message || 'Ошибка распознавания чека');
    } finally {
      setIsProcessing(false);
    }
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const result = event.target?.result;
      if (typeof result === 'string') {
        parseReceiptWithOCR(result);
      }
    };
    reader.readAsDataURL(file);
  };

  const processReceipt = () => {
    if (!scanResult) return;
    
    setIsProcessing(true);
    setError(null);

    try {
      let amount = 0;
      let date = new Date();
      let description = 'Покупка по чеку';

      if (scanMode === 'qr') {
        // Parse standard receipt QR format (e.g., t=20210810T1200&s=123.45&fn=...&i=...&fp=...&n=1)
        const params = new URLSearchParams(scanResult);
        const amountStr = params.get('s');
        const dateStr = params.get('t');

        if (!amountStr) {
          throw new Error('Не удалось найти сумму в чеке');
        }

        amount = parseFloat(amountStr);
        
        if (dateStr) {
          // Format: YYYYMMDDTHHMM or YYYYMMDDTHHMMSS
          const year = parseInt(dateStr.substring(0, 4));
          const month = parseInt(dateStr.substring(4, 6)) - 1;
          const day = parseInt(dateStr.substring(6, 8));
          const hour = parseInt(dateStr.substring(9, 11));
          const minute = parseInt(dateStr.substring(11, 13));
          date = new Date(year, month, day, hour, minute);
        }
      } else {
        if (!extractedAmount) {
          throw new Error('Сумма не распознана');
        }
        amount = extractedAmount;
        description = extractedNotes || 'Покупка по чеку (OCR)';
      }

      // Find default account (first one)
      const defaultAccount = accounts[0];
      if (!defaultAccount) {
        throw new Error('Сначала создайте счет для добавления транзакции');
      }

      addTransaction({
        accountId: defaultAccount.id,
        type: 'expense',
        amount: amount,
        category: 'Покупки',
        date: date.toISOString().slice(0, 10),
        notes: description,
      });

      setTimeout(() => {
        onClose();
      }, 1500);

    } catch (err: any) {
      setError(err.message || 'Ошибка обработки чека');
      setIsProcessing(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md overflow-hidden flex flex-col">
        <div className="p-4 border-b border-zinc-800 flex justify-between items-center">
          <h3 className="text-lg font-bold text-white flex items-center gap-2">
            <Camera className="w-5 h-5 text-emerald-500" />
            Сканер чеков
          </h3>
          <button onClick={onClose} className="p-2 text-zinc-400 hover:text-white rounded-lg hover:bg-zinc-800">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex border-b border-zinc-800">
          <button
            onClick={() => { setScanMode('qr'); setScanResult(null); setError(null); }}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${scanMode === 'qr' ? 'text-white border-b-2 border-emerald-500' : 'text-zinc-400 hover:text-white'}`}
          >
            QR-код
          </button>
          <button
            onClick={() => { setScanMode('ocr'); setScanResult(null); setError(null); }}
            className={`flex-1 py-3 text-sm font-medium transition-colors ${scanMode === 'ocr' ? 'text-white border-b-2 border-emerald-500' : 'text-zinc-400 hover:text-white'}`}
          >
            Фото (OCR)
          </button>
        </div>

        <div className="p-4 flex-1 flex flex-col">
          {!scanResult ? (
            <div className="flex-1 flex flex-col">
              {scanMode === 'qr' ? (
                <>
                  <div id="qr-reader" className="w-full bg-black rounded-lg overflow-hidden border border-zinc-800" />
                  <p className="text-sm text-zinc-400 text-center mt-4">
                    Наведите камеру на QR-код на чеке
                  </p>
                </>
              ) : (
                <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
                  <input
                    type="file"
                    accept="image/*"
                    capture="environment"
                    className="hidden"
                    ref={fileInputRef}
                    onChange={handlePhotoUpload}
                  />
                  {isProcessing ? (
                    <div className="flex flex-col items-center">
                      <div className="w-16 h-16 border-4 border-emerald-500/20 border-t-emerald-500 rounded-full animate-spin mb-4" />
                      <p className="text-zinc-400">Распознавание текста...</p>
                    </div>
                  ) : (
                    <>
                      <div className="w-16 h-16 bg-zinc-800 rounded-full flex items-center justify-center mb-4">
                        <FileText className="w-8 h-8 text-zinc-400" />
                      </div>
                      <h4 className="text-lg font-bold text-white mb-2">Распознавание по фото</h4>
                      <p className="text-zinc-400 mb-6 text-sm">
                        Сфотографируйте чек, и мы попытаемся найти на нем итоговую сумму.
                      </p>
                      <button
                        onClick={() => fileInputRef.current?.click()}
                        className="flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white rounded-xl font-medium hover:bg-emerald-500 transition-colors"
                      >
                        <Upload className="w-5 h-5" />
                        Загрузить фото
                      </button>
                    </>
                  )}
                </div>
              )}
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center text-center py-8">
              {error ? (
                <>
                  <div className="w-16 h-16 bg-red-500/20 rounded-full flex items-center justify-center mb-4">
                    <AlertCircle className="w-8 h-8 text-red-500" />
                  </div>
                  <h4 className="text-lg font-bold text-white mb-2">Ошибка</h4>
                  <p className="text-zinc-400 mb-6">{error}</p>
                  <button 
                    onClick={() => {
                      setScanResult(null);
                      setError(null);
                      // Re-render scanner if in QR mode
                      if (scanMode === 'qr') {
                        setTimeout(() => {
                          if (scannerRef.current) {
                            scannerRef.current.render(
                              (decodedText) => {
                                setScanResult(decodedText);
                                scannerRef.current?.clear();
                              },
                              () => {}
                            );
                          }
                        }, 100);
                      }
                    }}
                    className="px-6 py-2 bg-zinc-800 text-white rounded-xl font-medium hover:bg-zinc-700 transition-colors"
                  >
                    Попробовать снова
                  </button>
                </>
              ) : isProcessing ? (
                <>
                  <div className="w-16 h-16 bg-emerald-500/20 rounded-full flex items-center justify-center mb-4">
                    <CheckCircle2 className="w-8 h-8 text-emerald-500" />
                  </div>
                  <h4 className="text-lg font-bold text-white mb-2">Чек обработан!</h4>
                  <p className="text-zinc-400">Транзакция успешно добавлена.</p>
                </>
              ) : (
                <>
                  <div className="w-16 h-16 bg-emerald-500/20 rounded-full flex items-center justify-center mb-4">
                    <CheckCircle2 className="w-8 h-8 text-emerald-500" />
                  </div>
                  <h4 className="text-lg font-bold text-white mb-2">
                    {scanMode === 'qr' ? 'QR-код распознан' : 'Сумма распознана'}
                  </h4>
                  <div className="bg-zinc-950 p-4 rounded-lg border border-zinc-800 mb-6 w-full text-left break-all">
                    {scanMode === 'qr' ? (
                      <p className="text-xs text-zinc-500 font-mono">{scanResult}</p>
                    ) : (
                      <div className="space-y-2">
                        <div className="flex justify-between items-center">
                          <span className="text-zinc-400 text-sm">Сумма:</span>
                          <span className="text-white font-bold text-lg">{extractedAmount} {baseCurrency}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-zinc-400 text-sm">Детали:</span>
                          <span className="text-zinc-300 text-xs text-right max-w-[60%] truncate">{extractedNotes}</span>
                        </div>
                      </div>
                    )}
                  </div>
                  <div className="flex gap-3 w-full">
                    <button 
                      onClick={() => setScanResult(null)}
                      className="flex-1 px-4 py-3 bg-zinc-800 text-white rounded-xl font-medium hover:bg-zinc-700 transition-colors"
                    >
                      Отмена
                    </button>
                    <button 
                      onClick={processReceipt}
                      className="flex-1 px-4 py-3 bg-emerald-600 text-white rounded-xl font-medium hover:bg-emerald-500 transition-colors"
                    >
                      Добавить
                    </button>
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
