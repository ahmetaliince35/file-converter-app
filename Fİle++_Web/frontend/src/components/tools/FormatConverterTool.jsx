import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  FileCode, 
  UploadCloud, 
  Trash2, 
  ArrowRight, 
  FileText, 
  Sparkles, 
  FileType,
  Loader2
} from 'lucide-react';
import { jsPDF } from 'jspdf';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function FormatConverterTool({ setLoading }) {
  const [files, setFiles] = useState([]);
  const [targetFormat, setTargetFormat] = useState('pdf');
  const [processingIndex, setProcessingIndex] = useState(-1);
  const [statusMessage, setStatusMessage] = useState('');
  const { addOutput } = useOutputs();

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'text/*': [
        '.txt', '.md', '.csv', '.log', '.rtf',
        '.json', '.xml', '.html', '.htm',
        '.yaml', '.yml', '.ini', '.conf', '.cfg',
        '.properties', '.sql', '.tex',
        '.cs', '.java', '.py', '.cpp', '.c',
        '.h', '.hpp', '.js', '.ts', '.jsx', '.tsx',
        '.dart', '.php', '.rb', '.go', '.rs',
        '.swift', '.kt', '.kts', '.sh', '.bat',
        '.ps1', '.css', '.scss', '.less', '.vue'
      ],
    },
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles) => {
      setFiles((prev) => [...prev, ...acceptedFiles]);
    },
  });

  // RAM patlamasını önleyen Satır Bazlı PDF Üreticisi
  const convertTextToPdfMemorySafe = async (file) => {
    const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4', compress: true });
    const margin = 12;
    const pageWidth = 210 - margin * 2;
    const pageHeight = 297 - margin * 2;
    const fontSize = 8;
    const lineHeight = 3.8;

    doc.setFont('courier', 'normal');
    doc.setFontSize(fontSize);

    // Başlık
    doc.setFont('helvetica', 'bold');
    doc.text(`Dosya: ${file.name}`, margin, margin);
    doc.setFont('courier', 'normal');
    doc.setFontSize(fontSize);

    let cursorY = margin + 6;

    // FileReader ile devasa string yerine parça parça oku (Streaming mantığı)
    const reader = file.stream().getReader();
    const decoder = new TextDecoder('utf-8');
    let remainder = '';
    let totalLinesCount = 0;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = remainder + decoder.decode(value, { stream: true });
      const lines = chunk.split('\n');
      remainder = lines.pop() || ''; // Son yarım kalan satırı sakla

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].replace(/\r/g, '');
        
        // splitTextToSize'ı 20 MB metne değil, sadece tek bir satıra uygula (RAM'i korur)
        const wrappedSublines = line.length > 80 ? doc.splitTextToSize(line, pageWidth) : [line];

        for (let j = 0; j < wrappedSublines.length; j++) {
          if (cursorY > pageHeight) {
            doc.addPage();
            cursorY = margin;
          }
          doc.text(wrappedSublines[j], margin, cursorY);
          cursorY += lineHeight;
        }

        totalLinesCount++;
        // Her 500 satırda bir tarayıcıya nefes aldır (UI thread kilitlenmesin)
        if (totalLinesCount % 500 === 0) {
          setStatusMessage(`${file.name}: ${totalLinesCount.toLocaleString()} satır işlendi...`);
          await new Promise((resolve) => setTimeout(resolve, 0));
        }
      }
    }

    // Son kalan parçayı yaz
    if (remainder.trim()) {
      if (cursorY > pageHeight) doc.addPage();
      doc.text(remainder, margin, cursorY);
    }

    return doc.output('blob');
  };

  const handleConvert = async () => {
    if (files.length === 0) return;
    setLoading(true);

    try {
      for (let idx = 0; idx < files.length; idx++) {
        setProcessingIndex(idx);
        const file = files[idx];
        const baseName = file.name.substring(0, file.name.lastIndexOf('.')) || file.name;

        if (targetFormat === 'txt') {
          setStatusMessage(`${file.name} dönüştürülüyor...`);
          // Stream veya Blob doğrudan aktarılır, RAM şişmez
          const blob = new Blob([file], { type: 'text/plain;charset=utf-8' });
          addOutput({
            blob,
            name: `${baseName}_utf8.txt`,
            toolSource: 'Metin Çevirici (TXT)'
          });
        } else if (targetFormat === 'pdf') {
          setStatusMessage(`${file.name} PDF formatına derleniyor...`);
          const pdfBlob = await convertTextToPdfMemorySafe(file);
          addOutput({
            blob: pdfBlob,
            name: `${baseName}.pdf`,
            toolSource: 'Metin/Kod > PDF'
          });
        }

        await new Promise((r) => setTimeout(r, 50));
      }

      setFiles([]);
    } catch (err) {
      alert('Dönüştürme Hatası: ' + err.message);
    } finally {
      setLoading(false);
      setProcessingIndex(-1);
      setStatusMessage('');
    }
  };

  const getExtensionColor = (ext) => {
    switch (ext?.toLowerCase()) {
      case 'py': case 'js': case 'ts': case 'jsx': case 'tsx':
        return 'text-amber-400 bg-amber-400/10 border-amber-400/20';
      case 'cs': case 'java': case 'cpp': case 'c':
        return 'text-sky-400 bg-sky-400/10 border-sky-400/20';
      case 'json': case 'xml': case 'yaml':
        return 'text-emerald-400 bg-emerald-400/10 border-emerald-400/20';
      default:
        return 'text-slate-300 bg-slate-800 border-slate-700';
    }
  };

  const totalSizeMB = (
    files.reduce((acc, f) => acc + f.size, 0) / (1024 * 1024)
  ).toFixed(2);

  return (
    <div className="flex flex-col gap-5 max-w-3xl mx-auto w-full">
      <div className="flex items-start justify-between border-b border-slate-800/80 pb-4">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <FileCode className="w-5 h-5" />
            </span>
            Metin ve Kod Çevirici (Streaming Motorlu)
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            20 MB+ devasa dosyalar dahil satır akışı ile belleği şişirmeden dönüştürür.
          </p>
        </div>
      </div>

      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-3 ${
          isDragActive
            ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
            : 'border-slate-800 hover:border-slate-700 bg-slate-900/30 hover:bg-slate-900/50'
        }`}
      >
        <input {...getInputProps()} />
        <div className="p-3.5 rounded-full bg-slate-800/80 border border-slate-700/50 text-sky-400 shadow-inner">
          <UploadCloud className="w-6 h-6" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-200">
            Dosyaları buraya sürükleyin veya <span className="text-sky-400 underline underline-offset-2">seçin</span>
          </p>
          <p className="text-[11px] text-slate-500 mt-1">
            .txt, .py, .cs, .java, .js, .json, .sql, .log (Maks. 1024 MB)
          </p>
        </div>
      </div>

      {files.length > 0 && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3.5 shadow-xl backdrop-blur-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-200">
                Seçilen Dosyalar ({files.length})
              </span>
              <span className="text-[11px] font-mono text-slate-500">
                • {totalSizeMB} MB
              </span>
            </div>
            <button
              onClick={() => setFiles([])}
              className="text-xs text-slate-400 hover:text-rose-400 transition"
            >
              Tümünü Temizle
            </button>
          </div>

          <div className="max-h-48 overflow-y-auto flex flex-col gap-2 pr-1 custom-scrollbar">
            {files.map((file, idx) => {
              const ext = file.name.split('.').pop() || 'TXT';
              const isCurrent = processingIndex === idx;

              return (
                <div
                  key={idx}
                  className={`flex justify-between items-center px-3 py-2 rounded-xl border transition ${
                    isCurrent
                      ? 'bg-sky-500/10 border-sky-500/40'
                      : 'bg-slate-950/70 border-slate-800/80'
                  }`}
                >
                  <div className="flex items-center gap-2.5 truncate">
                    <span className={`text-[10px] font-mono font-semibold px-2 py-0.5 rounded-md border ${getExtensionColor(ext)}`}>
                      {ext.toUpperCase()}
                    </span>
                    <span className="text-xs text-slate-200 truncate max-w-[280px]">
                      {file.name}
                    </span>
                    <span className="text-[10px] text-slate-500 font-mono">
                      ({(file.size / 1024).toFixed(0)} KB)
                    </span>
                    {isCurrent && (
                      <span className="text-[10px] text-sky-400 flex items-center gap-1 ml-2">
                        <Loader2 className="w-3 h-3 animate-spin" /> {statusMessage || 'İşleniyor'}
                      </span>
                    )}
                  </div>

                  <button
                    onClick={() => setFiles((p) => p.filter((_, i) => i !== idx))}
                    className="p-1 rounded-md text-slate-500 hover:text-rose-400 transition"
                    title="Kaldır"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              );
            })}
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-between border-t border-slate-800/80 pt-3 gap-3">
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <span className="text-xs text-slate-400 flex items-center gap-1.5">
                <FileType className="w-3.5 h-3.5 text-slate-500" /> Hedef Format:
              </span>
              <div className="flex p-1 bg-slate-950/80 rounded-xl border border-slate-800/80 flex-1 sm:flex-none">
                <button
                  type="button"
                  onClick={() => setTargetFormat('pdf')}
                  className={`flex-1 sm:flex-none px-3.5 py-1 rounded-lg text-xs font-medium flex items-center justify-center gap-1.5 transition ${
                    targetFormat === 'pdf'
                      ? 'bg-sky-500 text-slate-950 shadow-md font-semibold'
                      : 'text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <FileText className="w-3 h-3" /> PDF
                </button>
                <button
                  type="button"
                  onClick={() => setTargetFormat('txt')}
                  className={`flex-1 sm:flex-none px-3.5 py-1 rounded-lg text-xs font-medium flex items-center justify-center gap-1.5 transition ${
                    targetFormat === 'txt'
                      ? 'bg-sky-500 text-slate-950 shadow-md font-semibold'
                      : 'text-slate-400 hover:text-slate-200'
                  }`}
                >
                  <FileCode className="w-3 h-3" /> TXT (UTF-8)
                </button>
              </div>
            </div>

            <button
              type="button"
              onClick={handleConvert}
              className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-medium px-5 py-2 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Dönüştür & Havuza Ekle</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}