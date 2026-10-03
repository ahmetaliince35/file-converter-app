import React from 'react';
import { Layers, LogOut, Cloud, ShieldCheck, Sun, Moon } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';

export default function Header() {
  const { provider, loginMicrosoft, loginGoogle, logout } = useAuth();
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="relative flex flex-col sm:flex-row justify-between items-center pb-4 mb-1 border-b border-[var(--border-main)] gap-4 transition-colors duration-200">
      {/* Sol Logo & Marka */}
      <div className="flex items-center gap-3.5 select-none">
        <div className="relative group">
          <div className="absolute -inset-1 bg-gradient-to-r from-sky-500 to-indigo-500 rounded-2xl blur-md opacity-30 group-hover:opacity-60 transition duration-300 pointer-events-none" />
          <div className="relative bg-[var(--bg-card)] border border-[var(--border-main)] p-2.5 rounded-2xl text-sky-500 shadow-md flex items-center justify-center">
            <Layers className="w-5 h-5 text-sky-500 group-hover:scale-105 transition-transform" />
          </div>
        </div>

        <div className="flex flex-col">
          <div className="flex items-center gap-2">
            <h1 className="text-xl font-black tracking-tight text-[var(--text-main)] font-display">
              File<span className="text-sky-500">++</span>
            </h1>
            <span className="text-[10px] font-mono uppercase tracking-wider bg-sky-500/10 text-sky-500 border border-sky-500/20 px-2 py-0.5 rounded-md font-bold">
              Studio Web
            </span>
          </div>
          <p className="text-xs text-[var(--text-muted)] flex items-center gap-1.5 font-medium">
            <span>Hibrit Dönüştürme & Belge Motoru</span>
            <span>•</span>
            <span className="text-emerald-500 text-[11px] flex items-center gap-1 font-semibold">
              <ShieldCheck className="w-3.5 h-3.5" /> %100 Yerel & Gizlilik Odaklı
            </span>
          </p>
        </div>
      </div>

      {/* Sağ Auth & Tema Seçici */}
      <div className="flex items-center gap-3">
        {/* Tema Değiştirici Buton (Güneş / Ay) */}
        <button
          onClick={toggleTheme}
          className="flex items-center gap-2 px-3 py-1.5 rounded-xl border border-[var(--border-main)] bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] text-[var(--text-main)] transition shadow-sm text-xs font-medium cursor-pointer"
          title={theme === 'dark' ? 'Açık Temaya Geç (Warm Linen)' : 'Karanlık Temaya Geç (Obsidian)'}
          aria-label="Temayı Değiştir"
        >
          {theme === 'dark' ? (
            <>
              <Sun className="w-4 h-4 text-amber-400 animate-in spin-in-180 duration-300" />
              <span className="hidden sm:inline text-xs text-[var(--text-muted)]">Açık</span>
            </>
          ) : (
            <>
              <Moon className="w-4 h-4 text-indigo-500 animate-in spin-in-180 duration-300" />
              <span className="hidden sm:inline text-xs text-[var(--text-muted)]">Koyu</span>
            </>
          )}
        </button>

        {/* Bulut Depolama Durumu */}
        {!provider ? (
          <div className="flex items-center gap-1.5 bg-[var(--bg-card-subtle)] p-1 rounded-2xl border border-[var(--border-main)] shadow-sm">
            <button
              onClick={loginGoogle}
              className="bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] text-[var(--text-main)] border border-[var(--border-main)] text-xs font-medium px-3 py-1.5 rounded-xl flex items-center gap-2 transition-all shadow-xs"
              title="Google Drive Entegrasyonu"
            >
              <img
                src="https://www.svgrepo.com/show/475656/google-color.svg"
                className="w-3.5 h-3.5"
                alt="Google"
              />
              <span className="hidden xs:inline">Drive</span>
            </button>

            <button
              onClick={loginMicrosoft}
              className="bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] text-[var(--text-main)] border border-[var(--border-main)] text-xs font-medium px-3 py-1.5 rounded-xl flex items-center gap-2 transition-all shadow-xs"
              title="OneDrive Entegrasyonu"
            >
              <img
                src="https://www.svgrepo.com/show/452062/microsoft.svg"
                className="w-3.5 h-3.5"
                alt="Microsoft"
              />
              <span className="hidden xs:inline">OneDrive</span>
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2.5 bg-[var(--bg-card)] border border-emerald-500/30 px-3 py-1.5 rounded-2xl shadow-sm">
            <div className="flex items-center gap-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
              </span>
              <Cloud className="w-3.5 h-3.5 text-emerald-500" />
              <span className="text-xs font-semibold text-[var(--text-main)]">
                {provider === 'google' ? 'Google Drive' : 'OneDrive'}
              </span>
            </div>

            <div className="h-3.5 w-px bg-[var(--border-main)]" />

            <button
              onClick={logout}
              className="text-[var(--text-muted)] hover:text-rose-500 p-1 rounded-md hover:bg-[var(--bg-card-subtle)] transition"
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