import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  FileSpreadsheet, 
  UploadCloud, 
  Sparkles, 
  FileText, 
  Presentation, 
  Cloud, 
  HardDrive, 
  ArrowRight, 
  ShieldCheck, 
  Trash2, 
  Loader2, 
  RotateCcw 
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { convertWithMicrosoft, convertWithGoogle } from '../../services/cloudEngines';
import { convertBatchApi } from '../../services/api';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function OfficeToPdfTool({ setLoading }) {
  const { provider, token } = useAuth();
  const [files, setFiles] = useState([]);
  const [processingIndex, setProcessingIndex] = useState(-1);
  const [statusText, setStatusText] = useState('');
  const { addOutput } = useOutputs();

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document': ['.docx'],
      'application/msword': ['.doc'],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': ['.xlsx'],
      'application/vnd.ms-excel': ['.xls'],
      'application/vnd.openxmlformats-officedocument.presentationml.presentation': ['.pptx'],
      'application/vnd.ms-powerpoint': ['.ppt']
    },
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isSizeErr) alert('1024 MB sınırını aşan ofis belgeleri atlandı.');
        if (isTypeErr) alert('Lütfen yalnızca Word (.docx), Excel (.xlsx) veya PowerPoint (.pptx) belgeleri yükleyin.');
      }

      if (acceptedFiles.length > 0) {
        setFiles((prev) => [...prev, ...acceptedFiles]);
      }
    },
  });

  const handleConvertBatch = async () => {
    if (files.length === 0) return;
    setLoading(true);

    try {
      for (let i = 0; i < files.length; i++) {
        setProcessingIndex(i);
        const currentFile = files[i];
        setStatusText(`${currentFile.name} dönüştürülüyor... (${i + 1}/${files.length})`);

        let pdfBlob;
        if (provider === 'microsoft') {
          pdfBlob = await convertWithMicrosoft(currentFile, token);
        } else if (provider === 'google') {
          pdfBlob = await convertWithGoogle(currentFile, token);
        } else {
          const res = await convertBatchApi([currentFile], 'pdf');
          pdfBlob = new Blob([res.data], { type: 'application/pdf' });
        }

        const fileName = `${currentFile.name.substring(0, currentFile.name.lastIndexOf('.')) || currentFile.name}.pdf`;

        addOutput({
          blob: pdfBlob,
          name: fileName,
          toolSource: provider ? `${provider.toUpperCase()} Çevirici` : 'Ofis Çevirici'
        });

        await new Promise((r) => setTimeout(r, 60));
      }

      setFiles([]);
    } catch (err) {
      alert("Hata: " + (err.message || "Dönüştürme işlemi sırasında bir hata oluştu."));
    } finally {
      setLoading(false);
      setProcessingIndex(-1);
      setStatusText('');
    }
  };

  const getDocTypeDetails = (fileName) => {
    const ext = fileName?.split('.').pop()?.toLowerCase();
    switch (ext) {
      case 'docx':
      case 'doc':
        return {
          icon: FileText,
          label: 'WORD',
          badgeClass: 'text-blue-400 bg-blue-500/10 border-blue-500/20'
        };
      case 'xlsx':
      case 'xls':
        return {
          icon: FileSpreadsheet,
          label: 'EXCEL',
          badgeClass: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20'
        };
      case 'pptx':
      case 'ppt':
        return {
          icon: Presentation,
          label: 'POWERPOINT',
          badgeClass: 'text-amber-400 bg-amber-500/10 border-amber-500/20'
        };
      default:
        return {
          icon: FileText,
          label: 'OFİS',
          badgeClass: 'text-sky-400 bg-sky-500/10 border-sky-500/20'
        };
    }
  };

  const totalSizeMB = (
    files.reduce((acc, f) => acc + f.size, 0) / (1024 * 1024)
  ).toFixed(2);

  return (
    <div className="flex flex-col gap-5 max-w-3xl mx-auto w-full">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between border-b border-slate-800/80 pb-4 gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <FileSpreadsheet className="w-5 h-5" />
            </span>
            Çoklu Ofis Belgelerini PDF'e Dönüştür
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Word, Excel ve PowerPoint dosyalarını sırayla mizanpajı bozulmadan PDF'e aktarın.
          </p>
        </div>

        <div className="flex items-center gap-1.5 self-start sm:self-auto px-2.5 py-1 rounded-full border text-[11px] font-medium bg-slate-900/90 border-slate-800">
          {provider ? (
            <>
              <Cloud className="w-3.5 h-3.5 text-sky-400" />
              <span className="text-slate-300 capitalize">{provider} Cloud Motoru</span>
            </>
          ) : (
            <>
              <HardDrive className="w-3.5 h-3.5 text-slate-400" />
              <span className="text-slate-400">Yerel Motor (Misafir)</span>
            </>
          )}
        </div>
      </div>

      {!provider && (
        <div className="flex items-center gap-2.5 px-3 py-2 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-300 text-xs">
          <ShieldCheck className="w-4 h-4 shrink-0 text-amber-400" />
          <span>En yüksek dönüştürme kalitesi için Microsoft veya Google hesabınızla giriş yapabilirsiniz.</span>
        </div>
      )}

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
            Ofis belgelerini buraya sürükleyin veya <span className="text-sky-400 underline">seçin</span>
          </p>
          <p className="text-[11px] text-slate-500 mt-1">
            DOCX, XLSX, PPTX (Çoklu Seçim • Maks. 1024 MB)
          </p>
        </div>
      </div>

      {files.length > 0 && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3.5 shadow-xl backdrop-blur-sm animate-in fade-in duration-200">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-slate-200">
                Kuyruktaki Belgeler ({files.length})
              </span>
              <span className="text-[11px] font-mono text-slate-500">
                • {totalSizeMB} MB
              </span>
            </div>
            <button
              onClick={() => setFiles([])}
              className="text-xs text-slate-400 hover:text-rose-400 transition flex items-center gap-1"
            >
              <RotateCcw className="w-3 h-3" /> Listeyi Temizle
            </button>
          </div>

          <div className="max-h-60 overflow-y-auto flex flex-col gap-2 pr-1 custom-scrollbar">
            {files.map((file, idx) => {
              const details = getDocTypeDetails(file.name);
              const DocIcon = details.icon;
              const isCurrent = processingIndex === idx;

              return (
                <div
                  key={`${file.name}-${idx}`}
                  className={`flex items-center justify-between px-3 py-2.5 rounded-xl border transition ${
                    isCurrent
                      ? 'bg-sky-500/10 border-sky-500/40'
                      : 'bg-slate-950/70 border-slate-800/80'
                  }`}
                >
                  <div className="flex items-center gap-2.5 truncate">
                    <span className={`p-1.5 rounded-lg border shrink-0 ${details.badgeClass}`}>
                      <DocIcon className="w-4 h-4" />
                    </span>
                    <span className={`text-[10px] font-mono font-bold px-1.5 py-0.5 rounded border ${details.badgeClass}`}>
                      {details.label}
                    </span>
                    <span className="text-xs text-slate-200 truncate max-w-[240px] sm:max-w-md">
                      {file.name}
                    </span>
                    <span className="text-[10px] text-slate-500 font-mono hidden sm:inline">
                      ({(file.size / (1024 * 1024)).toFixed(2)} MB)
                    </span>
                    {isCurrent && (
                      <span className="text-[10px] text-sky-400 flex items-center gap-1 ml-2 font-medium">
                        <Loader2 className="w-3 h-3 animate-spin" /> Dönüştürülüyor
                      </span>
                    )}
                  </div>

                  <button
                    onClick={() => setFiles((p) => p.filter((_, i) => i !== idx))}
                    className="p-1 rounded-md text-slate-500 hover:text-rose-400 hover:bg-rose-500/10 transition"
                    title="Kaldır"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              );
            })}
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-between border-t border-slate-800/80 pt-3 gap-3">
            <span className="text-xs text-slate-400">
              {statusText || `${files.length} belge sırayla PDF formatına aktarılacak.`}
            </span>

            <button
              type="button"
              onClick={handleConvertBatch}
              className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-medium px-5 py-2.5 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
            >
              <Sparkles className="w-4 h-4" />
              <span>
                {provider
                  ? `${provider.toUpperCase()} ile Sırayla Çevir (${files.length})`
                  : `Yerel Motorla Sırayla Çevir (${files.length})`}
              </span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}