import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { convertBatchApi } from '../../services/api';
import { useOutputs } from '../../context/OutputContext';
import { 
  ArrowUp, 
  ArrowDown, 
  Trash2, 
  Layers, 
  GripVertical, 
  FileText, 
  Sparkles,
  RotateCcw,
  UploadCloud
} from 'lucide-react';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function PdfMergeTool({ setLoading }) {
  const [files, setFiles] = useState([]);
  const [draggedIndex, setDraggedIndex] = useState(null);
  const { addOutput } = useOutputs();

  const moveItem = (index, direction) => {
    const targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= files.length) return;
    const newFiles = [...files];
    const temp = newFiles[index];
    newFiles[index] = newFiles[targetIndex];
    newFiles[targetIndex] = temp;
    setFiles(newFiles);
  };

  const removeItem = (index) => {
    setFiles((p) => p.filter((_, idx) => idx !== index));
  };

  const handleDragStart = (e, index) => {
    setDraggedIndex(index);
    e.dataTransfer.effectAllowed = 'move';
  };

  const handleDragOver = (e, index) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newFiles = [...files];
    const item = newFiles.splice(draggedIndex, 1)[0];
    newFiles.splice(index, 0, item);
    setDraggedIndex(index);
    setFiles(newFiles);
  };

  const handleDragEnd = () => {
    setDraggedIndex(null);
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'application/pdf': ['.pdf']
    },
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isSizeErr) alert('1024 MB sınırını aşan PDF dosyaları atlandı.');
        if (isTypeErr) alert('Lütfen yalnızca .pdf uzantılı dosyalar yükleyin.');
      }

      if (acceptedFiles.length > 0) {
        setFiles((prev) => [...prev, ...acceptedFiles]);
      }
    },
  });

  const handleMerge = async () => {
    if (files.length < 2) {
      alert("Birleştirmek için en az 2 PDF yüklemelisiniz.");
      return;
    }
    setLoading(true);

    try {
      const res = await convertBatchApi(files, 'pdf_merge');
      const blob = new Blob([res.data], { type: 'application/pdf' });
      const fileName = `Birlestirilmis_${Date.now()}.pdf`;

      addOutput({
        blob,
        name: fileName,
        toolSource: `PDF Birleştirici (${files.length} Belge)`
      });

      setFiles([]);
    } catch (err) {
      alert("Hata: " + (err.response?.data?.detail || "Birleştirme başarısız."));
    } finally {
      setLoading(false);
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
              <Layers className="w-5 h-5" />
            </span>
            Sıralanabilir Çoklu PDF Birleştirici
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            PDF dosyalarını sürükleyerek veya oklarla sıraya dizin; tek bir PDF dosyasında birleştirin.
          </p>
        </div>

        {files.length > 0 && (
          <button
            onClick={() => setFiles([])}
            className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:bg-slate-800 transition"
          >
            <RotateCcw className="w-3.5 h-3.5" /> Listeyi Sıfırla
          </button>
        )}
      </div>

      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-2xl p-7 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-2.5 ${
          isDragActive
            ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
            : 'border-slate-800 hover:border-slate-700 bg-slate-900/30 hover:bg-slate-900/50'
        }`}
      >
        <input {...getInputProps()} />
        <div className="p-3 rounded-full bg-slate-800/80 border border-slate-700/50 text-sky-400 shadow-inner">
          <UploadCloud className="w-6 h-6" />
        </div>
        <div>
          <p className="text-xs font-medium text-slate-200">
            PDF dosyalarını buraya bırakın veya <span className="text-sky-400 underline">seçin</span>
          </p>
          <p className="text-[11px] text-slate-500 mt-1">Yalnızca PDF formatı (Çoklu Seçim • Maks. 1024 MB)</p>
        </div>
      </div>

      {files.length > 0 && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3.5 shadow-xl backdrop-blur-sm animate-in fade-in duration-200">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-200">
                Birleştirme Sırası ({files.length} Belge)
              </span>
              <span className="text-[11px] font-mono text-slate-500">
                • {totalSizeMB} MB
              </span>
            </div>
            <span className="text-[10px] text-slate-500 hidden sm:inline">
              Öğeleri sürükleyerek de sıralayabilirsiniz
            </span>
          </div>

          <div className="flex flex-col gap-2 max-h-72 overflow-y-auto pr-1 custom-scrollbar">
            {files.map((file, idx) => {
              const isFirst = idx === 0;
              const isLast = idx === files.length - 1;
              const isBeingDragged = draggedIndex === idx;

              return (
                <div
                  key={`${file.name}-${idx}`}
                  draggable
                  onDragStart={(e) => handleDragStart(e, idx)}
                  onDragOver={(e) => handleDragOver(e, idx)}
                  onDragEnd={handleDragEnd}
                  className={`flex items-center justify-between bg-slate-950/70 border px-3 py-2.5 rounded-xl transition duration-150 select-none ${
                    isBeingDragged
                      ? 'border-sky-500 bg-sky-500/10 opacity-70 scale-[0.99]'
                      : 'border-slate-800/80 hover:border-slate-700/80'
                  }`}
                >
                  <div className="flex items-center gap-2.5 truncate">
                    <div className="cursor-grab active:cursor-grabbing text-slate-600 hover:text-slate-400 p-0.5">
                      <GripVertical className="w-4 h-4" />
                    </div>

                    <span
                      className={`w-5 h-5 rounded-lg flex items-center justify-center font-bold font-mono text-[10px] border ${
                        isFirst
                          ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                          : 'bg-slate-900 border-slate-800 text-sky-400'
                      }`}
                    >
                      {idx + 1}
                    </span>

                    <FileText className="w-4 h-4 text-slate-500 shrink-0" />

                    <span className="text-xs text-slate-200 truncate max-w-[220px] sm:max-w-sm">
                      {file.name}
                    </span>

                    <span className="text-[10px] text-slate-500 font-mono hidden sm:inline">
                      ({(file.size / 1024).toFixed(0)} KB)
                    </span>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      type="button"
                      disabled={isFirst}
                      onClick={() => moveItem(idx, -1)}
                      className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-20 disabled:hover:bg-transparent transition"
                      title="Yukarı Taşı"
                    >
                      <ArrowUp className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      disabled={isLast}
                      onClick={() => moveItem(idx, 1)}
                      className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-20 disabled:hover:bg-transparent transition"
                      title="Aşağı Taşı"
                    >
                      <ArrowDown className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => removeItem(idx)}
                      className="p-1 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 ml-1 transition"
                      title="Kaldır"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>

          <div className="flex items-center justify-between border-t border-slate-800/80 pt-3">
            <span className="text-xs text-slate-400">
              {files.length < 2 ? (
                <span className="text-amber-400/90">Birleştirmek için en az 1 dosya daha ekleyin</span>
              ) : (
                <span className="text-emerald-400/90 font-medium">Birleştirmeye hazır</span>
              )}
            </span>

            <button
              type="button"
              onClick={handleMerge}
              disabled={files.length < 2}
              className="bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 disabled:opacity-40 disabled:cursor-not-allowed text-white font-medium px-5 py-2 rounded-xl text-xs flex items-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Belirtilen Sırada Birleştir ({files.length} Belge)</span>
            </button>
          </div>
        </div>
      )}
    </div>
  );
}