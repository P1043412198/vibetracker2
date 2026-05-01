import React from 'react';
import { motion } from 'framer-motion';

interface BookVisualizationProps {
  read: number;
  total: number;
}

export function BookVisualization({ read, total }: BookVisualizationProps) {
  const progress = Math.min(Math.max(read / total, 0), 1);
  const pages = Array.from({ length: 10 }); // 10 visual "layers" of pages
  
  return (
    <div className="relative w-16 h-20 bg-emerald-900/20 rounded-md border border-emerald-500/30 overflow-hidden flex items-end">
      {/* Book Spine */}
      <div className="absolute left-0 top-0 bottom-0 w-1.5 bg-emerald-600/40 border-r border-emerald-500/30 z-10" />
      
      {/* Pages filling up */}
      <motion.div 
        initial={{ height: 0 }}
        animate={{ height: `${progress * 100}%` }}
        className="absolute bottom-0 left-1.5 right-0 bg-emerald-500/40 z-0"
      />
      
      {/* Page lines */}
      <div className="absolute inset-0 left-1.5 flex flex-col justify-around py-1 px-1 opacity-20">
        {pages.map((_, i) => (
          <div key={i} className="h-[1px] bg-white w-full" />
        ))}
      </div>

      {/* Progress Text */}
      <div className="absolute inset-0 flex items-center justify-center z-20">
        <span className="text-[10px] font-bold text-white drop-shadow-md">
          {Math.round(progress * 100)}%
        </span>
      </div>
    </div>
  );
}
