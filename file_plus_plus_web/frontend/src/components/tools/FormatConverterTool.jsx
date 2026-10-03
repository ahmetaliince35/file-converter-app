import React, { useState } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  FileCode2, 
  UploadCloud, 
  Trash2, 
  ArrowRight, 
  FileText, 
  Sparkles, 
  FileType,
  Loader2,
  AlertTriangle,
  FolderArchive,
  Eye,
  CheckCircle2,
  Info,
  X
} from 'lucide-react';
import { useOutputs } from '../../context/OutputContext';
import ZipFilePickerModal from '../ZipFilePickerModal';
import CodeViewerModal from '../CodeViewerModal';
import { 
  isSupportedCodeExtension,
  isArchiveExtension,
  isBlockedMediaExtension,
  isBlockedBinaryExtension,
  decodeFileToText,
  convertTextOrCodeToPdf,
  inspectZipArchive,
  extractZipFiles
} from '../../services/universalConverter';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function FormatConverterTool({ setLoading }) {
  const [files, setFiles] = useState([]);
  const [targetFormat, setTargetFormat] = useState('pdf');
  const [processingIndex, setProcessingIndex] = useState(-1);
  const [statusMessage, setStatusMessage] = useState('');
  const [warningMessage, setWarningMessage] = useState(null);
  
  // ZIP Modal Durumu
  const [zipModalOpen, setZipModalOpen] = useState(false);
  const [zipData, setZipData] = useState(null);

  // Kod Önizleme Modal Durumu
  const [previewModalOpen, setPreviewModalOpen] = useState(false);
  const [previewFile, setPreviewFile] = useState(null);
  const [previewContent, setPreviewContent] = useState('');

  const { addOutput } = useOutputs();

  const handleIncomingFiles = async (incomingFiles) => {
    setWarningMessage(null);
    const validFiles = [];
    const blockedMedia = [];
    const blockedBinary = [];

    for (const file of incomingFiles) {
      const ext = file.name.split('.').pop() || '';

      // ZIP Arşivi Kontrolü
      if (isArchiveExtension(ext)) {
        try {
          setStatusMessage(`${file.name} taranıyor...`);
          const inspection = await inspectZipArchive(file);
          if (inspection.hasSupportedFiles) {
            setZipData(inspection);
            setZipModalOpen(true);
          } else {
            setWarningMessage({
              title: 'ZIP İçeriği Uygun Değil',
              text: `${file.name} arşivi içinde dönüştürülebilir kod veya metin belgesi bulunamadı.`
            });
          }
        } catch (err) {
          setWarningMessage({
            title: 'Arşiv Açılamadı',
            text: `ZIP dosyası incelenirken hata oluştu: ${err.message}`
          });
        } finally {
          setStatusMessage('');
        }
        continue;
      }

      // Medya Dosyaları Kontrolü (Ses, Video, Resim)
      if (isBlockedMediaExtension(ext)) {
        blockedMedia.push(file.name);
        continue;
      }

      // İkili / Çalıştırılabilir Dosyalar
      if (isBlockedBinaryExtension(ext)) {
        blockedBinary.push(file.name);
        continue;
      }

      // Desteklenen Kod veya Metin
      validFiles.push(file);
    }

    if (blockedMedia.length > 0) {
      setWarningMessage({
        title: 'Medya Dosyaları Atlandı',
        text: `${blockedMedia.length} adet medya dosyası (${blockedMedia.slice(0, 2).join(', ')}${blockedMedia.length > 2 ? '...' : ''}) doğrudan koda/metne dönüştürülemez. Görseller için PNG/JPG -> PDF veya OCR, ses kayıtları için MP3 -> Metin aracını kullanabilirsiniz.`
      });
    } else if (blockedBinary.length > 0) {
      setWarningMessage({
        title: 'Çalıştırılabilir Dosyalar Reddedildi',
        text: `Sistem güvenliği ve veri bütünlüğü için ${blockedBinary.join(', ')} dosyaları işlenemez.`
      });
    }

    if (validFiles.length > 0) {
      setFiles((prev) => [...prev, ...validFiles]);
    }
  };

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: handleIncomingFiles,
  });

  // ZIP'ten seçilen dosyaları dönüştürme kuyruğuna aktar
  const handleConfirmZipExtraction = async (selectedPaths, format) => {
    if (!zipData || !selectedPaths.length) return;
    setZipModalOpen(false);
    setLoading(true);

    try {
      setStatusMessage(`${selectedPaths.length} arşiv dosyası çıkartılıyor...`);
      const extractedFiles = await extractZipFiles(zipData.file, selectedPaths);

      for (let i = 0; i < extractedFiles.length; i++) {
        const item = extractedFiles[i];
        setStatusMessage(`[${i + 1}/${extractedFiles.length}] ${item.name} dönüştürülüyor...`);
        const baseName = item.name.substring(0, item.name.lastIndexOf('.')) || item.name;

        if (format === 'txt') {
          const blob = new Blob([item.content], { type: 'text/plain;charset=utf-8' });
          addOutput({
            blob,
            name: `${baseName}_utf8.txt`,
            toolSource: 'Arşivden Kod > TXT'
          });
        } else {
          const fakeFile = new File([item.content], item.name, { type: 'text/plain' });
          const pdfBlob = await convertTextOrCodeToPdf(fakeFile, (p) => {
            setStatusMessage(`${item.name}: ${p.percent}%`);
          });
          addOutput({
            blob: pdfBlob,
            name: `${baseName}.pdf`,
            toolSource: 'Arşivden Kod > PDF'
          });
        }
      }
    } catch (err) {
      alert('ZIP Dönüştürme Hatası: ' + err.message);
    } finally {
      setLoading(false);
      setStatusMessage('');
      setZipData(null);
    }
  };

  // Tek tek önizleme açma
  const handleOpenPreview = async (file) => {
    try {
      setLoading(true);
      const text = await decodeFileToText(file);
      setPreviewFile(file);
      setPreviewContent(text);
      setPreviewModalOpen(true);
    } catch (e) {
      alert('Dosya okunamadı: ' + e.message);
    } finally {
      setLoading(false);
    }
  };

  // Liste Halindeki Dosyaları Dönüştür
  const handleConvert = async () => {
    if (files.length === 0) return;
    setLoading(true);

    try {
      for (let idx = 0; idx < files.length; idx++) {
        setProcessingIndex(idx);
        const file = files[idx];
        const baseName = file.name.substring(0, file.name.lastIndexOf('.')) || file.name;

        if (targetFormat === 'txt') {
          setStatusMessage(`${file.name} UTF-8 metne dönüştürülüyor...`);
          const text = await decodeFileToText(file);
          const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
          addOutput({
            blob,
            name: `${baseName}_utf8.txt`,
            toolSource: 'Evrensel Metin (TXT)'
          });
        } else if (targetFormat === 'pdf') {
          setStatusMessage(`${file.name} PDF formatına derleniyor...`);
          const pdfBlob = await convertTextOrCodeToPdf(file, (progress) => {
            if (progress.lines) {
              setStatusMessage(`${file.name}: ${progress.lines.toLocaleString()} satır derlendi`);
            }
          });
          addOutput({
            blob: pdfBlob,
            name: `${baseName}.pdf`,
            toolSource: 'Evrensel Kod/Metin > PDF'
          });
        }

        await new Promise((r) => setTimeout(r, 60));
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

  const getExtensionBadgeClass = (ext) => {
    const e = ext.toLowerCase();
    if (['py', 'js', 'ts', 'jsx', 'tsx'].includes(e)) return 'text-amber-500 bg-amber-500/10 border-amber-500/30';
    if (['cs', 'java', 'cpp', 'c', 'go', 'rs', 'dart', 'swift', 'kt'].includes(e)) return 'text-sky-500 bg-sky-500/10 border-sky-500/30';
    if (['json', 'xml', 'yaml', 'yml', 'sql', 'toml'].includes(e)) return 'text-emerald-500 bg-emerald-500/10 border-emerald-500/30';
    if (['html', 'css', 'scss', 'vue'].includes(e)) return 'text-indigo-500 bg-indigo-500/10 border-indigo-500/30';
    return 'text-[var(--text-muted)] bg-[var(--bg-card-subtle)] border-[var(--border-subtle)]';
  };

  const totalSizeMB = (files.reduce((acc, f) => acc + f.size, 0) / (1024 * 1024)).toFixed(2);

  return (
    <div className="flex flex-col gap-5 max-w-4xl mx-auto w-full transition-colors duration-200">
      {/* Üst Başlık & Açıklama */}
      <div className="flex items-start justify-between border-b border-[var(--border-subtle)] pb-4">
        <div>
          <div className="flex items-center gap-2.5">
            <span className="p-2 rounded-2xl bg-sky-500/10 border border-sky-500/20 text-sky-500">
              <FileCode2 className="w-5 h-5" />
            </span>
            <h2 className="text-lg font-bold text-[var(--text-main)] font-display tracking-tight">
              Evrensel Kod & Metin Dönüştürücü
            </h2>
            <span className="text-[10px] font-mono font-bold uppercase px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">
              150+ Dil & Format
            </span>
          </div>
          <p className="text-xs text-[var(--text-muted)] mt-1.5 leading-relaxed">
            Python, Dart, C#, Java, Rust, Go, C++, JS/TS, SQL, JSON, YAML dahil 150+ kaynak kod dosyasını ve TXT/MD dokümanlarını bellek dostu motorla A4 PDF veya UTF-8 TXT'ye dönüştürün. ZIP arşivlerini çökmeksizin içeriden ayıklayın.
          </p>
        </div>
      </div>

      {/* Uyarı Banner'ı (Görsel/Ses Reddedilince veya Bilgilendirmede) */}
      {warningMessage && (
        <div className="flex items-start justify-between gap-3 p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-amber-500 animate-in fade-in duration-200">
          <div className="flex items-start gap-2.5">
            <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5" />
            <div className="text-xs">
              <span className="font-bold">{warningMessage.title}: </span>
              <span className="text-[var(--text-muted)]">{warningMessage.text}</span>
            </div>
          </div>
          <button
            onClick={() => setWarningMessage(null)}
            className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-lg transition"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {/* Sürükle Bırak Alanı */}
      <div
        {...getRootProps()}
        className={`border-2 border-dashed rounded-3xl p-8 sm:p-10 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-3.5 ${
          isDragActive
            ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
            : 'border-[var(--border-main)] hover:border-sky-500/50 bg-[var(--bg-card-subtle)] hover:bg-[var(--bg-card)]'
        }`}
      >
        <input {...getInputProps()} />
        <div className="p-4 rounded-3xl bg-[var(--bg-card)] border border-[var(--border-main)] text-sky-500 shadow-md">
          <UploadCloud className="w-7 h-7" />
        </div>
        <div>
          <p className="text-sm font-semibold text-[var(--text-main)]">
            Dosyaları veya ZIP arşivini buraya sürükleyin ya da <span className="text-sky-500 underline underline-offset-4">seçin</span>
          </p>
          <p className="text-xs text-[var(--text-muted)] mt-1.5 font-mono">
            .py, .dart, .cs, .java, .cpp, .rs, .go, .ts, .js, .sql, .json, .zip (Maks. 1024 MB)
          </p>
        </div>
        <div className="flex items-center gap-2 mt-1">
          <span className="inline-flex items-center gap-1 text-[11px] text-emerald-500 bg-emerald-500/10 px-2 py-0.5 rounded-md font-medium border border-emerald-500/20">
            <CheckCircle2 className="w-3 h-3" /> Akıllı Kod & ZIP Ayrıştırıcı
          </span>
          <span className="inline-flex items-center gap-1 text-[11px] text-sky-500 bg-sky-500/10 px-2 py-0.5 rounded-md font-medium border border-sky-500/20">
            <FolderArchive className="w-3 h-3" /> Güvenli ZIP İnceleme
          </span>
        </div>
      </div>

      {/* Seçilen Dosyalar Listesi */}
      {files.length > 0 && (
        <div className="bg-[var(--bg-card)] border border-[var(--border-main)] rounded-3xl p-4 sm:p-5 flex flex-col gap-4 shadow-sm">
          <div className="flex items-center justify-between border-b border-[var(--border-subtle)] pb-3">
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold text-[var(--text-main)] font-display">
                Dönüştürülecek Dosyalar ({files.length})
              </span>
              <span className="text-[11px] font-mono text-[var(--text-muted)]">
                • {totalSizeMB} MB
              </span>
            </div>
            <button
              onClick={() => setFiles([])}
              className="text-xs text-[var(--text-muted)] hover:text-rose-500 transition font-medium cursor-pointer"
            >
              Tümünü Temizle
            </button>
          </div>

          <div className="max-h-56 overflow-y-auto flex flex-col gap-2 pr-1 custom-scrollbar">
            {files.map((file, idx) => {
              const ext = file.name.split('.').pop() || 'TXT';
              const isCurrent = processingIndex === idx;

              return (
                <div
                  key={idx}
                  className={`flex justify-between items-center px-3.5 py-2.5 rounded-2xl border transition-all ${
                    isCurrent
                      ? 'bg-sky-500/10 border-sky-500/50 shadow-xs'
                      : 'bg-[var(--bg-card-subtle)] border-[var(--border-subtle)] hover:border-[var(--border-main)]'
                  }`}
                >
                  <div className="flex items-center gap-3 truncate min-w-0">
                    <span className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded-md border shrink-0 ${getExtensionBadgeClass(ext)}`}>
                      {ext.toUpperCase()}
                    </span>
                    <span className="text-xs text-[var(--text-main)] font-medium truncate max-w-[240px] sm:max-w-md">
                      {file.name}
                    </span>
                    <span className="text-[10px] text-[var(--text-muted)] font-mono shrink-0">
                      ({(file.size / 1024).toFixed(0)} KB)
                    </span>
                    {isCurrent && (
                      <span className="text-[10px] text-sky-500 flex items-center gap-1 font-semibold ml-2 shrink-0">
                        <Loader2 className="w-3 h-3 animate-spin" /> {statusMessage || 'İşleniyor'}
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-1.5 shrink-0 ml-2">
                    <button
                      type="button"
                      onClick={() => handleOpenPreview(file)}
                      className="p-1.5 rounded-xl text-[var(--text-muted)] hover:text-sky-500 hover:bg-[var(--bg-card)] transition cursor-pointer"
                      title="Kodu/Metni Önizle"
                    >
                      <Eye className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => setFiles((p) => p.filter((_, i) => i !== idx))}
                      className="p-1.5 rounded-xl text-[var(--text-muted)] hover:text-rose-500 hover:bg-[var(--bg-card)] transition cursor-pointer"
                      title="Listeden Çıkar"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Alt Format Seçici & Dönüştürme Butonu */}
          <div className="flex flex-col sm:flex-row items-center justify-between border-t border-[var(--border-subtle)] pt-4 gap-3">
            <div className="flex items-center gap-2.5 w-full sm:w-auto">
              <span className="text-xs text-[var(--text-muted)] font-medium flex items-center gap-1.5">
                <FileType className="w-4 h-4 text-sky-500" /> Hedef Format:
              </span>
              <div className="flex p-1 bg-[var(--bg-card-subtle)] rounded-2xl border border-[var(--border-main)] flex-1 sm:flex-none">
                <button
                  type="button"
                  onClick={() => setTargetFormat('pdf')}
                  className={`flex-1 sm:flex-none px-4 py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition cursor-pointer ${
                    targetFormat === 'pdf'
                      ? 'bg-sky-500 text-white shadow-xs'
                      : 'text-[var(--text-muted)] hover:text-[var(--text-main)]'
                  }`}
                >
                  <FileText className="w-3.5 h-3.5" /> A4 PDF
                </button>
                <button
                  type="button"
                  onClick={() => setTargetFormat('txt')}
                  className={`flex-1 sm:flex-none px-4 py-1.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition cursor-pointer ${
                    targetFormat === 'txt'
                      ? 'bg-sky-500 text-white shadow-xs'
                      : 'text-[var(--text-muted)] hover:text-[var(--text-main)]'
                  }`}
                >
                  <FileCode2 className="w-3.5 h-3.5" /> TXT (UTF-8)
                </button>
              </div>
            </div>

            <button
              type="button"
              onClick={handleConvert}
              className="w-full sm:w-auto bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-semibold px-6 py-2.5 rounded-2xl text-xs flex items-center justify-center gap-2 shadow-md shadow-sky-500/20 active:scale-[0.99] transition duration-150 cursor-pointer"
            >
              <Sparkles className="w-4 h-4" />
              <span>Dönüştür & Havuza Aktar</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* ZIP Ayıklama & Dosya Seçim Modalı */}
      {zipModalOpen && zipData && (
        <ZipFilePickerModal
          zipName={zipData.name}
          files={zipData.files}
          onConfirm={handleConfirmZipExtraction}
          onClose={() => setZipModalOpen(false)}
        />
      )}

      {/* In-App Kod & Metin Önizleme Modalı */}
      {previewModalOpen && previewFile && (
        <CodeViewerModal
          file={previewFile}
          textContent={previewContent}
          onClose={() => {
            setPreviewModalOpen(false);
            setPreviewFile(null);
            setPreviewContent('');
          }}
        />
      )}
    </div>
  );
}