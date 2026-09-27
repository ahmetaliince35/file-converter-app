import React from 'react';
import { Layers, LogOut, Cloud, ShieldCheck } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Header() {
  const { provider, loginMicrosoft, loginGoogle, logout } = useAuth();

  return (
    <header className="relative flex flex-col sm:flex-row justify-between items-center pb-4 mb-2 border-b border-slate-800/80 gap-4">
      {/* Sol Logo & Marka */}
      <div className="flex items-center gap-3.5 select-none">
        <div className="relative group">
          <div className="absolute -inset-1 bg-gradient-to-r from-sky-500 to-emerald-500 rounded-2xl blur-md opacity-30 group-hover:opacity-60 transition duration-300 pointer-events-none" />
          <div className="relative bg-slate-900 border border-slate-700/80 p-2.5 rounded-2xl text-sky-400 shadow-xl flex items-center justify-center">
            <Layers className="w-5 h-5 text-sky-400 group-hover:scale-105 transition-transform" />
          </div>
        </div>

        <div className="flex flex-col">
          <div className="flex items-center gap-2">
            <h1 className="text-lg font-extrabold tracking-tight text-white font-sans">
              File<span className="text-sky-400">++</span>
            </h1>
            <span className="text-[10px] font-mono uppercase tracking-wider bg-sky-500/10 text-sky-300 border border-sky-500/20 px-1.5 py-0.2 rounded-md font-semibold">
              Studio
            </span>
          </div>
          <p className="text-[11px] text-slate-400 flex items-center gap-1.5 font-medium">
            <span>Hibrit Bulut & Belge Motoru</span>
            <span className="text-slate-600">•</span>
            <span className="text-emerald-400 text-[10px] flex items-center gap-1">
              <ShieldCheck className="w-3 h-3" /> Yerel Güvenli
            </span>
          </p>
        </div>
      </div>

      {/* Sağ Auth / Hesap Durumu */}
      <div className="flex items-center gap-2.5">
        {!provider ? (
          <div className="flex items-center gap-2 bg-slate-950/60 p-1 rounded-xl border border-slate-800/90 shadow-inner">
            <button
              onClick={loginGoogle}
              className="bg-slate-900/90 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/60 hover:border-slate-600 text-xs font-medium px-3 py-1.5 rounded-lg flex items-center gap-2 transition-all shadow-sm"
              title="Google Drive Entegrasyonu"
            >
              <img
                src="https://www.svgrepo.com/show/475656/google-color.svg"
                className="w-3.5 h-3.5"
                alt="Google"
              />
              <span className="hidden xs:inline">Google</span>
            </button>

            <button
              onClick={loginMicrosoft}
              className="bg-slate-900/90 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-700/60 hover:border-slate-600 text-xs font-medium px-3 py-1.5 rounded-lg flex items-center gap-2 transition-all shadow-sm"
              title="OneDrive Entegrasyonu"
            >
              <img
                src="https://www.svgrepo.com/show/452062/microsoft.svg"
                className="w-3.5 h-3.5"
                alt="Microsoft"
              />
              <span className="hidden xs:inline">Microsoft</span>
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2.5 bg-slate-950 border border-emerald-500/20 px-3 py-1.5 rounded-xl shadow-lg shadow-emerald-500/5">
            <div className="flex items-center gap-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
              </span>
              <Cloud className="w-3.5 h-3.5 text-emerald-400" />
              <span className="text-xs font-semibold text-slate-200">
                {provider === 'google' ? 'Google Drive' : 'OneDrive'}
              </span>
            </div>

            <div className="h-3.5 w-px bg-slate-800" />

            <button
              onClick={logout}
              className="text-slate-400 hover:text-rose-400 p-1 rounded-md hover:bg-slate-900 transition"
              title="Bağlantıyı Kes"
            >
              <LogOut className="w-3.5 h-3.5" />
            </button>
          </div>
        )}
      </div>
    </header>
  );
}