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
        return 'bg-rose-500/10 text-rose-400 border-rose-500/20';
      case 'py':
      case 'cs':
      case 'js':
      case 'html':
      case 'json':
        return 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';
      case 'doc':
      case 'docx':
        return 'bg-blue-500/10 text-blue-400 border-blue-500/20';
      default:
        return 'bg-sky-500/10 text-sky-400 border-sky-500/20';
    }
  };

  return (
    <div className="bg-slate-950/80 border border-slate-800/90 rounded-2xl p-4 flex flex-col gap-3 shadow-xl backdrop-blur-sm">
      {/* Üst Başlık & Özet Barı */}
      <div className="flex justify-between items-center border-b border-slate-800/80 pb-2.5 px-0.5">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full bg-sky-400" />
          <span className="text-xs font-bold text-white tracking-wide">
            Kuyruk Listesi
          </span>
          <span className="text-[10px] bg-slate-900 border border-slate-800 text-slate-300 px-2 py-0.5 rounded-full font-mono">
            {files.length} dosya • {totalSizeFormatted}
          </span>
        </div>

        <button
          type="button"
          onClick={onClear}
          className="text-[11px] text-slate-400 hover:text-rose-400 transition font-medium"
        >
          Tümünü Temizle
        </button>
      </div>

      {/* Kaydırılabilir Dosya Listesi */}
      <div className="max-h-52 overflow-y-auto flex flex-col gap-1.5 pr-1 scrollbar-thin scrollbar-thumb-slate-800">
        {files.map((file, idx) => {
          const ext = file.name.includes('.') ? file.name.split('.').pop().toUpperCase() : 'TXT';
          const sizeKb = (file.size / 1024).toFixed(1);

          return (
            <div
              key={idx}
              className="group flex justify-between items-center bg-slate-900/60 hover:bg-slate-900 border border-slate-850 hover:border-slate-700/80 px-3 py-2 rounded-xl transition duration-150"
            >
              <div className="flex items-center gap-2.5 truncate max-w-[65%] sm:max-w-[70%]">
                <span
                  className={`text-[9px] font-mono font-bold px-1.5 py-0.5 rounded border uppercase shrink-0 ${getBadgeStyle(file.name)}`}
                >
                  {ext}
                </span>
                <span className="text-xs text-slate-200 truncate font-medium" title={file.name}>
                  {file.name}
                </span>
              </div>

              <div className="flex items-center gap-2.5 shrink-0">
                <span className="text-[10px] font-mono text-slate-500">
                  {sizeKb} KB
                </span>
                <button
                  type="button"
                  onClick={() => onRemove(idx)}
                  className="p-1 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-slate-800/80 transition"
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
      <div className="flex flex-col sm:flex-row justify-between items-center gap-3 pt-3 border-t border-slate-800/80">
        {/* Hedef Format: 2-3 seçenek varsa Segment Buton, fazlaysa Select */}
        {availableFormats.length > 1 ? (
          <div className="flex items-center gap-2 w-full sm:w-auto">
            <span className="text-[11px] text-slate-400 font-medium">Hedef:</span>
            {availableFormats.length <= 3 ? (
              <div className="flex bg-slate-900 p-1 rounded-xl border border-slate-800 gap-1">
                {availableFormats.map((fmt) => (
                  <button
                    key={fmt}
                    type="button"
                    onClick={() => onTargetChange(fmt)}
                    className={`px-2.5 py-1 rounded-lg text-[11px] font-semibold transition ${
                      targetFormat === fmt
                        ? 'bg-sky-500 text-slate-950 shadow-sm'
                        : 'text-slate-400 hover:text-white'
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
                className="bg-slate-900 border border-slate-700/80 text-slate-200 text-xs rounded-xl px-2.5 py-1.5 outline-none focus:border-sky-400 font-medium"
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
          className="w-full sm:w-auto flex items-center justify-center gap-2 bg-sky-500 hover:bg-sky-400 text-slate-950 font-bold px-5 py-2 rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed text-xs shadow-lg shadow-sky-500/10 active:scale-95"
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