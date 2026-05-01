import React, { useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useStore } from '../store/useStore';
import { Loader2 } from 'lucide-react';

export function ShareTarget() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  useEffect(() => {
    const title = searchParams.get('title') || '';
    const text = searchParams.get('text') || '';
    const url = searchParams.get('url') || '';

    // Combine available data into a note description
    const parts = [];
    if (title) parts.push(`**${title}**`);
    if (text) parts.push(text);
    if (url) parts.push(url);

    const noteContent = parts.join('\n\n');

    if (noteContent) {
      const store = useStore.getState();
      const spheres = store.spheres;
      
      // Find or create "Заметки" sphere
      let notesSphere = spheres.find(s => s.title.toLowerCase() === 'заметки');
      let sphereId = notesSphere?.id;

      if (!notesSphere) {
        sphereId = store.addSphere({
          title: 'Заметки',
          description: 'Сохраненные ссылки и идеи',
          notes: '',
          notesList: []
        });
      }

      if (sphereId) {
        store.addSphereNote(sphereId, noteContent);
      }
    }

    // Redirect to spheres page after saving
    navigate('/spheres', { replace: true });
  }, [searchParams, navigate]);

  return (
    <div className="flex flex-col items-center justify-center h-full min-h-[50vh] text-zinc-400">
      <Loader2 className="w-8 h-8 animate-spin mb-4 text-emerald-400" />
      <p>Сохраняем в заметки...</p>
    </div>
  );
}
