import React from 'react';
import { Trash2, ArrowRight, FileCheck, Layers, Loader2 } from 'lucide-react';

export default function FileQueue({
  files = [],
  onRemove,
  onClear,
  targetFormat,
  onTargetChange,
  availableFormats = [],
  onConvert,
  loading = false,
  btnText = "İşlemi Başlat"
}) {
  // Toplam dosya boyutunu hesapla
  const totalSizeBytes = files.reduce((acc, f) => acc + (f.size || 0), 0);
  const totalSizeFormatted =
    totalSizeBytes > 1024 * 1024
      ? `${(totalSizeBytes / (1024 * 1024)).toFixed(2)} MB`
      : `${(totalSizeBytes / 1024).toFixed(1)} KB`;

  // Uzantıya göre etiket stili
  const getBadgeStyle = (fileName) => {
    const ext = fileName.includes('.') ? fileName.split('.').pop().toLowerCase() : 'txt';
    switch (ext) {
      case 'pdf':
        return 'bg-rose-500/10 text-rose-500 border-rose-500/30';
      case 'py':
      case 'cs':
      case 'js':
      case 'html':
      case 'json':
        return 'bg-emerald-500/10 text-emerald-500 border-emerald-500/30';
      case 'doc':
      case 'docx':
        return 'bg-blue-500/10 text-blue-500 border-blue-500/30';
      default:
        return 'bg-sky-500/10 text-sky-500 border-sky-500/30';
    }
  };

  return (
    <div className="bg-[var(--bg-card)] border border-[var(--border-main)] rounded-2xl p-4 flex flex-col gap-3 shadow-sm backdrop-blur-sm transition-colors duration-200">
      {/* Üst Başlık & Özet Barı */}
      <div className="flex justify-between items-center border-b border-[var(--border-subtle)] pb-2.5 px-0.5">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-sky-500" />
          <span className="text-xs font-bold text-[var(--text-main)] tracking-wide font-display">
            Kuyruk Listesi
          </span>
          <span className="text-[10px] bg-[var(--bg-card-subtle)] border border-[var(--border-subtle)] text-[var(--text-muted)] px-2 py-0.5 rounded-full font-mono font-medium">
            {files.length} dosya • {totalSizeFormatted}
          </span>
        </div>

        <button
          type="button"
          onClick={onClear}
          className="text-[11px] text-[var(--text-muted)] hover:text-rose-500 transition font-medium cursor-pointer"
        >
          Tümünü Temizle
        </button>
      </div>

      {/* Kaydırılabilir Dosya Listesi */}
      <div className="max-h-52 overflow-y-auto flex flex-col gap-1.5 pr-1 custom-scrollbar">
        {files.map((file, idx) => {
          const ext = file.name.includes('.') ? file.name.split('.').pop().toUpperCase() : 'TXT';
          const sizeKb = (file.size / 1024).toFixed(1);

          return (
            <div
              key={idx}
              className="group flex justify-between items-center bg-[var(--bg-card-subtle)] hover:bg-[var(--bg-card)] border border-[var(--border-subtle)] hover:border-[var(--border-main)] px-3 py-2 rounded-xl transition duration-150"
            >
              <div className="flex items-center gap-2.5 truncate max-w-[65%] sm:max-w-[70%]">
                <span
                  className={`text-[9px] font-mono font-bold px-1.5 py-0.5 rounded border uppercase shrink-0 ${getBadgeStyle(file.name)}`}
                >
                  {ext}
                </span>
                <span className="text-xs text-[var(--text-main)] truncate font-medium" title={file.name}>
                  {file.name}
                </span>
              </div>

              <div className="flex items-center gap-2.5 shrink-0">
                <span className="text-[10px] font-mono text-[var(--text-muted)]">
                  {sizeKb} KB
                </span>
                <button
                  type="button"
                  onClick={() => onRemove(idx)}
                  className="p-1 rounded-lg text-[var(--text-muted)] hover:text-rose-500 hover:bg-rose-500/10 transition cursor-pointer"
                  title="Kuyruktan Çıkar"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Alt Aksiyon & Format Seçim Barı */}
      <div className="flex flex-col sm:flex-row justify-between items-center gap-3 pt-3 border-t border-[var(--border-subtle)]">
        {availableFormats.length > 1 ? (
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <span className="text-[11px] text-[var(--text-muted)] font-medium">Hedef:</span>
            {availableFormats.length <= 3 ? (
              <div className="flex bg-[var(--bg-card-subtle)] p-1 rounded-xl border border-[var(--border-main)] gap-1">
                {availableFormats.map((fmt) => (
                  <button
                    key={fmt}
                    type="button"
                    onClick={() => onTargetChange(fmt)}
                    className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition cursor-pointer ${
                      targetFormat === fmt
                        ? 'bg-sky-500 text-white shadow-xs'
                        : 'text-[var(--text-muted)] hover:text-[var(--text-main)]'
                    }`}
                  >
                    {fmt.toUpperCase()}
                  </button>
                ))}
              </div>
            ) : (
              <select
                value={targetFormat}
                onChange={(e) => onTargetChange(e.target.value)}
                className="bg-[var(--bg-card-subtle)] border border-[var(--border-main)] text-[var(--text-main)] text-xs rounded-xl px-2.5 py-1.5 outline-none focus:border-sky-500 font-medium"
              >
                {availableFormats.map((fmt) => (
                  <option key={fmt} value={fmt}>
                    {fmt.toUpperCase()}
                  </option>
                ))}
              </select>
            )}
          </div>
        ) : (
          <div />
        )}

        {/* Aksiyon Başlat Butonu */}
        <button
          type="button"
          onClick={onConvert}
          disabled={loading || files.length === 0}
          className="w-full sm:w-auto flex items-center justify-center gap-2 bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-semibold px-5 py-2 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed text-xs shadow-md shadow-sky-500/20 active:scale-95 cursor-pointer"
        >
          {loading ? (
            <>
              <Loader2 className="w-3.5 h-3.5 animate-spin" />
              <span>İşleniyor...</span>
            </>
          ) : (
            <>
              <span>{btnText}</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </>
          )}
        </button>
      </div>
    </div>
  );
}