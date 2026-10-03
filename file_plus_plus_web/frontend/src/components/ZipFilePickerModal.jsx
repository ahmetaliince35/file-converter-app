import React, { useState } from 'react';
import { 
  FolderArchive, 
  X, 
  CheckSquare, 
  Square, 
  FileCode, 
  FileText, 
  FileSpreadsheet, 
  FileType, 
  Sparkles,
  ArrowRight,
  Filter
} from 'lucide-react';
import { useTheme } from '../context/ThemeContext';

export default function ZipFilePickerModal({ 
  zipName, 
  entries,
  files, 
  onConfirm, 
  onClose 
}) {
  const { isDark } = useTheme();
  const fileItems = entries || files || [];
  const [selectedPaths, setSelectedPaths] = useState(() => 
    fileItems.filter(e => e.isConvertible).map(e => e.path)
  );
  const [targetFormat, setTargetFormat] = useState('pdf');

  const toggleSelect = (path) => {
    setSelectedPaths(prev => 
      prev.includes(path) ? prev.filter(p => p !== path) : [...prev, path]
    );
  };

  const selectAll = () => {
    setSelectedPaths(fileItems.filter(e => e.isConvertible).map(e => e.path));
  };

  const clearAll = () => {
    setSelectedPaths([]);
  };

  const getFileIcon = (ext) => {
    if (['pdf', 'docx', 'doc'].includes(ext)) {
      return <FileText className="w-4 h-4 text-rose-500" />;
    }
    if (['xlsx', 'xls', 'csv'].includes(ext)) {
      return <FileSpreadsheet className="w-4 h-4 text-emerald-500" />;
    }
    return <FileCode className="w-4 h-4 text-sky-500" />;
  };

  const convertibleCount = fileItems.filter(e => e.isConvertible).length;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="w-full max-w-2xl rounded-3xl border shadow-2xl flex flex-col overflow-hidden max-h-[85vh] transition-colors"
        style={{
          backgroundColor: 'var(--bg-card)',
          borderColor: 'var(--border-main)',
        }}
      >
        {/* Başlık */}
        <div 
          className="p-5 border-b flex items-center justify-between"
          style={{ borderColor: 'var(--border-subtle)' }}
        >
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-amber-500">
              <FolderArchive className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold text-[var(--text-main)] font-display">
                ZIP Arşivi İncelendi
              </h2>
              <p className="text-xs text-[var(--text-muted)] truncate max-w-sm sm:max-w-md">
                {zipName} • {fileItems.length} dosya bulundu ({convertibleCount} dönüştürülebilir)
              </p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-2 rounded-xl text-[var(--text-muted)] hover:text-[var(--text-main)] hover:bg-[var(--bg-card-subtle)] transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Seçim Araç Çubuğu */}
        <div 
          className="px-5 py-2.5 border-b flex items-center justify-between text-xs"
          style={{ 
            backgroundColor: 'var(--bg-card-subtle)',
            borderColor: 'var(--border-subtle)'
          }}
        >
          <div className="flex items-center gap-2">
            <span className="font-semibold text-[var(--text-main)]">
              {selectedPaths.length} dosya seçili
            </span>
            <span className="text-[var(--text-subtle)]">•</span>
            <button 
              onClick={selectAll} 
              className="text-sky-500 hover:underline font-medium"
            >
              Tümünü Seç
            </button>
            <span className="text-[var(--text-subtle)]">|</span>
            <button 
              onClick={clearAll} 
              className="text-rose-400 hover:underline font-medium"
            >
              Temizle
            </button>
          </div>

          {/* Hedef Format */}
          <div className="flex items-center gap-1.5 bg-[var(--bg-card)] p-1 rounded-xl border border-[var(--border-main)]">
            <button
              type="button"
              onClick={() => setTargetFormat('pdf')}
              className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition ${
                targetFormat === 'pdf'
                  ? 'bg-rose-500 text-white shadow-sm'
                  : 'text-[var(--text-muted)] hover:text-[var(--text-main)]'
              }`}
            >
              ➔ PDF
            </button>
            <button
              type="button"
              onClick={() => setTargetFormat('txt')}
              className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition ${
                targetFormat === 'txt'
                  ? 'bg-amber-500 text-white shadow-sm'
                  : 'text-[var(--text-muted)] hover:text-[var(--text-main)]'
              }`}
            >
              ➔ TXT
            </button>
          </div>
        </div>

        {/* Dosya Listesi */}
        <div className="flex-1 overflow-y-auto p-4 space-y-1.5 custom-scrollbar">
          {fileItems.map((entry) => {
            const isSelected = selectedPaths.includes(entry.path);
            const isConvertible = entry.isConvertible;

            return (
              <div
                key={entry.path}
                onClick={() => isConvertible && toggleSelect(entry.path)}
                className={`flex items-center justify-between p-2.5 rounded-xl border transition cursor-pointer select-none ${
                  !isConvertible
                    ? 'opacity-40 cursor-not-allowed bg-[var(--bg-card-subtle)] border-transparent'
                    : isSelected
                    ? 'bg-sky-500/10 border-sky-500/30'
                    : 'bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] border-[var(--border-subtle)]'
                }`}
              >
                <div className="flex items-center gap-3 truncate min-w-0 pr-2">
                  <button type="button" className="text-sky-500 shrink-0">
                    {isSelected ? (
                      <CheckSquare className="w-4 h-4 text-sky-500" />
                    ) : (
                      <Square className="w-4 h-4 text-[var(--text-subtle)]" />
                    )}
                  </button>
                  <div className="shrink-0">{getFileIcon(entry.extension)}</div>
                  <div className="truncate">
                    <p className="text-xs font-medium text-[var(--text-main)] truncate">
                      {entry.name}
                    </p>
                    <p className="text-[10px] text-[var(--text-subtle)] truncate">
                      {entry.path}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  <span className="text-[10px] font-mono font-semibold uppercase px-1.5 py-0.5 rounded bg-[var(--bg-card-subtle)] text-[var(--text-muted)] border border-[var(--border-subtle)]">
                    .{entry.extension || 'bin'}
                  </span>
                  {!isConvertible && (
                    <span className="text-[9px] text-amber-500 font-medium">
                      Atlandı (Medya)
                    </span>
                  )}
                </div>
              </div>
            );
          })}
        </div>

        {/* Alt Aksiyon Butonları */}
        <div 
          className="p-4 border-t flex items-center justify-between gap-3"
          style={{ borderColor: 'var(--border-subtle)' }}
        >
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 rounded-xl border border-[var(--border-main)] text-xs font-medium text-[var(--text-muted)] hover:text-[var(--text-main)] hover:bg-[var(--bg-card-subtle)] transition"
          >
            Vazgeç
          </button>

          <button
            type="button"
            disabled={selectedPaths.length === 0}
            onClick={() => onConfirm(selectedPaths, targetFormat)}
            className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white text-xs font-bold shadow-lg shadow-sky-500/20 flex items-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed transition"
          >
            <span>{selectedPaths.length} Dosyayı {targetFormat.toUpperCase()} Yap</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
