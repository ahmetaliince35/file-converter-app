import React, { useState, useRef, useCallback, useEffect } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  FileText, 
  UploadCloud, 
  Copy, 
  Check, 
  Scan, 
  Crop, 
  RotateCcw, 
  X,
  FileCheck
} from 'lucide-react';
import { ocrApi } from '../../services/api';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function OcrTool({ setLoading }) {
  const [file, setFile] = useState(null);
  const [imageSrc, setImageSrc] = useState(null);
  const [extractedText, setExtractedText] = useState('');
  const [copied, setCopied] = useState(false);

  const [crop, setCrop] = useState({ x: 0, y: 0, w: 0, h: 0 });
  const [isSelecting, setIsSelecting] = useState(false);
  const [startPos, setStartPos] = useState({ x: 0, y: 0 });

  const imageRef = useRef(null);
  const { addOutput } = useOutputs();

  const resetAll = () => {
    if (imageSrc) URL.revokeObjectURL(imageSrc);
    setFile(null);
    setImageSrc(null);
    setExtractedText('');
    setCrop({ x: 0, y: 0, w: 0, h: 0 });
  };

  useEffect(() => {
    return () => {
      if (imageSrc) URL.revokeObjectURL(imageSrc);
    };
  }, [imageSrc]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'image/*': ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.heic', '.heif']
    },
    maxFiles: 1,
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isMultiple = fileRejections.some(r => r.errors.some(e => e.code === 'too-many-files'));
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isMultiple) {
          alert('OCR Aracı tek seferde yalnızca 1 görsel işleyebilir.');
          return;
        }
        if (isSizeErr) {
          alert('Görsel boyutu 1024 MB sınırını aşıyor.');
          return;
        }
        if (isTypeErr) {
          alert('Lütfen geçerli bir görsel formatı seçin (.jpg, .png, .webp, .bmp vb.).');
          return;
        }
      }

      if (acceptedFiles[0]) {
        const cur = acceptedFiles[0];

        if (imageSrc) URL.revokeObjectURL(imageSrc);
        setFile(cur);
        setImageSrc(URL.createObjectURL(cur));
        setExtractedText('');
        setCrop({ x: 0, y: 0, w: 0, h: 0 });
      }
    },
  });

  const getRelativeCoords = useCallback((clientX, clientY) => {
    const img = imageRef.current;
    if (!img) return { x: 0, y: 0, width: 0, height: 0 };
    const rect = img.getBoundingClientRect();
    const x = Math.max(0, Math.min(clientX - rect.left, rect.width));
    const y = Math.max(0, Math.min(clientY - rect.top, rect.height));
    return { x, y, width: rect.width, height: rect.height };
  }, []);

  const handlePointerDown = (clientX, clientY) => {
    const coords = getRelativeCoords(clientX, clientY);
    setStartPos({ x: coords.x, y: coords.y });
    setCrop({ x: coords.x, y: coords.y, w: 0, h: 0 });
    setIsSelecting(true);
  };

  const handlePointerMove = (clientX, clientY) => {
    if (!isSelecting) return;
    const coords = getRelativeCoords(clientX, clientY);

    const x = Math.min(startPos.x, coords.x);
    const y = Math.min(startPos.y, coords.y);
    const w = Math.abs(coords.x - startPos.x);
    const h = Math.abs(coords.y - startPos.y);

    setCrop({ x, y, w, h });
  };

  const handlePointerUp = () => setIsSelecting(false);

  const handleRunOcr = async () => {
    if (!file || !imageRef.current) return;
    setLoading(true);

    try {
      const img = imageRef.current;
      const scaleX = img.naturalWidth / img.clientWidth;
      const scaleY = img.naturalHeight / img.clientHeight;

      const hasSelection = crop.w > 12 && crop.h > 12;
      let realX = hasSelection ? crop.x * scaleX : 0;
      let realY = hasSelection ? crop.y * scaleY : 0;
      let realW = hasSelection ? crop.w * scaleX : img.naturalWidth;
      let realH = hasSelection ? crop.h * scaleY : img.naturalHeight;

      const MAX_DIM = 2400;
      let outW = realW;
      let outH = realH;
      if (outW > MAX_DIM || outH > MAX_DIM) {
        const ratio = outW / outH;
        if (ratio > 1) {
          outW = MAX_DIM;
          outH = Math.round(MAX_DIM / ratio);
        } else {
          outH = MAX_DIM;
          outW = Math.round(MAX_DIM * ratio);
        }
      }

      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, outW);
      canvas.height = Math.max(1, outH);
      const ctx = canvas.getContext('2d');

      ctx.drawImage(img, realX, realY, realW, realH, 0, 0, outW, outH);

      canvas.toBlob(async (blob) => {
        canvas.width = 0;
        canvas.height = 0;

        try {
          const croppedFile = new File([blob], 'selected_area.jpg', { type: 'image/jpeg' });
          const res = await ocrApi(croppedFile);
          setExtractedText(res.data.text || 'Bu alanda okunabilir metin bulunamadı.');
        } catch (apiErr) {
          alert('Hata: ' + (apiErr.response?.data?.detail || apiErr.message));
        } finally {
          setLoading(false);
        }
      }, 'image/jpeg', 0.90);
    } catch (err) {
      alert('İşlem hatası: ' + err.message);
      setLoading(false);
    }
  };

  const copyToClipboard = () => {
    if (!extractedText) return;
    navigator.clipboard.writeText(extractedText);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleSaveToDock = () => {
    if (!extractedText.trim()) return;
    const blob = new Blob([extractedText], { type: 'text/plain;charset=utf-8' });
    const baseName = file?.name?.substring(0, file.name.lastIndexOf('.')) || 'ocr_metin';
    const outputName = `${baseName}_ocr.txt`;

    addOutput({
      blob,
      name: outputName,
      toolSource: 'Hassas OCR (Metin Çıkarıcı)'
    });
  };

  const wordCount = extractedText.trim() ? extractedText.trim().split(/\s+/).length : 0;

  return (
    <div className="flex flex-col gap-5 max-w-4xl mx-auto w-full select-none">
      <div className="flex items-start justify-between border-b border-slate-800/80 pb-4">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <FileText className="w-5 h-5" />
            </span>
            Hassas Bölgesel OCR
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Görsel üzerinden fareyle seçim yaparak yalnızca istediğiniz bölümün metnini ayrıştırın.
          </p>
        </div>

        {file && (
          <button
            onClick={resetAll}
            className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:bg-slate-800 transition"
          >
            <RotateCcw className="w-3.5 h-3.5" /> Yeni Görsel
          </button>
        )}
      </div>

      {!imageSrc ? (
        <div
          {...getRootProps()}
          className={`border-2 border-dashed rounded-2xl p-10 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-3 ${
            isDragActive
              ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
              : 'border-slate-800 hover:border-slate-700 bg-slate-900/30 hover:bg-slate-900/50'
          }`}
        >
          <input {...getInputProps()} />
          <div className="p-3.5 rounded-full bg-slate-800/80 border border-slate-700/50 text-sky-400 shadow-inner">
            <UploadCloud className="w-7 h-7" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-200">
              OCR yapılacak görseli buraya sürükleyin veya <span className="text-sky-400 underline underline-offset-2">seçin</span>
            </p>
            <p className="text-[11px] text-slate-500 mt-1">JPG, JPEG, PNG, WEBP, BMP (Tek Görsel • Maks. 1024 MB)</p>
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row justify-between items-center bg-slate-900/80 border border-slate-800 p-2.5 rounded-2xl gap-3 backdrop-blur-md">
            <div className="flex items-center gap-2 text-xs">
              <span className="p-1.5 rounded-lg bg-slate-800 text-sky-400 border border-slate-700/60">
                <Crop className="w-4 h-4" />
              </span>
              <span className="text-slate-300 font-medium">
                {crop.w > 12 && crop.h > 12 ? (
                  <span className="text-sky-400">Bölge Seçildi ({Math.round(crop.w)}x{Math.round(crop.h)}px)</span>
                ) : (
                  'Tüm Görsel Seçili'
                )}
              </span>
              {crop.w > 12 && crop.h > 12 && (
                <button
                  type="button"
                  onClick={() => setCrop({ x: 0, y: 0, w: 0, h: 0 })}
                  className="text-[11px] text-slate-400 hover:text-rose-400 flex items-center gap-1 ml-1 px-2 py-0.5 rounded bg-slate-800/60 transition"
                >
                  <X className="w-3 h-3" /> Sıfırla
                </button>
              )}
            </div>

            <button
              type="button"
              onClick={handleRunOcr}
              className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-medium px-5 py-2 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
            >
              <Scan className="w-4 h-4" />
              <span>{crop.w > 12 && crop.h > 12 ? 'Seçili Bölgeyi Oku' : 'Tüm Resmi Çözümle'}</span>
            </button>
          </div>

          <div className="relative border border-slate-800 rounded-2xl overflow-hidden bg-slate-950/80 flex justify-center items-center p-3 shadow-2xl">
            <div
              className="relative inline-block cursor-crosshair leading-none touch-none"
              onMouseDown={(e) => handlePointerDown(e.clientX, e.clientY)}
              onMouseMove={(e) => handlePointerMove(e.clientX, e.clientY)}
              onMouseUp={handlePointerUp}
              onTouchStart={(e) => {
                const touch = e.touches[0];
                handlePointerDown(touch.clientX, touch.clientY);
              }}
              onTouchMove={(e) => {
                const touch = e.touches[0];
                handlePointerMove(touch.clientX, touch.clientY);
              }}
              onTouchEnd={handlePointerUp}
            >
              <img
                ref={imageRef}
                src={imageSrc}
                alt="OCR Hedefi"
                draggable={false}
                className="max-h-[500px] w-auto block select-none rounded-lg"
              />

              {crop.w > 8 && crop.h > 8 && (
                <div
                  className="absolute border-2 border-sky-400 bg-sky-500/10 pointer-events-none rounded-sm transition-all"
                  style={{
                    left: `${crop.x}px`,
                    top: `${crop.y}px`,
                    width: `${crop.w}px`,
                    height: `${crop.h}px`,
                    boxShadow: '0 0 0 9999px rgba(2, 6, 23, 0.55)',
                  }}
                >
                  <span className="absolute -top-1 -left-1 w-2.5 h-2.5 border-t-2 border-l-2 border-white pointer-events-none" />
                  <span className="absolute -top-1 -right-1 w-2.5 h-2.5 border-t-2 border-r-2 border-white pointer-events-none" />
                  <span className="absolute -bottom-1 -left-1 w-2.5 h-2.5 border-b-2 border-l-2 border-white pointer-events-none" />
                  <span className="absolute -bottom-1 -right-1 w-2.5 h-2.5 border-b-2 border-r-2 border-white pointer-events-none" />
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {extractedText && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3 shadow-xl backdrop-blur-sm animate-in fade-in duration-200">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
            <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
              <FileCheck className="w-4 h-4 text-emerald-400" /> Çıkarılan Metin
            </span>
            <div className="flex items-center gap-3">
              <span className="text-[11px] text-slate-500 font-mono">
                {wordCount} kelime • {extractedText.length} karakter
              </span>
              <button
                type="button"
                onClick={copyToClipboard}
                className="text-xs text-sky-400 hover:text-sky-300 flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-sky-500/10 border border-sky-500/20 transition"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? 'Kopyalandı' : 'Kopyala'}</span>
              </button>
            </div>
          </div>

          <textarea
            value={extractedText}
            onChange={(e) => setExtractedText(e.target.value)}
            rows={7}
            className="w-full bg-slate-950/90 text-slate-200 font-sans text-xs p-3.5 rounded-xl border border-slate-800 focus:border-sky-500/50 focus:ring-1 focus:ring-sky-500/50 outline-none leading-relaxed resize-y transition shadow-inner"
          />

          <div className="flex justify-end pt-1">
            <button
              type="button"
              onClick={handleSaveToDock}
              className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-semibold px-4 py-2 rounded-xl text-xs flex items-center gap-2 shadow-lg shadow-emerald-500/20 active:scale-[0.99] transition duration-150"
            >
              <FileCheck className="w-4 h-4" /> Çıktı Havuzuna TXT Olarak Ekle
            </button>
          </div>
        </div>
      )}
    </div>
  );
}