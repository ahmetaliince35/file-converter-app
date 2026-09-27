import React, { useState } from 'react';
import { TOOLS } from '../constants/tools';
import { ChevronRight, Wrench, Search } from 'lucide-react';

export default function Sidebar({ activeTool, onSelectTool }) {
  const [searchTerm, setSearchTerm] = useState('');

  const filteredTools = TOOLS.filter((t) =>
    t.label.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <aside className="w-full md:w-64 bg-slate-900/60 backdrop-blur-xl border border-slate-800/80 rounded-3xl p-3.5 flex flex-col shrink-0 shadow-2xl max-h-[calc(100vh-4rem)] sticky top-6">
      {/* Üst Logo / Başlık */}
      <div className="px-2.5 pt-1 pb-3 mb-2 border-b border-slate-800/80 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="p-1.5 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
            <Wrench className="w-4 h-4" />
          </span>
          <span className="text-xs font-bold tracking-wide uppercase text-slate-200">
            Araç Kutusu
          </span>
        </div>
        <span className="text-[10px] font-mono font-semibold bg-slate-800/90 text-sky-400 px-2 py-0.5 rounded-full border border-slate-700/50">
          {TOOLS.length} Modül
        </span>
      </div>

      {/* Arama Inputu */}
      <div className="relative mb-2.5 px-1">
        <Search className="w-3.5 h-3.5 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Araç ara..."
          className="w-full bg-slate-950/70 border border-slate-800/90 rounded-xl pl-8 pr-3 py-1.5 text-xs text-slate-200 placeholder:text-slate-600 outline-none focus:border-sky-500/50 focus:ring-1 focus:ring-sky-500/30 transition duration-150"
        />
      </div>

      {/* Dikeyde Kayan Araç Listesi */}
      <nav className="flex flex-col gap-1.5 overflow-y-auto pr-1 select-none custom-scrollbar">
        {filteredTools.map((t) => {
          const Icon = t.icon;
          const isActive = activeTool === t.id;

          return (
            <button
              key={t.id}
              onClick={() => onSelectTool(t.id)}
              className={`group relative flex items-center justify-between px-3 py-2.5 rounded-xl text-left transition-all duration-150 ${
                isActive
                  ? 'bg-slate-800/90 text-white font-medium border border-sky-500/40 shadow-lg shadow-sky-500/10'
                  : 'text-slate-400 hover:bg-slate-800/50 hover:text-slate-200 border border-transparent'
              }`}
            >
              {/* Aktif Sol Vurgu Çizgisi */}
              {isActive && (
                <span className="absolute left-0 top-2 bottom-2 w-1 bg-sky-400 rounded-r-full shadow-sm shadow-sky-400" />
              )}

              <div className="flex items-center gap-3 truncate pl-1">
                <span
                  className={`p-1.5 rounded-lg border transition-colors ${
                    isActive
                      ? 'bg-sky-500/20 border-sky-500/30 text-sky-300'
                      : 'bg-slate-950/60 border-slate-800/80 text-slate-400 group-hover:text-slate-300 group-hover:border-slate-700'
                  }`}
                >
                  <Icon className="w-4 h-4 shrink-0" />
                </span>
                <span className="text-xs truncate">{t.label}</span>
              </div>

              <div className="flex items-center gap-1.5 shrink-0 ml-2">
                {t.badge && (
                  <span
                    className={`text-[9px] px-1.5 py-0.5 rounded-md font-mono font-medium border ${
                      isActive
                        ? 'bg-sky-950/80 text-sky-300 border-sky-500/30'
                        : 'bg-slate-950 text-slate-500 border-slate-800'
                    }`}
                  >
                    {t.badge}
                  </span>
                )}
                <ChevronRight
                  className={`w-3.5 h-3.5 transition-transform duration-150 ${
                    isActive
                      ? 'text-sky-400 translate-x-0.5'
                      : 'text-slate-600 opacity-0 group-hover:opacity-100'
                  }`}
                />
              </div>
            </button>
          );
        })}
      </nav>
    </aside>
  );
}