import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import FileQueue from '../FileQueue';
import { LayoutGrid, Layers, FileCheck, UploadCloud } from 'lucide-react';
import { jsPDF } from 'jspdf';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function ImagesToPdfTool({ setLoading }) {
  const [files, setFiles] = useState([]);
  const [matrix, setMatrix] = useState('1x1');
  const { addOutput } = useOutputs();

  const matrixOptions = [
    { id: '1x1', title: '1x1', desc: 'Tek Resim (Tam A4)', cols: 1, rows: 1 },
    { id: '2x1', title: '2x1', desc: '2 Resim (Alt Alta)', cols: 1, rows: 2 },
    { id: '2x2', title: '2x2', desc: '4 Resim (2x2 Izgara)', cols: 2, rows: 2 },
    { id: '3x2', title: '3x2', desc: '6 Resim (Tablo)', cols: 2, rows: 3 },
  ];

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'image/*': ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.heic', '.heif']
    },
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isSizeErr) alert('1024 MB sınırını aşan görseller atlandı.');
        if (isTypeErr) alert('Lütfen yalnızca resim formatları (.jpg, .png, .webp, .bmp vb.) yükleyin.');
      }

      if (acceptedFiles.length > 0) {
        setFiles((prev) => [...prev, ...acceptedFiles]);
      }
    },
  });

  const processImageNative = async (file) => {
    let bitmap;
    try {
      bitmap = await createImageBitmap(file);
    } catch {
      return new Promise((resolve) => {
        const url = URL.createObjectURL(file);
        const img = new Image();
        img.src = url;
        img.onload = () => {
          URL.revokeObjectURL(url);
          resolve({ dataUrl: img.src, width: img.naturalWidth, height: img.naturalHeight });
        };
      });
    }

    const MAX_DIM = 2000;
    let w = bitmap.width;
    let h = bitmap.height;

    if (w > MAX_DIM || h > MAX_DIM) {
      if (w / h > 1) {
        h = Math.round((h * MAX_DIM) / w);
        w = MAX_DIM;
      } else {
        w = Math.round((w * MAX_DIM) / h);
        h = MAX_DIM;
      }
    }

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(bitmap, 0, 0, w, h);
    bitmap.close();

    const dataUrl = canvas.toDataURL('image/jpeg', 0.82);
    canvas.width = 0;
    canvas.height = 0;

    return { dataUrl, width: w, height: h };
  };

  const handleGeneratePdf = async () => {
    if (files.length === 0) return;
    setLoading(true);

    try {
      const selected = matrixOptions.find((m) => m.id === matrix) || matrixOptions[0];
      const { cols, rows } = selected;
      const perPage = cols * rows;

      const doc = new jsPDF({ orientation: 'p', unit: 'mm', format: 'a4', compress: true });
      const a4Width = 210;
      const a4Height = 297;
      const margin = 10;
      const usableW = a4Width - margin * 2;
      const usableH = a4Height - margin * 2;
      const cellW = usableW / cols;
      const cellH = usableH / rows;

      for (let i = 0; i < files.length; i++) {
        if (i > 0 && i % perPage === 0) {
          doc.addPage();
        }

        const slotIndex = i % perPage;
        const col = slotIndex % cols;
        const row = Math.floor(slotIndex / cols);
        const cellX = margin + col * cellW;
        const cellY = margin + row * cellH;

        const { dataUrl, width: imgW, height: imgH } = await processImageNative(files[i]);

        const padding = 2.5;
        const maxW = cellW - padding * 2;
        const maxH = cellH - padding * 2;
        const imgRatio = imgW / imgH;
        const boxRatio = maxW / maxH;

        let renderW = maxW;
        let renderH = maxH;

        if (imgRatio > boxRatio) {
          renderH = maxW / imgRatio;
        } else {
          renderW = maxH * imgRatio;
        }

        const posX = cellX + padding + (maxW - renderW) / 2;
        const posY = cellY + padding + (maxH - renderH) / 2;

        doc.addImage(dataUrl, 'JPEG', posX, posY, renderW, renderH, undefined, 'FAST');

        await new Promise((r) => setTimeout(r, 20));
      }

      const blob = doc.output('blob');
      const fileName = `Galeri_${matrix}_${Date.now()}.pdf`;

      addOutput({
        blob,
        name: fileName,
        toolSource: `Resimden PDF (${matrix})`
      });

      setFiles([]);
    } catch (err) {
      alert('PDF oluşturulurken hata: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const selectedMatrix = matrixOptions.find((m) => m.id === matrix) || matrixOptions[0];
  const itemsPerPage = selectedMatrix.cols * selectedMatrix.rows;
  const estimatedPages = files.length > 0 ? Math.ceil(files.length / itemsPerPage) : 0;

  return (
    <div className="flex flex-col gap-5 max-w-3xl mx-auto w-full">
      <div className="flex items-start justify-between border-b border-slate-800/80 pb-4">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <LayoutGrid className="w-5 h-5" />
            </span>
            A4 Resim Yerleşim Matrisi
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Görselleri oranlarını koruyarak A4 sayfalarına sırayla yerleştirin.
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-2">
        <label className="text-xs font-medium text-slate-400 flex items-center justify-between">
          <span className="flex items-center gap-1.5">
            <Layers className="w-3.5 h-3.5 text-sky-400" /> Yerleşim Şablonu
          </span>
          {files.length > 0 && (
            <span className="text-[11px] text-sky-400 font-mono flex items-center gap-1">
              <FileCheck className="w-3.5 h-3.5" />
              Tahmini: {estimatedPages} Sayfa ({files.length} Görsel)
            </span>
          )}
        </label>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
          {matrixOptions.map((opt) => {
            const isSelected = matrix === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setMatrix(opt.id)}
                className={`p-3 rounded-xl border flex flex-col items-center gap-2 transition-all duration-150 ${
                  isSelected
                    ? 'bg-sky-500/10 border-sky-500 text-sky-400 shadow-md shadow-sky-500/10'
                    : 'bg-slate-900/50 border-slate-800 text-slate-400 hover:bg-slate-800/60 hover:text-slate-200 hover:border-slate-700'
                }`}
              >
                <div
                  className={`w-9 h-12 rounded border p-0.5 grid gap-0.5 transition ${
                    isSelected ? 'border-sky-400 bg-slate-950' : 'border-slate-700 bg-slate-950/70'
                  }`}
                  style={{
                    gridTemplateColumns: `repeat(${opt.cols}, minmax(0, 1fr))`,
                    gridTemplateRows: `repeat(${opt.rows}, minmax(0, 1fr))`
                  }}
                >
                  {Array.from({ length: opt.cols * opt.rows }).map((_, i) => (
                    <div
                      key={i}
                      className={`rounded-[1px] ${
                        isSelected ? 'bg-sky-500/40' : 'bg-slate-800'
                      }`}
                    />
                  ))}
                </div>

                <div className="text-center">
                  <div className={`text-xs font-semibold ${isSelected ? 'text-white' : 'text-slate-300'}`}>
                    {opt.title}
                  </div>
                  <div className="text-[10px] text-slate-500 mt-0.5 line-clamp-1">
                    {opt.desc}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
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
            Resimleri buraya sürükleyin veya <span className="text-sky-400 underline">seçin</span>
          </p>
          <p className="text-[11px] text-slate-500 mt-1">
            JPG, PNG, WEBP, BMP (Çoklu Seçim • Maks. 1024 MB)
          </p>
        </div>
      </div>

      {files.length > 0 && (
        <FileQueue
          files={files}
          onRemove={(i) => setFiles((p) => p.filter((_, idx) => idx !== i))}
          onClear={() => setFiles([])}
          availableFormats={['pdf']}
          onConvert={handleGeneratePdf}
          btnText={`A4 PDF Oluştur (${matrix})`}
        />
      )}
    </div>
  );
}