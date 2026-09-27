import React, { useState, useRef, useEffect, useCallback } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  ScanLine, 
  UploadCloud, 
  Sparkles, 
  Wand2, 
  FileText, 
  Image as ImageIcon, 
  RotateCcw, 
  CheckCircle2, 
  Layers 
} from 'lucide-react';
import { detectCornersApi, camScannerApi } from '../../services/api';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function CamScannerTool({ setLoading }) {
  const [file, setFile] = useState(null);
  const [imageSrc, setImageSrc] = useState(null);
  const [points, setPoints] = useState([]);
  const [activePoint, setActivePoint] = useState(null);
  const [scannedPreviewUrl, setScannedPreviewUrl] = useState(null);
  const [filterMode, setFilterMode] = useState('magic');
  const [naturalDimensions, setNaturalDimensions] = useState({ width: 1, height: 1 });
  const { addOutput } = useOutputs();

  const canvasRef = useRef(null);
  const imageRef = useRef(new Image());

  const resetAll = () => {
    if (imageSrc) URL.revokeObjectURL(imageSrc);
    if (scannedPreviewUrl) URL.revokeObjectURL(scannedPreviewUrl);
    setFile(null);
    setImageSrc(null);
    setPoints([]);
    setScannedPreviewUrl(null);
    setActivePoint(null);
  };

  useEffect(() => {
    return () => {
      if (imageSrc) URL.revokeObjectURL(imageSrc);
      if (scannedPreviewUrl) URL.revokeObjectURL(scannedPreviewUrl);
    };
  }, [imageSrc, scannedPreviewUrl]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'image/*': ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.tiff', '.tif', '.heic', '.heif']
    },
    maxFiles: 1,
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: async (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isMultiple = fileRejections.some(r => r.errors.some(e => e.code === 'too-many-files'));
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isMultiple) {
          alert('CamScanner tek seferde yalnızca 1 belge görseli tarayabilir.');
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
        const currentFile = acceptedFiles[0];

        if (imageSrc) URL.revokeObjectURL(imageSrc);
        if (scannedPreviewUrl) URL.revokeObjectURL(scannedPreviewUrl);

        setFile(currentFile);
        const url = URL.createObjectURL(currentFile);
        setImageSrc(url);
        setScannedPreviewUrl(null);

        const img = imageRef.current;
        img.src = url;
        img.onload = async () => {
          const nw = img.naturalWidth || 1;
          const nh = img.naturalHeight || 1;
          setNaturalDimensions({ width: nw, height: nh });

          setLoading(true);
          try {
            const res = await detectCornersApi(currentFile);
            const returnedPoints = res.data?.points;

            // Backend [[x, y], ...] dizisi döner; React için {x, y} formatına çeviriyoruz
            if (Array.isArray(returnedPoints) && returnedPoints.length === 4) {
              setPoints(
                returnedPoints.map((pt) => 
                  Array.isArray(pt) ? { x: pt[0], y: pt[1] } : { x: pt.x, y: pt.y }
                )
              );
            } else {
              throw new Error("Köşe formatı geçersiz");
            }
          } catch {
            // Algılama başarısız olursa güvenli varsayılan sınırlar
            setPoints([
              { x: nw * 0.08, y: nh * 0.08 },
              { x: nw * 0.92, y: nh * 0.08 },
              { x: nw * 0.92, y: nh * 0.92 },
              { x: nw * 0.08, y: nh * 0.92 }
            ]);
          } finally {
            setLoading(false);
          }
        };
      }
    }
  });

  // Canvas üzerinde görseli ve ayarlanabilir köşe noktalarını çizme
  useEffect(() => {
    if (!imageSrc || points.length !== 4) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const img = imageRef.current;

    const MAX_CANVAS_DIM = 2000;
    let targetW = naturalDimensions.width;
    let targetH = naturalDimensions.height;

    if (targetW > MAX_CANVAS_DIM || targetH > MAX_CANVAS_DIM) {
      const ratio = targetW / targetH;
      if (ratio > 1) {
        targetW = MAX_CANVAS_DIM;
        targetH = Math.round(MAX_CANVAS_DIM / ratio);
      } else {
        targetH = MAX_CANVAS_DIM;
        targetW = Math.round(MAX_CANVAS_DIM * ratio);
      }
    }

    canvas.width = targetW;
    canvas.height = targetH;

    const scaleX = targetW / naturalDimensions.width;
    const scaleY = targetH / naturalDimensions.height;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(img, 0, 0, targetW, targetH);

    // Dörtgen çerçeve çizgileri
    ctx.beginPath();
    ctx.moveTo(points[0].x * scaleX, points[0].y * scaleY);
    for (let i = 1; i < 4; i++) {
      ctx.lineTo(points[i].x * scaleX, points[i].y * scaleY);
    }
    ctx.closePath();

    ctx.lineWidth = Math.max(3, targetW * 0.003);
    ctx.strokeStyle = '#38bdf8';
    ctx.stroke();

    ctx.fillStyle = 'rgba(56, 189, 248, 0.18)';
    ctx.fill();

    // 4 köşe kontrol tutamaçları
    const radius = Math.max(12, targetW * 0.012);
    points.forEach((pt, index) => {
      const px = pt.x * scaleX;
      const py = pt.y * scaleY;

      ctx.beginPath();
      ctx.arc(px, py, radius, 0, 2 * Math.PI);
      ctx.fillStyle = activePoint === index ? '#38bdf8' : '#0284c7';
      ctx.fill();
      ctx.lineWidth = 2.5;
      ctx.strokeStyle = '#ffffff';
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(px, py, radius * 0.35, 0, 2 * Math.PI);
      ctx.fillStyle = '#ffffff';
      ctx.fill();
    });
  }, [imageSrc, points, activePoint, naturalDimensions]);

  const getCanvasCoords = useCallback((clientX, clientY) => {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    const scaleX = naturalDimensions.width / rect.width;
    const scaleY = naturalDimensions.height / rect.height;
    return {
      x: (clientX - rect.left) * scaleX,
      y: (clientY - rect.top) * scaleY
    };
  }, [naturalDimensions]);

  const handlePointerDown = (clientX, clientY) => {
    const canvas = canvasRef.current;
    if (!canvas || points.length !== 4) return;
    const { x, y } = getCanvasCoords(clientX, clientY);

    // Ekranda tıklanan yerin piksel toleransı (yüksek çözünürlüklerde tıklamayı kolaylaştırır)
    const rect = canvas.getBoundingClientRect();
    const threshold = (naturalDimensions.width / rect.width) * 36;

    let closestIdx = null;
    let minDistance = Infinity;

    points.forEach((pt, idx) => {
      const dist = Math.hypot(pt.x - x, pt.y - y);
      if (dist < threshold && dist < minDistance) {
        minDistance = dist;
        closestIdx = idx;
      }
    });

    if (closestIdx !== null) {
      setActivePoint(closestIdx);
    }
  };

  const handlePointerMove = (clientX, clientY) => {
    if (activePoint === null) return;
    const { x, y } = getCanvasCoords(clientX, clientY);
    setPoints((prev) => {
      const next = [...prev];
      next[activePoint] = { 
        x: Math.max(0, Math.min(x, naturalDimensions.width)), 
        y: Math.max(0, Math.min(y, naturalDimensions.height)) 
      };
      return next;
    });
  };

  const handlePointerUp = () => setActivePoint(null);

  const handleScan = async (selectedFilter = filterMode) => {
    if (!file || points.length !== 4) return;
    setLoading(true);
    try {
      // Backend OpenCV formatına uygun [[x, y], ...] listesi oluşturulur
      const rawPoints = points.map((p) => [Math.round(p.x), Math.round(p.y)]);
      const res = await camScannerApi(file, rawPoints, selectedFilter);

      // Gelen Blob'u tarayıcıda görselleştirelim
      const blob = new Blob([res.data], { type: 'image/jpeg' });
      const fileName = `Taranmis_${file.name.substring(0, file.name.lastIndexOf('.')) || 'belge'}.jpg`;

      if (scannedPreviewUrl) URL.revokeObjectURL(scannedPreviewUrl);
      const previewUrl = URL.createObjectURL(blob);
      setScannedPreviewUrl(previewUrl);

      addOutput({
        blob,
        name: fileName,
        toolSource: 'CamScanner'
      });
    } catch (err) {
      let errorMessage = "İşlem gerçekleştirilemedi.";
      if (err.response?.data instanceof Blob) {
        // Blob olarak dönen 400/500 JSON hatasını okur
        const text = await err.response.data.text();
        try {
          const parsed = JSON.parse(text);
          errorMessage = parsed.detail || errorMessage;
        } catch {
          errorMessage = text || errorMessage;
        }
      } else if (err.response?.data?.detail) {
        errorMessage = err.response.data.detail;
      }
      alert("Hata: " + errorMessage);
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
              <ScanLine className="w-5 h-5" />
            </span>
            Akıllı Belge Tarayıcı (CamScanner)
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Perspektif ve gölge düzeltmeli belge tarayıcı.
          </p>
        </div>

        {file && (
          <button
            onClick={resetAll}
            className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 hover:bg-slate-800 transition"
          >
            <RotateCcw className="w-3.5 h-3.5" /> Yeni Belge
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
              Taranacak belgeyi sürükleyin veya <span className="text-sky-400 underline underline-offset-2">seçin</span>
            </p>
            <p className="text-[11px] text-slate-500 mt-1">JPG, JPEG, PNG, WEBP, BMP (Tek Görsel • Maks. 1024 MB)</p>
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          <div className="flex flex-col sm:flex-row justify-between items-center bg-slate-900/80 border border-slate-800 p-2.5 rounded-2xl gap-3 backdrop-blur-md">
            <div className="flex items-center p-1 bg-slate-950/80 rounded-xl border border-slate-800/80 w-full sm:w-auto">
              <button
                type="button"
                onClick={() => { setFilterMode('magic'); handleScan('magic'); }}
                className={`flex-1 sm:flex-none px-3.5 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-2 transition duration-150 ${
                  filterMode === 'magic'
                    ? 'bg-sky-500 text-slate-950 shadow-md font-semibold'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                <Wand2 className="w-3.5 h-3.5" /> Büyülü Renk
              </button>
              <button
                type="button"
                onClick={() => { setFilterMode('bw'); handleScan('bw'); }}
                className={`flex-1 sm:flex-none px-3.5 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-2 transition duration-150 ${
                  filterMode === 'bw'
                    ? 'bg-sky-500 text-slate-950 shadow-md font-semibold'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                <FileText className="w-3.5 h-3.5" /> Siyah-Beyaz
              </button>
              <button
                type="button"
                onClick={() => { setFilterMode('original'); handleScan('original'); }}
                className={`flex-1 sm:flex-none px-3.5 py-1.5 rounded-lg text-xs font-medium flex items-center justify-center gap-2 transition duration-150 ${
                  filterMode === 'original'
                    ? 'bg-sky-500 text-slate-950 shadow-md font-semibold'
                    : 'text-slate-400 hover:text-slate-200'
                }`}
              >
                <ImageIcon className="w-3.5 h-3.5" /> Orijinal
              </button>
            </div>

            <button
              type="button"
              onClick={() => handleScan(filterMode)}
              className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-medium px-5 py-2 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
            >
              <Sparkles className="w-4 h-4" /> Belgeyi Tara & Doğrult
            </button>
          </div>

          <div className="relative border border-slate-800 rounded-2xl overflow-hidden bg-slate-950/80 flex justify-center items-center max-h-[520px] p-2 shadow-2xl">
            <canvas
              ref={canvasRef}
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
              className="max-h-[500px] w-auto object-contain cursor-crosshair rounded-lg touch-none"
            />
          </div>
        </div>
      )}

      {scannedPreviewUrl && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3 shadow-xl backdrop-blur-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
            <div className="flex items-center gap-2 text-xs font-semibold text-emerald-400">
              <CheckCircle2 className="w-4 h-4" /> Belge Doğrultuldu & Havuzuna Eklendi
            </div>
            <span className="text-[11px] font-mono text-slate-500 flex items-center gap-1.5">
              <Layers className="w-3.5 h-3.5" /> Mod: {filterMode.toUpperCase()}
            </span>
          </div>

          <div className="flex justify-center bg-slate-950/60 p-2 rounded-xl border border-slate-800/60">
            <img 
              src={scannedPreviewUrl} 
              alt="Taranmış Belge" 
              className="max-h-[360px] w-auto rounded-lg object-contain shadow-2xl" 
            />
          </div>
        </div>
      )}
    </div>
  );
}