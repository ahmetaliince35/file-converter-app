import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { UploadCloud, AlertCircle, FileCheck2, Sparkles } from 'lucide-react';

export default function DropZone({
  onFilesAdded,
  accept,
  hint = "Dosyaları sürükleyin veya göz atın",
  maxSize = 1024 * 1024 * 1024, // 1024 MB varsayılan
  multiple = true,
  maxFiles,
}) {
  const [errorMessage, setErrorMessage] = useState(null);

  const { getRootProps, getInputProps, isDragActive, isDragReject } = useDropzone({
    accept,
    multiple,
    maxFiles,
    maxSize,
    onDrop: (acceptedFiles, fileRejections) => {
      setErrorMessage(null);

      // Boyut veya format hatası alan dosyalar varsa uyar
      if (fileRejections.length > 0) {
        const firstError = fileRejections[0].errors[0];
        if (firstError.code === 'file-too-large') {
          setErrorMessage(`Dosya çok büyük! Maksimum sınır: ${(maxSize / (1024 * 1024)).toFixed(0)} MB`);
        } else if (firstError.code === 'file-invalid-type') {
          setErrorMessage('Desteklenmeyen dosya türü seçildi.');
        } else if (firstError.code === 'too-many-files') {
          setErrorMessage(`En fazla ${maxFiles} dosya seçebilirsiniz.`);
        } else {
          setErrorMessage(firstError.message);
        }
        return;
      }

      if (acceptedFiles.length > 0) {
        onFilesAdded(acceptedFiles);
      }
    },
  });

  // Kabul edilen format uzantılarını temiz bir metne çevir (örn: PDF, DOCX, PNG)
  const formatList = accept
    ? Object.values(accept).flat().map((ext) => ext.replace('.', '').toUpperCase()).join(', ')
    : null;

  return (
    <div className="flex flex-col gap-2">
      <div
        {...getRootProps()}
        className={`relative group border-2 border-dashed rounded-2xl p-7 text-center cursor-pointer transition-all duration-200 overflow-hidden select-none ${
          isDragReject
            ? 'border-rose-500 bg-rose-500/10'
            : isDragActive
            ? 'border-sky-400 bg-sky-500/10 scale-[0.99] shadow-inner'
            : 'border-slate-800/90 bg-slate-950/40 hover:border-slate-700 hover:bg-slate-900/40'
        }`}
      >
        <input {...getInputProps()} />

        {/* Arka plan hafif neon parıltısı */}
        <div className="absolute -top-12 left-1/2 -translate-x-1/2 w-40 h-16 bg-sky-500/10 blur-2xl pointer-events-none group-hover:bg-sky-500/20 transition duration-300" />

        <div className="relative flex flex-col items-center gap-3">
          {/* İkon Dairesi */}
          <div
            className={`p-3.5 rounded-2xl border transition-all duration-300 ${
              isDragReject
                ? 'bg-rose-950/50 border-rose-500/40 text-rose-400'
                : isDragActive
                ? 'bg-sky-500 text-slate-950 border-sky-400 scale-110 shadow-lg shadow-sky-500/20'
                : 'bg-slate-900/90 text-sky-400 border-slate-800 group-hover:border-slate-700 group-hover:scale-105 shadow-md'
            }`}
          >
            {isDragReject ? (
              <AlertCircle className="w-6 h-6 animate-pulse" />
            ) : isDragActive ? (
              <FileCheck2 className="w-6 h-6 animate-bounce" />
            ) : (
              <UploadCloud className="w-6 h-6" />
            )}
          </div>

          {/* Başlık ve İpuçları */}
          <div className="flex flex-col gap-1 max-w-sm">
            <p className="text-xs sm:text-sm font-semibold text-slate-200">
              {isDragReject
                ? 'Bu dosya türü desteklenmiyor!'
                : isDragActive
                ? 'Dosyayı şimdi bırakabilirsiniz...'
                : hint}
            </p>

            <span className="text-[11px] text-slate-500">
              Cihazınızdan seçmek için tıklayın veya buraya sürükleyin
            </span>
          </div>

          {/* Alt Bilgi Rozetleri */}
          <div className="flex flex-wrap items-center justify-center gap-2 pt-1">
            {formatList && (
              <span className="text-[10px] font-mono bg-slate-900 text-slate-400 border border-slate-800 px-2 py-0.5 rounded-md">
                Destek: {formatList}
              </span>
            )}
            <span className="text-[10px] font-mono bg-slate-900 text-slate-500 border border-slate-800 px-2 py-0.5 rounded-md">
              Maks: {(maxSize / (1024 * 1024)).toFixed(0)} MB
            </span>
          </div>
        </div>
      </div>

      {/* Hata Bildirim Çubuğu */}
      {errorMessage && (
        <div className="flex items-center gap-2 bg-rose-500/10 border border-rose-500/20 text-rose-400 px-3.5 py-2 rounded-xl text-xs font-medium animate-in fade-in duration-150">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span>{errorMessage}</span>
        </div>
      )}
    </div>
  );
}