import React, { useRef, useEffect, useState } from 'react';
import { Camera, X } from 'lucide-react';
import * as PoseModule from '@mediapipe/pose';
import { Camera as MediaPipeCamera } from '@mediapipe/camera_utils';
import { drawConnectors, drawLandmarks } from '@mediapipe/drawing_utils';
import { set, get } from 'idb-keyval';

type ExerciseType = 'squats' | 'pushups' | 'pullups' | 'benchpress' | 'abs' | 'kegel';

const EXERCISES: { id: ExerciseType, name: string }[] = [
  { id: 'squats', name: 'Приседания' },
  { id: 'pushups', name: 'Отжимания' },
  { id: 'pullups', name: 'Подтягивания' },
  { id: 'benchpress', name: 'Жим лежа' },
  { id: 'abs', name: 'Пресс' },
  { id: 'kegel', name: 'Кегель (не отслеживается)' },
];

export function CameraTracker({ onClose }: { onClose: () => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [error, setError] = useState<string | null>(null);
  const [exercise, setExercise] = useState<ExerciseType>('squats');
  const exerciseRef = useRef(exercise);
  const [count, setCount] = useState(0);
  const [isPerforming, setIsPerforming] = useState(false);
  const isPerformingRef = useRef(isPerforming);

  useEffect(() => {
    exerciseRef.current = exercise;
  }, [exercise]);

  useEffect(() => {
    isPerformingRef.current = isPerforming;
  }, [isPerforming]);
  const [isRecording, setIsRecording] = useState(false);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  const saveStats = async () => {
    const stats: any[] = (await get('workout-stats')) || [];
    stats.push({ exercise, count, date: new Date().toISOString() });
    await set('workout-stats', stats);
  };

  const startRecording = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const stream = canvas.captureStream(30);
    mediaRecorderRef.current = new MediaRecorder(stream, { mimeType: 'video/webm' });
    chunksRef.current = [];
    mediaRecorderRef.current.ondataavailable = (e) => chunksRef.current.push(e.data);
    mediaRecorderRef.current.onstop = () => {
      const blob = new Blob(chunksRef.current, { type: 'video/webm' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `workout-${exercise}-${new Date().getTime()}.webm`;
      a.click();
    };
    mediaRecorderRef.current.start();
    setIsRecording(true);
  };

  const stopRecording = () => {
    mediaRecorderRef.current?.stop();
    setIsRecording(false);
    saveStats();
  };

  const calculateAngle = (a: { x: number, y: number }, b: { x: number, y: number }, c: { x: number, y: number }) => {
    const radians = Math.atan2(c.y - b.y, c.x - b.x) - Math.atan2(a.y - b.y, a.x - b.x);
    let angle = Math.abs(radians * 180.0 / Math.PI);
    if (angle > 180.0) angle = 360 - angle;
    return angle;
  };

  useEffect(() => {
    const pose = new PoseModule.Pose({
      locateFile: (file) => {
        console.log(`Loading MediaPipe asset: ${file}`);
        return `https://unpkg.com/@mediapipe/pose@0.5.1675469404/${file}`;
      },
    });

    pose.setOptions({
      modelComplexity: 1,
      smoothLandmarks: true,
      minDetectionConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });

    pose.onResults((results: PoseModule.Results) => {
      const canvasElement = canvasRef.current;
      if (!canvasElement) return;
      const canvasCtx = canvasElement.getContext('2d');
      if (!canvasCtx) return;

      canvasCtx.save();
      canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);
      
      if (results.poseLandmarks) {
        drawConnectors(canvasCtx, results.poseLandmarks, [[11, 12], [11, 13], [13, 15], [12, 14], [14, 16], [11, 23], [12, 24], [23, 24], [23, 25], [25, 27], [27, 29], [29, 31], [31, 27], [24, 26], [26, 28], [28, 30], [30, 32], [32, 28]], { color: '#00FF00', lineWidth: 4 });
        drawLandmarks(canvasCtx, results.poseLandmarks, { color: '#FF0000', lineWidth: 2 });

        // Logic switch
        const landmarks = results.poseLandmarks;
        const drawAngle = (angle: number, target: string) => {
          canvasCtx.font = '20px Arial';
          canvasCtx.fillStyle = 'white';
          canvasCtx.fillText(`Угол: ${Math.round(angle)}°`, 50, 50);
          canvasCtx.fillText(`Цель: ${target}`, 50, 80);
        };

        if (exerciseRef.current === 'squats') {
          const hip = landmarks[24];
          const knee = landmarks[26];
          const ankle = landmarks[28];
          if (hip && knee && ankle) {
            const angle = calculateAngle(hip, knee, ankle);
            drawAngle(angle, '< 100° / > 160°');
            if (angle < 100 && !isPerformingRef.current) {
              isPerformingRef.current = true;
              setIsPerforming(true);
            } else if (angle > 160 && isPerformingRef.current) {
              setCount(p => p + 1);
              isPerformingRef.current = false;
              setIsPerforming(false);
            }
          }
        } else if (exerciseRef.current === 'pushups') {
          const shoulder = landmarks[12];
          const elbow = landmarks[14];
          const wrist = landmarks[16];
          if (shoulder && elbow && wrist) {
            const angle = calculateAngle(shoulder, elbow, wrist);
            drawAngle(angle, '< 90° / > 160°');
            if (angle < 90 && !isPerformingRef.current) {
              isPerformingRef.current = true;
              setIsPerforming(true);
            } else if (angle > 160 && isPerformingRef.current) {
              setCount(p => p + 1);
              isPerformingRef.current = false;
              setIsPerforming(false);
            }
          }
        } else if (exerciseRef.current === 'abs') {
          const shoulder = landmarks[12];
          const hip = landmarks[24];
          const knee = landmarks[26];
          if (shoulder && hip && knee) {
            const angle = calculateAngle(shoulder, hip, knee);
            drawAngle(angle, '< 90° / > 130°');
            if (angle < 90 && !isPerformingRef.current) {
              isPerformingRef.current = true;
              setIsPerforming(true);
            } else if (angle > 130 && isPerformingRef.current) {
              setCount(p => p + 1);
              isPerformingRef.current = false;
              setIsPerforming(false);
            }
          }
        } else if (exerciseRef.current === 'pullups') {
          const shoulder = landmarks[12];
          const elbow = landmarks[14];
          const wrist = landmarks[16];
          if (shoulder && elbow && wrist) {
            const angle = calculateAngle(shoulder, elbow, wrist);
            drawAngle(angle, '< 90° / > 160°');
            if (angle < 90 && !isPerformingRef.current) {
              isPerformingRef.current = true;
              setIsPerforming(true);
            } else if (angle > 160 && isPerformingRef.current) {
              setCount(p => p + 1);
              isPerformingRef.current = false;
              setIsPerforming(false);
            }
          }
        } else if (exerciseRef.current === 'benchpress') {
          const shoulder = landmarks[12];
          const elbow = landmarks[14];
          const wrist = landmarks[16];
          if (shoulder && elbow && wrist) {
            const angle = calculateAngle(shoulder, elbow, wrist);
            drawAngle(angle, '< 90° / > 160°');
            if (angle < 90 && !isPerformingRef.current) {
              isPerformingRef.current = true;
              setIsPerforming(true);
            } else if (angle > 160 && isPerformingRef.current) {
              setCount(p => p + 1);
              isPerformingRef.current = false;
              setIsPerforming(false);
            }
          }
        }
      }
      canvasCtx.restore();
    });

    let camera: MediaPipeCamera | null = null;
    if (videoRef.current) {
      camera = new MediaPipeCamera(videoRef.current, {
        onFrame: async () => {
          if (videoRef.current) await pose.send({ image: videoRef.current });
        },
        width: { ideal: 1280 },
        height: { ideal: 720 },
        facingMode: 'user',
      });
      camera.start().catch(err => { setError('Не удалось запустить камеру.'); console.error(err); });
    }

    return () => { camera?.stop(); pose.close(); };
  }, []);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 p-4">
      <div className="relative w-full max-w-2xl aspect-video bg-zinc-900 rounded-2xl overflow-hidden">
        {error ? (
          <div className="flex items-center justify-center h-full text-red-400">{error}</div>
        ) : (
          <>
            <video ref={videoRef} className="absolute inset-0 w-full h-full object-cover" />
            <canvas ref={canvasRef} width={640} height={480} className="absolute inset-0 w-full h-full object-cover" />
            <div className="absolute top-4 left-4 flex gap-2">
              <select value={exercise} onChange={(e) => { setExercise(e.target.value as ExerciseType); setCount(0); }} className="bg-black/50 text-white p-2 rounded-lg">
                {EXERCISES.map(ex => <option key={ex.id} value={ex.id}>{ex.name}</option>)}
              </select>
              <div className="bg-black/50 text-white px-4 py-2 rounded-full text-xl font-bold">
                {EXERCISES.find(e => e.id === exercise)?.name}: {count}
              </div>
            </div>
            <button
              onClick={isRecording ? stopRecording : startRecording}
              className={`absolute bottom-4 left-1/2 -translate-x-1/2 px-6 py-2 rounded-full font-bold ${isRecording ? 'bg-red-500' : 'bg-green-500'} text-white`}
            >
              {isRecording ? 'Стоп запись' : 'Начать запись'}
            </button>
          </>
        )}
        <button onClick={onClose} className="absolute top-4 right-4 p-2 bg-black/50 text-white rounded-full hover:bg-black/70"><X className="w-6 h-6" /></button>
      </div>
    </div>
  );
}
