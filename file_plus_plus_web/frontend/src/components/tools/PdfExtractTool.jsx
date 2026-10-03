import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  Scissors, 
  UploadCloud, 
  Check, 
  CheckSquare, 
  Square, 
  Eye, 
  RotateCcw, 
  Sparkles, 
  X,
  FileText
} from 'lucide-react';
import { extractPdfPagesApi, getPdfThumbnailsApi } from '../../services/api';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function PdfExtractTool({ setLoading }) {
  const [documents, setDocuments] = useState([]);
  const [activeDocIndex, setActiveDocIndex] = useState(0);
  const [previewModalImg, setPreviewModalImg] = useState(null);
  const { addOutput } = useOutputs();

  const resetAll = () => {
    setDocuments([]);
    setActiveDocIndex(0);
    setPreviewModalImg(null);
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'application/pdf': ['.pdf'],
      'application/x-pdf': ['.pdf'],
      'application/octet-stream': ['.pdf'],
    },
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: async (acceptedFiles, fileRejections) => {
      const validFiles = [
        ...acceptedFiles,
        ...fileRejections
          .filter(r => r.file && r.file.name && r.file.name.toLowerCase().endsWith('.pdf'))
          .map(r => r.file)
      ];

      const uniqueMap = new Map();
      for (const f of validFiles) {
        uniqueMap.set(`${f.name}_${f.size}`, f);
      }
      const allPdfs = Array.from(uniqueMap.values());

      if (allPdfs.length === 0) {
        if (fileRejections.length > 0) {
          alert('Lütfen geçerli bir .pdf dosyası seçin.');
        }
        return;
      }

      setLoading(true);
      const newDocs = [];

      for (const file of allPdfs) {
        try {
          const res = await getPdfThumbnailsApi(file);
          if (res.data && res.data.thumbnails && res.data.thumbnails.length > 0) {
            newDocs.push({
              file,
              pages: res.data.thumbnails,
              selectedPages: []
            });
          } else {
            alert(`${file.name} belgesinin sayfaları okunamadı.`);
          }
        } catch (err) {
          console.error(file.name + ' yüklenemedi:', err);
          alert(`${file.name} önizlemesi yüklenirken hata oluştu: ` + (err.response?.data?.detail || err.message));
        }
      }

      if (newDocs.length > 0) {
        setDocuments((prev) => [...prev, ...newDocs]);
      }
      setLoading(false);
    },
  });

  const activeDoc = documents[activeDocIndex];

  const togglePage = (pageNum) => {
    const num = Number(pageNum);
    setDocuments((prev) =>
      prev.map((doc, idx) => {
        if (idx !== activeDocIndex) return doc;
        const exists = doc.selectedPages.some((p) => Number(p) === num);
        const nextSelected = exists
          ? doc.selectedPages.filter((p) => Number(p) !== num)
          : [...doc.selectedPages, num].sort((a, b) => a - b);
        return {
          ...doc,
          selectedPages: nextSelected,
        };
      })
    );
  };

  const selectAll = () => {
    if (!activeDoc) return;
    setDocuments((prev) =>
      prev.map((doc, idx) => {
        if (idx !== activeDocIndex) return doc;
        const allSelected = doc.selectedPages.length === doc.pages.length;
        return {
          ...doc,
          selectedPages: allSelected
            ? []
            : doc.pages.map((p) => Number(p.page_number)),
        };
      })
    );
  };

  const selectOddPages = () => {
    if (!activeDoc) return;
    setDocuments((prev) =>
      prev.map((doc, idx) => {
        if (idx !== activeDocIndex) return doc;
        return {
          ...doc,
          selectedPages: doc.pages
            .filter((p) => Number(p.page_number) % 2 !== 0)
            .map((p) => Number(p.page_number)),
        };
      })
    );
  };

  const selectEvenPages = () => {
    if (!activeDoc) return;
    setDocuments((prev) =>
      prev.map((doc, idx) => {
        if (idx !== activeDocIndex) return doc;
        return {
          ...doc,
          selectedPages: doc.pages
            .filter((p) => Number(p.page_number) % 2 === 0)
            .map((p) => Number(p.page_number)),
        };
      })
    );
  };

  const removeDocument = (index, e) => {
    e.stopPropagation();
    setDocuments((prev) => {
      const next = prev.filter((_, i) => i !== index);
      if (activeDocIndex >= next.length) {
        setActiveDocIndex(Math.max(0, next.length - 1));
      }
      return next;
    });
  };

  const handleExtractCurrent = async () => {
    if (!activeDoc || activeDoc.selectedPages.length === 0) {
      alert('Lütfen bu belgeden en az bir sayfa seçin.');
      return;
    }

    setLoading(true);
    try {
      const pagesStr = activeDoc.selectedPages.join(',');
      const res = await extractPdfPagesApi(activeDoc.file, pagesStr);
      const blob = new Blob([res.data], { type: 'application/pdf' });
      const baseName = activeDoc.file.name.replace(/\.pdf$/i, '');
      const fileName = `${baseName}_sayfa_${pagesStr}.pdf`;

      addOutput({
        blob,
        name: fileName,
        toolSource: `PDF Ayıklayıcı (${activeDoc.selectedPages.length} Sayfa)`
      });

      setDocuments((prev) => {
        const next = [...prev];
        next[activeDocIndex].selectedPages = [];
        return next;
      });
    } catch (err) {
      alert('Hata: ' + (err.response?.data?.detail || 'Sayfalar ayıklanamadı.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col gap-5 max-w-4xl mx-auto w-full">
      <div className="flex items-start justify-between border-b border-slate-800/80 pb-4">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <Scissors className="w-5 h-5" />
            </span>
            Çoklu PDF Önizlemeli Ayıklayıcı
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Birden fazla PDF yükleyin, dilediğiniz belgeden istediğiniz sayfaları seçip ayıklayın.
          </p>
        </div>

        {documents.length > 0 && (
          <button
            onClick={resetAll}
            className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:bg-slate-800 transition"
          >
            <RotateCcw className="w-3.5 h-3.5" /> Tümünü Temizle
          </button>
        )}
      </div>

      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-2xl p-6 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-2 ${
          isDragActive
            ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
            : 'border-slate-800 hover:border-slate-700 bg-slate-900/30 hover:bg-slate-900/50'
        }`}
      >
        <input {...getInputProps()} />
        <UploadCloud className="w-6 h-6 text-sky-400" />
        <p className="text-xs font-medium text-slate-200">
          PDF dosyalarını buraya sürükleyin veya <span className="text-sky-400 underline">seçin</span>
        </p>
        <p className="text-[10px] text-slate-500">Yalnızca PDF formatı kabul edilir (Çoklu Seçim • Maks. 1024 MB)</p>
      </div>

      {documents.length > 0 && (
        <div className="flex flex-col gap-4">
          <div className="flex items-center gap-2 overflow-x-auto pb-1.5 custom-scrollbar">
            {documents.map((doc, idx) => {
              const isActive = idx === activeDocIndex;
              return (
                <div
                  key={idx}
                  onClick={() => setActiveDocIndex(idx)}
                  className={`flex items-center gap-2 px-3 py-2 rounded-xl border text-xs cursor-pointer shrink-0 transition ${
                    isActive
                      ? 'bg-sky-500/15 border-sky-500/50 text-sky-300 font-medium'
                      : 'bg-slate-950/70 border-slate-800 text-slate-400 hover:bg-slate-800/50 hover:text-slate-200'
                  }`}
                >
                  <FileText className="w-3.5 h-3.5" />
                  <span className="truncate max-w-[140px]">{doc.file.name}</span>
                  {doc.selectedPages.length > 0 && (
                    <span className="text-[10px] bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-1.5 py-0.2 rounded-full font-mono">
                      {doc.selectedPages.length}
                    </span>
                  )}
                  <button
                    type="button"
                    onClick={(e) => removeDocument(idx, e)}
                    className="hover:text-rose-400 p-0.5"
                    title="Bu Belgeyi Kaldır"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              );
            })}
          </div>

          {activeDoc && (
            <div className="flex flex-col sm:flex-row justify-between items-center bg-slate-900/80 border border-slate-800 p-2.5 rounded-2xl gap-3 backdrop-blur-md">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-xs text-slate-300 font-medium px-2">
                  Toplam: <strong className="text-sky-400">{activeDoc.pages.length}</strong> Sayfa • Seçilen: <strong className="text-emerald-400">{activeDoc.selectedPages.length}</strong>
                </span>

                <div className="flex items-center gap-1 bg-slate-950/80 p-1 rounded-xl border border-slate-800">
                  <button
                    type="button"
                    onClick={selectAll}
                    className="px-2.5 py-1 rounded-lg text-xs font-medium text-slate-300 hover:text-white hover:bg-slate-800 flex items-center gap-1.5 transition"
                  >
                    {activeDoc.selectedPages.length === activeDoc.pages.length ? (
                      <CheckSquare className="w-3.5 h-3.5 text-sky-400" />
                    ) : (
                      <Square className="w-3.5 h-3.5 text-slate-500" />
                    )}
                    {activeDoc.selectedPages.length === activeDoc.pages.length ? 'Bırak' : 'Tümü'}
                  </button>
                  <button
                    type="button"
                    onClick={selectOddPages}
                    className="px-2.5 py-1 rounded-lg text-xs font-medium text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
                  >
                    Tekler
                  </button>
                  <button
                    type="button"
                    onClick={selectEvenPages}
                    className="px-2.5 py-1 rounded-lg text-xs font-medium text-slate-400 hover:text-slate-200 hover:bg-slate-800 transition"
                  >
                    Çiftler
                  </button>
                </div>
              </div>

              <button
                type="button"
                onClick={handleExtractCurrent}
                disabled={activeDoc.selectedPages.length === 0}
                className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 disabled:opacity-40 disabled:cursor-not-allowed text-white font-medium px-5 py-2 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
              >
                <Sparkles className="w-3.5 h-3.5" />
                <span>Bu Belgeden Sayfaları Ayıkla ({activeDoc.selectedPages.length})</span>
              </button>
            </div>
          )}

          {activeDoc && (
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 max-h-[500px] overflow-y-auto p-2 bg-slate-950/60 rounded-2xl border border-slate-800/80 custom-scrollbar">
              {activeDoc.pages.map((p) => {
                const pageNum = Number(p.page_number);
                const isSelected = activeDoc.selectedPages.some((num) => Number(num) === pageNum);
                return (
                  <div
                    key={p.page_number}
                    onClick={() => togglePage(p.page_number)}
                    className={`group relative cursor-pointer rounded-xl border overflow-hidden transition-all duration-150 bg-slate-900 flex flex-col ${
                      isSelected
                        ? 'border-sky-400 ring-2 ring-sky-400/30 shadow-lg shadow-sky-500/10'
                        : 'border-slate-800/80 hover:border-slate-700 hover:scale-[1.01]'
                    }`}
                  >
                    <div className="relative aspect-[1/1.41] bg-white flex items-center justify-center overflow-hidden">
                      <img
                        src={p.image}
                        alt={`Sayfa ${p.page_number}`}
                        loading="lazy"
                        className="w-full h-full object-contain pointer-events-none select-none"
                      />

                      <button
                        type="button"
                        onClick={(e) => {
                          e.stopPropagation();
                          setPreviewModalImg(p.image);
                        }}
                        className="absolute top-2 right-2 bg-slate-950/80 hover:bg-slate-900 text-slate-200 p-1.5 rounded-lg opacity-0 group-hover:opacity-100 transition shadow backdrop-blur-sm"
                        title="Tam Boy Önizle"
                      >
                        <Eye className="w-3.5 h-3.5" />
                      </button>

                      {isSelected && (
                        <div className="absolute top-2 left-2 bg-sky-500 text-slate-950 p-1 rounded-lg shadow-md">
                          <Check className="w-3.5 h-3.5 stroke-[3]" />
                        </div>
                      )}
                    </div>

                    <div className="py-2 px-2.5 bg-slate-950 border-t border-slate-800/80 flex justify-between items-center text-[11px]">
                      <span className="text-slate-300 font-semibold font-mono">
                        Sayfa {p.page_number}
                      </span>
                      <span className={isSelected ? 'text-sky-400 font-bold' : 'text-slate-500'}>
                        {isSelected ? 'Seçildi' : 'Seç'}
                      </span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {previewModalImg && (
        <div
          onClick={() => setPreviewModalImg(null)}
          className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex justify-center items-center p-4 cursor-zoom-out animate-in fade-in duration-200"
        >
          <div className="relative max-h-[90vh] max-w-[90vw] flex flex-col items-center">
            <button
              onClick={() => setPreviewModalImg(null)}
              className="absolute -top-10 right-0 text-slate-400 hover:text-white p-1 rounded-lg transition"
            >
              <X className="w-6 h-6" />
            </button>
            <img
              src={previewModalImg}
              alt="Büyük Önizleme"
              className="max-h-[85vh] max-w-[90vw] object-contain rounded-xl shadow-2xl bg-white border border-slate-700"
            />
          </div>
        </div>
      )}
    </div>
  );
}