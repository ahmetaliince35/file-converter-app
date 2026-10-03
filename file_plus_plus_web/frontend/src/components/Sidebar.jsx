import React, { useState } from 'react';
import { TOOLS } from '../constants/tools';
import { ChevronRight, Wrench, Search } from 'lucide-react';

export default function Sidebar({ activeTool, onSelectTool }) {
  const [searchTerm, setSearchTerm] = useState('');

  const filteredTools = TOOLS.filter((t) =>
    t.label.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <aside className="w-full md:w-68 bg-[var(--bg-card)] backdrop-blur-xl border border-[var(--border-main)] rounded-3xl p-3.5 flex flex-col shrink-0 shadow-sm max-h-[calc(100vh-4rem)] sticky top-6 transition-colors duration-200">
      {/* Üst Başlık */}
      <div className="px-2.5 pt-1 pb-3 mb-2 border-b border-[var(--border-subtle)] flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="p-1.5 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-500">
            <Wrench className="w-4 h-4" />
          </span>
          <span className="text-xs font-bold tracking-wide uppercase text-[var(--text-main)] font-display">
            Araç Kutusu
          </span>
        </div>
        <span className="text-[10px] font-mono font-semibold bg-[var(--bg-card-subtle)] text-sky-500 px-2 py-0.5 rounded-full border border-[var(--border-subtle)]">
          {TOOLS.length} Modül
        </span>
      </div>

      {/* Arama Inputu */}
      <div className="relative mb-2.5 px-1">
        <Search className="w-3.5 h-3.5 text-[var(--text-muted)] absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
        <input
          type="text"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          placeholder="Araç ara..."
          className="w-full bg-[var(--bg-card-subtle)] border border-[var(--border-main)] rounded-xl pl-8 pr-3 py-1.5 text-xs text-[var(--text-main)] placeholder:text-[var(--text-muted)] outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500/30 transition duration-150"
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
              className={`group relative flex items-center justify-between px-3 py-2.5 rounded-2xl text-left transition-all duration-150 cursor-pointer ${
                isActive
                  ? 'bg-sky-500/10 text-sky-500 font-semibold border border-sky-500/30 shadow-xs'
                  : 'text-[var(--text-muted)] hover:bg-[var(--bg-card-subtle)] hover:text-[var(--text-main)] border border-transparent'
              }`}
            >
              {/* Aktif Sol Vurgu Çizgisi */}
              {isActive && (
                <span className="absolute left-0 top-2 bottom-2 w-1 bg-sky-500 rounded-r-full shadow-sm shadow-sky-500" />
              )}

              <div className="flex items-center gap-3 truncate pl-1">
                <span
                  className={`p-1.5 rounded-xl border transition-colors ${
                    isActive
                      ? 'bg-sky-500 text-white border-sky-500 shadow-sm'
                      : 'bg-[var(--bg-card-subtle)] border-[var(--border-subtle)] text-[var(--text-muted)] group-hover:text-[var(--text-main)] group-hover:border-[var(--border-main)]'
                  }`}
                >
                  <Icon className="w-4 h-4 shrink-0" />
                </span>
                <span className="text-xs truncate font-medium">{t.label}</span>
              </div>

              <div className="flex items-center gap-1.5 shrink-0 ml-2">
                {t.badge && (
                  <span
                    className={`text-[9px] px-1.5 py-0.5 rounded-md font-mono font-bold border ${
                      isActive
                        ? 'bg-sky-500/20 text-sky-500 border-sky-500/30'
                        : 'bg-[var(--bg-card-subtle)] text-[var(--text-muted)] border-[var(--border-subtle)]'
                    }`}
                  >
                    {t.badge}
                  </span>
                )}
                <ChevronRight
                  className={`w-3.5 h-3.5 transition-transform duration-150 ${
                    isActive
                      ? 'text-sky-500 translate-x-0.5'
                      : 'text-[var(--text-muted)] opacity-0 group-hover:opacity-100'
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