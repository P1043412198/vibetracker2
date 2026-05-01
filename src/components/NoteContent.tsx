import React, { useState, useEffect } from 'react';
import { Edit2, Check, X } from 'lucide-react';
import MDEditor from '@uiw/react-md-editor';

interface NoteContentProps {
  content: string;
  onUpdateContent: (newContent: string) => void;
  isEditing?: boolean;
}

export const NoteContent: React.FC<NoteContentProps> = ({ content, onUpdateContent, isEditing = false }) => {
  const [localContent, setLocalContent] = useState(content);
  const [editMode, setEditMode] = useState(isEditing);

  useEffect(() => {
    if (!editMode) {
      setLocalContent(content);
    }
  }, [content, editMode]);

  const handleSave = () => {
    onUpdateContent(localContent || '');
    setEditMode(false);
  };

  const toggleCheckbox = (lineIndex: number) => {
    const lines = content.split('\n');
    if (lines[lineIndex]) {
      if (lines[lineIndex].includes('- [ ]')) {
        lines[lineIndex] = lines[lineIndex].replace('- [ ]', '- [x]');
      } else if (lines[lineIndex].includes('- [x]')) {
        lines[lineIndex] = lines[lineIndex].replace('- [x]', '- [ ]');
      } else if (lines[lineIndex].includes('- [X]')) {
        lines[lineIndex] = lines[lineIndex].replace('- [X]', '- [ ]');
      }
      onUpdateContent(lines.join('\n'));
    }
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64 = reader.result as string;
        const imageMarkdown = `\n![Uploaded Image](${base64})\n`;
        setLocalContent(prev => prev + imageMarkdown);
      };
      reader.readAsDataURL(file);
    }
  };

  if (editMode) {
    return (
      <div className="space-y-3" data-color-mode="dark">
        <div className="border border-zinc-800 rounded-xl overflow-hidden">
          <MDEditor
            value={localContent}
            onChange={(val) => setLocalContent(val || '')}
            preview="edit"
            height={300}
            className="!bg-zinc-950 !border-none"
            textareaProps={{
              placeholder: 'Введите текст заметки... Поддерживается Markdown (чекбоксы, фото, видео, ссылки)',
            }}
          />
        </div>
        <div className="flex justify-between items-center">
          <label className="flex items-center gap-2 px-3 py-1.5 rounded-xl text-xs font-medium transition-colors border bg-zinc-950 text-zinc-400 border-zinc-800 hover:border-zinc-700 hover:text-white cursor-pointer">
            <input 
              type="file" 
              accept="image/*" 
              className="hidden" 
              onChange={handlePhotoUpload} 
            />
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/></svg>
            Загрузить фото
          </label>
          <div className="flex justify-end gap-2">
            <button
              onClick={() => {
                setLocalContent(content);
                setEditMode(false);
              }}
              className="flex items-center gap-1 px-3 py-1.5 text-xs text-zinc-400 hover:bg-zinc-800 rounded-xl font-medium transition-colors"
            >
              <X className="w-3.5 h-3.5" /> Отмена
            </button>
            <button
              onClick={handleSave}
              className="flex items-center gap-1 px-3 py-1.5 text-xs bg-white text-black rounded-xl hover:bg-zinc-200 font-medium transition-colors"
            >
              <Check className="w-3.5 h-3.5" /> Сохранить
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="text-sm leading-relaxed text-zinc-200 group relative" data-color-mode="dark">
      <button 
        onClick={() => setEditMode(true)}
        className="absolute -top-2 -right-2 p-1.5 bg-zinc-800 text-zinc-400 hover:text-white rounded-lg opacity-0 group-hover:opacity-100 transition-opacity z-10"
        title="Редактировать заметку"
      >
        <Edit2 className="w-3.5 h-3.5" />
      </button>
      
      <div className="prose prose-invert prose-sm max-w-none prose-p:leading-relaxed prose-pre:bg-zinc-900 prose-pre:border prose-pre:border-zinc-800">
        <MDEditor.Markdown 
          source={content || '*Пустая заметка*'} 
          style={{ backgroundColor: 'transparent' }}
          components={{
            input: ({ node, checked, ...props }) => {
              if (props.type === 'checkbox') {
                const lineIndex = node?.position?.start?.line ? node.position.start.line - 1 : -1;
                return (
                  <input
                    type="checkbox"
                    checked={checked}
                    onChange={() => {
                      if (lineIndex >= 0) {
                        toggleCheckbox(lineIndex);
                      }
                    }}
                    className="w-4 h-4 rounded border-zinc-700 text-emerald-500 focus:ring-emerald-500 focus:ring-offset-zinc-950 bg-zinc-900 cursor-pointer mt-1"
                  />
                );
              }
              return <input {...props} />;
            },
            a: ({ node, href, children, ...props }) => {
              // Auto-embed YouTube links if they are on their own line or just plain links
              if (href && (href.includes('youtube.com/watch') || href.includes('youtu.be/'))) {
                const videoId = href.includes('youtube.com/watch') 
                  ? new URL(href).searchParams.get('v')
                  : href.split('youtu.be/')[1]?.split('?')[0];
                  
                if (videoId) {
                  return (
                    <div className="my-4 rounded-xl overflow-hidden border border-zinc-800 bg-zinc-900 aspect-video">
                      <iframe
                        width="100%"
                        height="100%"
                        src={`https://www.youtube.com/embed/${videoId}`}
                        title="YouTube video player"
                        frameBorder="0"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        allowFullScreen
                      ></iframe>
                    </div>
                  );
                }
              }
              return <a href={href} target="_blank" rel="noopener noreferrer" className="text-emerald-400 hover:text-emerald-300 underline" {...props}>{children}</a>;
            },
            img: ({ node, src, alt, ...props }) => (
              <img src={src} alt={alt} className="rounded-xl border border-zinc-800 max-h-96 object-contain bg-zinc-900" {...props} />
            )
          }}
        />
      </div>
    </div>
  );
};
