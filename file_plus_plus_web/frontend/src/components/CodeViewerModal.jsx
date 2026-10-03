import React, { useState } from 'react';
import { 
  Code2, 
  X, 
  Copy, 
  Check, 
  Download, 
  FileText, 
  WrapText, 
  Maximize2, 
  Minimize2,
  Sparkles
} from 'lucide-react';
import { useTheme } from '../context/ThemeContext';
import { convertTextOrCodeToPdf } from '../services/universalConverter';

export default function CodeViewerModal({ file, textContent, onClose }) {
  const { isDark } = useTheme();
  const [copied, setCopied] = useState(false);
  const [wrapLines, setWrapLines] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [isPdfLoading, setIsPdfLoading] = useState(false);

  const lines = (textContent || '').split('\n');
  const ext = file.name.split('.').pop()?.toUpperCase() || 'KOD';

  const handleCopy = () => {
    navigator.clipboard.writeText(textContent);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadTxt = () => {
    const blob = new Blob([textContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = file.name.endsWith('.txt') ? file.name : `${file.name}.txt`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleDownloadPdf = async () => {
    try {
      setIsPdfLoading(true);
      const pdfBlob = await convertTextOrCodeToPdf(file);
      const url = URL.createObjectURL(pdfBlob);
      const a = document.createElement('a');
      a.href = url;
      const baseName = file.name.substring(0, file.name.lastIndexOf('.')) || file.name;
      a.download = `${baseName}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      alert('PDF oluşturulamadı: ' + e.message);
    } finally {
      setIsPdfLoading(false);
    }
  };

  const editorBg = isDark ? '#101217' : '#F8F9FA';
  const gutterBg = isDark ? '#151820' : '#EEF0F4';
  const gutterColor = isDark ? '#6B7280' : '#9CA3AF';
  const codeColor = isDark ? '#E6EDF3' : '#1F2328';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-black/70 backdrop-blur-md animate-in fade-in duration-200">
      <div 
        className={`w-full rounded-3xl border shadow-2xl flex flex-col overflow-hidden transition-all duration-300 ${
          isFullscreen ? 'h-[96vh] max-w-[96vw]' : 'h-[88vh] max-w-4xl'
        }`}
        style={{
          backgroundColor: 'var(--bg-card)',
          borderColor: 'var(--border-main)',
        }}
      >
        {/* Üst Başlık Barı */}
        <div 
          className="px-5 py-3.5 border-b flex items-center justify-between"
          style={{ borderColor: 'var(--border-subtle)' }}
        >
          <div className="flex items-center gap-3 min-w-0">
            <div className="p-2.5 rounded-2xl bg-sky-500/10 border border-sky-500/20 text-sky-500 shrink-0">
              <Code2 className="w-5 h-5" />
            </div>
            <div className="truncate">
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-bold text-[var(--text-main)] truncate font-display">
                  {file.name}
                </h3>
                <span className="text-[10px] font-mono font-bold uppercase px-2 py-0.5 rounded-md bg-sky-500/10 text-sky-400 border border-sky-500/20 shrink-0">
                  {ext}
                </span>
              </div>
              <p className="text-xs text-[var(--text-muted)] font-mono">
                {lines.length.toLocaleString()} satır • {(textContent.length / 1024).toFixed(1)} KB
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <button
              onClick={() => setIsFullscreen(prev => !prev)}
              className="p-2 rounded-xl text-[var(--text-muted)] hover:text-[var(--text-main)] hover:bg-[var(--bg-card-subtle)] transition"
              title={isFullscreen ? 'Küçült' : 'Tam Ekran'}
            >
              {isFullscreen ? <Minimize2 className="w-4 h-4" /> : <Maximize2 className="w-4 h-4" />}
            </button>
            <button 
              onClick={onClose}
              className="p-2 rounded-xl text-[var(--text-muted)] hover:text-rose-400 hover:bg-[var(--bg-card-subtle)] transition"
              title="Kapat"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Aksiyon Çubuğu */}
        <div 
          className="px-4 py-2 border-b flex flex-wrap items-center justify-between gap-2 text-xs"
          style={{ 
            backgroundColor: 'var(--bg-card-subtle)',
            borderColor: 'var(--border-subtle)' 
          }}
        >
          <div className="flex items-center gap-1.5">
            <button
              onClick={handleCopy}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[var(--bg-card)] border border-[var(--border-main)] hover:border-sky-500/40 text-[var(--text-main)] font-medium transition shadow-sm"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5 text-sky-500" />}
              <span>{copied ? 'Kopyalandı' : 'Kopyala'}</span>
            </button>

            <button
              onClick={handleDownloadPdf}
              disabled={isPdfLoading}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[var(--bg-card)] border border-[var(--border-main)] hover:border-rose-500/40 text-[var(--text-main)] font-medium transition shadow-sm disabled:opacity-50"
            >
              <FileText className="w-3.5 h-3.5 text-rose-500" />
              <span>{isPdfLoading ? 'Derleniyor...' : 'A4 PDF Yap'}</span>
            </button>

            <button
              onClick={handleDownloadTxt}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[var(--bg-card)] border border-[var(--border-main)] hover:border-emerald-500/40 text-[var(--text-main)] font-medium transition shadow-sm"
            >
              <Download className="w-3.5 h-3.5 text-emerald-500" />
              <span>TXT İndir</span>
            </button>
          </div>

          <button
            onClick={() => setWrapLines(prev => !prev)}
            className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border text-[11px] font-medium transition ${
              wrapLines
                ? 'bg-sky-500/10 border-sky-500/30 text-sky-400'
                : 'bg-[var(--bg-card)] border-[var(--border-main)] text-[var(--text-muted)]'
            }`}
          >
            <WrapText className="w-3.5 h-3.5" />
            <span>Satır Kaydır</span>
          </button>
        </div>

        {/* Kod Alanı (Gutter & Editor Body) */}
        <div 
          className="flex-1 overflow-auto flex text-xs font-mono custom-scrollbar"
          style={{ backgroundColor: editorBg }}
        >
          {/* Sol Satır Numaraları */}
          <div 
            className="select-none py-4 px-3 text-right shrink-0 border-r"
            style={{ 
              backgroundColor: gutterBg,
              borderColor: isDark ? '#262A36' : '#E2E5EC',
              color: gutterColor,
              minWidth: '52px'
            }}
          >
            {lines.map((_, i) => (
              <div key={i} className="leading-5">
                {i + 1}
              </div>
            ))}
          </div>

          {/* Kod İçeriği */}
          <div 
            className={`p-4 flex-1 ${wrapLines ? 'whitespace-pre-wrap break-all' : 'whitespace-pre overflow-x-auto custom-scrollbar'}`}
            style={{ color: codeColor }}
          >
            {lines.map((line, i) => (
              <div key={i} className="leading-5 hover:bg-sky-500/5 transition-colors">
                {line || ' '}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
