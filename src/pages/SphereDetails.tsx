import React, { useState, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useStore } from '../store/useStore';
import { ArrowLeft, Plus, Trash2, Youtube, Calendar, ImagePlus, X, CheckCircle2, Circle, Pin } from 'lucide-react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { cn } from '../lib/utils';
import { NoteContent } from '../components/NoteContent';
import { NoteComments } from '../components/NoteComments';

import MDEditor from '@uiw/react-md-editor';

export function SphereDetails() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { spheres, tasks, toggleTaskCompletion, addSphereNote, deleteSphereNote, updateSphereNote } = useStore();
  
  const sphere = spheres.find(s => s.id === id);
  const sphereTasks = tasks ? tasks.filter(t => t.sphereId === id) : [];
  
  const [isAddingNote, setIsAddingNote] = useState(false);
  const [noteContent, setNoteContent] = useState('');
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [photoUrl, setPhotoUrl] = useState<string | undefined>();
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  if (!sphere) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-zinc-900">Сфера не найдена</h2>
        <button 
          onClick={() => navigate('/spheres')}
          className="mt-4 text-zinc-500 hover:text-zinc-900"
        >
          Вернуться к сферам
        </button>
      </div>
    );
  }

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      setPhotoUrl(event.target?.result as string);
    };
    reader.readAsDataURL(file);
  };

  const handleNotePhotoUpload = (noteId: string, e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      updateSphereNote(sphere.id, noteId, { photoUrl: event.target?.result as string });
    };
    reader.readAsDataURL(file);
  };

  const handleAddNote = (e: React.FormEvent) => {
    e.preventDefault();
    if (!noteContent.trim()) return;
    
    addSphereNote(sphere.id, noteContent, youtubeUrl.trim() || undefined, false, photoUrl);
    setNoteContent('');
    setYoutubeUrl('');
    setPhotoUrl(undefined);
    setIsAddingNote(false);
  };

  const extractYoutubeId = (url: string) => {
    const regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|&v=)([^#&?]*).*/;
    const match = url.match(regExp);
    return (match && match[2].length === 11) ? match[2] : null;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <button 
          onClick={() => navigate('/spheres')}
          className="p-2 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-full transition-colors"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-xl font-bold tracking-tight text-zinc-900">{sphere.title}</h1>
          {sphere.description && (
            <p className="text-xs text-zinc-500 mt-1">{sphere.description}</p>
          )}
        </div>
      </div>

      {sphere.deadline && (
        <div className="flex items-center gap-2 text-xs text-zinc-500 bg-white/60 w-fit px-3 py-1.5 rounded-lg border border-stone-200">
          <Calendar className="w-3.5 h-3.5" />
          <span>Дедлайн: {format(new Date(sphere.deadline), 'd MMM yyyy', { locale: ru })}</span>
        </div>
      )}

      {sphereTasks.length > 0 && (
        <div className="mt-6">
          <h2 className="text-base font-semibold text-zinc-900 mb-4">Задачи</h2>
          <div className="space-y-2">
            {sphereTasks.map(task => (
              <div 
                key={task.id}
                className={cn(
                  "flex items-center gap-3 p-3 rounded-xl border transition-all",
                  task.completed 
                    ? "bg-white/60 border-stone-200/70 opacity-60" 
                    : "bg-white border-stone-200"
                )}
              >
                <button
                  onClick={() => toggleTaskCompletion(task.id)}
                  className={cn(
                    "shrink-0 transition-colors",
                    task.completed ? "text-emerald-500" : "text-zinc-500 hover:text-zinc-500"
                  )}
                >
                  {task.completed ? <CheckCircle2 className="w-5 h-5" /> : <Circle className="w-5 h-5" />}
                </button>
                <div className="flex-1 min-w-0">
                  <p className={cn(
                    "text-sm font-medium truncate",
                    task.completed ? "text-zinc-500 line-through" : "text-zinc-800"
                  )}>
                    {task.title}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="flex items-center justify-between mt-6">
        <h2 className="text-base font-semibold text-zinc-900">Заметки</h2>
        <button
          onClick={() => setIsAddingNote(true)}
          className="flex items-center gap-2 bg-white text-black px-3 py-1.5 rounded-xl hover:bg-zinc-200 transition-colors text-xs font-medium"
        >
          <Plus className="w-4 h-4" />
          Добавить заметку
        </button>
      </div>

      {isAddingNote && (
        <div className="bg-white p-5 rounded-2xl shadow-sm border border-stone-200">
          <form onSubmit={handleAddNote} className="space-y-4">
            <div data-color-mode="dark">
              <label className="block text-xs font-medium text-zinc-700 mb-1">Текст заметки</label>
              <div className="border border-stone-200 rounded-xl overflow-hidden">
                <MDEditor
                  value={noteContent}
                  onChange={(val) => setNoteContent(val || '')}
                  preview="edit"
                  height={200}
                  className="!bg-stone-50 !border-none"
                  textareaProps={{
                    placeholder: 'Подробное описание... Поддерживается Markdown (чекбоксы, фото, видео, ссылки)',
                  }}
                />
              </div>
            </div>
            <div>
              <label className="block text-xs font-medium text-zinc-700 mb-1 flex items-center gap-2">
                <Youtube className="w-3.5 h-3.5 text-zinc-500" />
                Ссылка на YouTube (необязательно)
              </label>
              <input
                type="url"
                value={youtubeUrl}
                onChange={(e) => setYoutubeUrl(e.target.value)}
                className="w-full px-3 py-2 bg-stone-50 border border-stone-200 text-zinc-900 rounded-xl focus:ring-2 focus:ring-zinc-500 focus:border-zinc-500 text-sm"
                placeholder="https://youtube.com/watch?v=..."
              />
            </div>
            <div className="flex items-center gap-2 pt-1">
              <label className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-colors border bg-stone-50 text-zinc-500 border-stone-200 hover:border-stone-300 hover:text-zinc-900 cursor-pointer">
                <input 
                  type="file" 
                  accept="image/*" 
                  className="hidden" 
                  onChange={handlePhotoUpload} 
                />
                <ImagePlus className="w-4 h-4" />
                Добавить фото
              </label>
            </div>

            {photoUrl && (
              <div className="relative w-32 h-32 rounded-xl overflow-hidden border border-stone-200 group">
                <img src={photoUrl} alt="Note attachment" className="w-full h-full object-cover" />
                <button
                  type="button"
                  onClick={() => setPhotoUrl(undefined)}
                  className="absolute top-1 right-1 w-6 h-6 bg-zinc-900/30 backdrop-blur-md rounded-full flex items-center justify-center text-zinc-900 opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-500/80"
                >
                  <X className="w-3 h-3" />
                </button>
              </div>
            )}

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsAddingNote(false)}
                className="px-3 py-1.5 text-xs text-zinc-500 hover:bg-stone-100 rounded-xl font-medium transition-colors"
              >
                Отмена
              </button>
              <button
                type="submit"
                className="px-3 py-1.5 text-xs bg-white text-black rounded-xl hover:bg-zinc-200 font-medium transition-colors"
              >
                Сохранить
              </button>
            </div>
          </form>
        </div>
      )}

      <div className="space-y-4">
        {(!sphere.notesList || sphere.notesList.length === 0) ? (
          <div className="text-center py-10 bg-white/60 rounded-2xl border border-dashed border-stone-200">
            <p className="text-zinc-500 text-sm">В этой сфере пока нет заметок.</p>
          </div>
        ) : (
          [...(sphere.notesList || [])]
            .sort((a, b) => {
              if (a.isPinned && !b.isPinned) return -1;
              if (!a.isPinned && b.isPinned) return 1;
              return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
            })
            .map((note) => {
              const videoId = note.youtubeUrl ? extractYoutubeId(note.youtubeUrl) : null;
              
              return (
                <div key={note.id} className={cn(
                  "bg-white p-5 rounded-2xl shadow-sm border transition-all",
                  note.isPinned ? "border-indigo-500/50 ring-1 ring-indigo-500/20" : "border-stone-200"
                )}>
                  <div className="flex justify-between items-start gap-4">
                    <div className="flex-1 flex gap-3">
                      {note.isCheckbox && (
                        <button
                          onClick={() => updateSphereNote(sphere.id, note.id, { isChecked: !note.isChecked })}
                          className={cn(
                            "mt-0.5 flex-shrink-0 w-5 h-5 rounded flex items-center justify-center transition-colors border",
                            note.isChecked 
                              ? "bg-emerald-500 border-emerald-500 text-zinc-900" 
                              : "bg-stone-50 border-stone-300 text-transparent hover:border-zinc-500"
                          )}
                        >
                          <CheckCircle2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                      <div className="flex-1">
                        <NoteContent 
                          content={note.content} 
                          onUpdateContent={(newContent) => updateSphereNote(sphere.id, note.id, { content: newContent })} 
                          isEditing={false} // We will add an edit mode state
                        />
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => updateSphereNote(sphere.id, note.id, { isPinned: !note.isPinned })}
                        className={cn(
                          "p-1 transition-colors",
                          note.isPinned ? "text-indigo-400" : "text-zinc-500 hover:text-indigo-400"
                        )}
                        title={note.isPinned ? "Открепить" : "Закрепить"}
                      >
                        <Pin className={cn("w-4 h-4", note.isPinned && "fill-current")} />
                      </button>
                      {!note.photoUrl && (
                        <label className="text-zinc-500 hover:text-blue-400 transition-colors p-1 cursor-pointer">
                          <input 
                            type="file" 
                            accept="image/*" 
                            className="hidden" 
                            onChange={(e) => handleNotePhotoUpload(note.id, e)} 
                          />
                          <ImagePlus className="w-4 h-4" />
                        </label>
                      )}
                      <button
                        onClick={() => deleteSphereNote(sphere.id, note.id)}
                        className="text-zinc-500 hover:text-red-400 transition-colors p-1"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                
                {note.photoUrl && (
                  <div className="mt-4 relative rounded-xl overflow-hidden border border-stone-200 group w-full max-w-2xl">
                    <img src={note.photoUrl} alt="Note attachment" className="w-full h-auto object-cover max-h-[400px]" />
                    <button 
                      onClick={() => updateSphereNote(sphere.id, note.id, { photoUrl: undefined })}
                      className="absolute top-2 right-2 w-8 h-8 bg-zinc-900/30 backdrop-blur-md rounded-full flex items-center justify-center text-zinc-900 opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-500/80"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                )}
                
                {videoId && (
                  <div className="mt-4 rounded-xl overflow-hidden border border-stone-200 aspect-video w-full max-w-2xl">
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
                )}
                
                <div className="mt-3 text-[10px] text-zinc-500 uppercase tracking-wider font-medium">
                  {format(new Date(note.createdAt), 'd MMM yyyy, HH:mm', { locale: ru })}
                </div>

                <NoteComments 
                  comments={note.comments || []} 
                  onUpdateComments={(comments) => updateSphereNote(sphere.id, note.id, { comments })} 
                />
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
