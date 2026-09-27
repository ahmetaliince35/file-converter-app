import React from 'react';
import { Loader2, Sparkles, Cpu } from 'lucide-react';

export default function LoadingOverlay({ message = "İşlem yürütülüyor..." }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/75 backdrop-blur-md animate-in fade-in duration-200">
      {/* Arkadaki neon parıltı (ambient glow) */}
      <div className="absolute w-72 h-72 bg-sky-500/10 rounded-full blur-3xl pointer-events-none animate-pulse" />

      {/* Ana Cam Kart */}
      <div className="relative w-full max-w-xs bg-slate-900/90 border border-slate-800/90 rounded-2xl p-6 shadow-2xl flex flex-col items-center gap-4 text-center overflow-hidden">
        
        {/* İkon & Dönen Efekt Katmanı */}
        <div className="relative flex items-center justify-center w-14 h-14">
          {/* Dış halka - Dönme efekti */}
          <div className="absolute inset-0 rounded-2xl border-2 border-dashed border-sky-400/40 animate-[spin_6s_linear_infinite]" />
          
          {/* İç kutu - Hafif gradient ve ikon */}
          <div className="w-11 h-11 rounded-xl bg-gradient-to-tr from-sky-500/20 to-slate-800 border border-sky-500/30 flex items-center justify-center shadow-inner">
            <Loader2 className="w-5 h-5 text-sky-400 animate-spin" />
          </div>
        </div>

        {/* Başlık & Açıklama */}
        <div className="flex flex-col gap-1 z-10">
          <div className="flex items-center justify-center gap-1.5 text-xs font-bold text-white tracking-wide uppercase">
            <Cpu className="w-3.5 h-3.5 text-sky-400" />
            <span>File++ Motoru</span>
          </div>
          <p className="text-xs font-medium text-slate-300">
            {message}
          </p>
          <span className="text-[10px] text-slate-500">
            Bu işlem dosya boyutuna bağlı olarak birkaç saniye sürebilir
          </span>
        </div>

        {/* Sonsuz Akışlı İlerleme Çubuğu */}
        <div className="w-full bg-slate-950/80 rounded-full h-1 overflow-hidden border border-slate-800/80">
          <div className="h-full bg-gradient-to-r from-sky-500 via-emerald-400 to-sky-500 rounded-full w-2/3 animate-[indeterminate_1.5s_infinite_linear]" />
        </div>
      </div>
    </div>
  );
}