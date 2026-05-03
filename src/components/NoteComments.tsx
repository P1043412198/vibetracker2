import React, { useState } from 'react';
import { format } from 'date-fns';
import { ru } from 'date-fns/locale';
import { MessageSquare, Send, Edit2, Trash2, Check, X, ChevronDown, ChevronUp } from 'lucide-react';
import { v4 as uuidv4 } from 'uuid';
import { NoteComment } from '../types';

interface NoteCommentsProps {
  comments: NoteComment[];
  onUpdateComments: (comments: NoteComment[]) => void;
}

export const NoteComments: React.FC<NoteCommentsProps> = ({ comments, onUpdateComments }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [newComment, setNewComment] = useState('');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  const handleAddComment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim()) return;

    const comment: NoteComment = {
      id: uuidv4(),
      content: newComment.trim(),
      createdAt: new Date().toISOString(),
    };

    onUpdateComments([...comments, comment]);
    setNewComment('');
  };

  const handleDelete = (id: string) => {
    onUpdateComments(comments.filter(c => c.id !== id));
  };

  const startEditing = (comment: NoteComment) => {
    setEditingId(comment.id);
    setEditContent(comment.content);
  };

  const handleSaveEdit = () => {
    if (!editContent.trim()) return;
    onUpdateComments(
      comments.map(c => c.id === editingId ? { ...c, content: editContent.trim() } : c)
    );
    setEditingId(null);
    setEditContent('');
  };

  return (
    <div className="mt-4 border-t border-stone-200/70 pt-3">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-2 text-xs font-medium text-zinc-500 hover:text-zinc-800 transition-colors"
      >
        <MessageSquare className="w-3.5 h-3.5" />
        {comments.length} {comments.length === 1 ? 'комментарий' : comments.length > 1 && comments.length < 5 ? 'комментария' : 'комментариев'}
        {isOpen ? <ChevronUp className="w-3.5 h-3.5 ml-1" /> : <ChevronDown className="w-3.5 h-3.5 ml-1" />}
      </button>

      {isOpen && (
        <div className="mt-4 space-y-4">
          <div className="space-y-3">
            {comments.map((comment) => (
              <div key={comment.id} className="bg-stone-50/50 rounded-xl p-3 border border-stone-200/70 group">
                <div className="flex justify-between items-start gap-2 mb-1">
                  <span className="text-[10px] text-zinc-500 uppercase tracking-wider font-medium">
                    {format(new Date(comment.createdAt), 'd MMM yyyy, HH:mm', { locale: ru })}
                  </span>
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      onClick={() => startEditing(comment)}
                      className="p-1 text-zinc-500 hover:text-blue-400 transition-colors"
                    >
                      <Edit2 className="w-3 h-3" />
                    </button>
                    <button
                      onClick={() => handleDelete(comment.id)}
                      className="p-1 text-zinc-500 hover:text-red-400 transition-colors"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                </div>

                {editingId === comment.id ? (
                  <div className="mt-2 space-y-2">
                    <textarea
                      value={editContent}
                      onChange={(e) => setEditContent(e.target.value)}
                      className="w-full px-3 py-2 bg-white border border-stone-300 text-zinc-900 rounded-lg focus:ring-1 focus:ring-zinc-500 focus:border-zinc-500 min-h-[60px] resize-y text-xs"
                      autoFocus
                    />
                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => setEditingId(null)}
                        className="p-1.5 text-zinc-500 hover:text-zinc-900 hover:bg-stone-100 rounded-lg transition-colors"
                      >
                        <X className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={handleSaveEdit}
                        className="p-1.5 text-emerald-400 hover:text-emerald-300 hover:bg-emerald-400/10 rounded-lg transition-colors"
                      >
                        <Check className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="text-xs text-zinc-700 whitespace-pre-wrap leading-relaxed">
                    {comment.content}
                  </div>
                )}
              </div>
            ))}
          </div>

          <form onSubmit={handleAddComment} className="flex gap-2">
            <input
              type="text"
              value={newComment}
              onChange={(e) => setNewComment(e.target.value)}
              placeholder="Добавить комментарий..."
              className="flex-1 bg-stone-50 border border-stone-200 text-zinc-900 text-xs rounded-xl px-3 py-2 focus:outline-none focus:ring-1 focus:ring-zinc-500"
            />
            <button
              type="submit"
              disabled={!newComment.trim()}
              className="p-2 bg-white text-black rounded-xl hover:bg-zinc-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <Send className="w-4 h-4" />
            </button>
          </form>
        </div>
      )}
    </div>
  );
};
