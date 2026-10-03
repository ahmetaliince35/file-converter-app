import React, { useState } from "react";
import { useOutputs } from "../context/OutputContext";
import { 
  Eye, 
  Trash2, 
  X, 
  FileText, 
  Download, 
  QrCode, 
  Copy, 
  Check, 
  Loader2, 
  Inbox,
  FileSpreadsheet,
  FileAudio,
  FileCode2,
  Image as ImageIcon
} from "lucide-react";
import CloudDownloadAction from "./common/CloudDownloadAction";
import CodeViewerModal from "./CodeViewerModal";
import { createShareLinkApi } from "../services/api";
import { decodeFileToText, isSupportedCodeExtension } from "../services/universalConverter";

export default function OutputDock() {
  const { outputs, removeOutput, clearOutputs } = useOutputs();
  
  // Standart Önizleme (PDF, Görsel)
  const [previewItem, setPreviewItem] = useState(null);

  // Gelişmiş Kod & Metin İnceleyici Modalı
  const [codeViewerFile, setCodeViewerFile] = useState(null);
  const [codeViewerText, setCodeViewerText] = useState("");

  // Paylaşım (QR / PIN)
  const [sharingItem, setSharingItem] = useState(null);
  const [shareData, setShareData] = useState(null);
  const [shareLoading, setShareLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const openPreview = async (item) => {
    const ext = item.name.split('.').pop()?.toLowerCase() || '';
    const isCodeOrText = 
      isSupportedCodeExtension(ext) || 
      item.blob.type.includes("text") ||
      ['txt', 'log', 'md', 'json', 'csv'].includes(ext);

    // Eğer kod veya metin dosyası ise doğrudan tam donanımlı CodeViewerModal'ı aç
    if (isCodeOrText) {
      try {
        const text = await decodeFileToText(item.blob);
        setCodeViewerFile({ name: item.name, size: item.blob.size });
        setCodeViewerText(text);
        return;
      } catch (err) {
        console.error("Metin okuma hatası, genel önizlemeye geçiliyor:", err);
      }
    }

    // Diğerleri (PDF, Resim vb.) için standart modal
    const url = URL.createObjectURL(item.blob);
    setPreviewItem({
      ...item,
      url,
      isPdf: item.blob.type === "application/pdf" || item.name.endsWith(".pdf"),
      isImage: item.blob.type.startsWith("image/"),
    });
  };

  const closePreview = () => {
    if (previewItem?.url) {
      URL.revokeObjectURL(previewItem.url);
    }
    setPreviewItem(null);
  };

  const handleRemoveOutput = (index) => {
    if (previewItem && outputs[index]?.name === previewItem.name) {
      closePreview();
    }
    removeOutput(index);
  };

  const handleClearAll = () => {
    closePreview();
    clearOutputs();
  };

  const handleShareClick = async (item) => {
    setSharingItem(item);
    setShareData(null);
    setShareLoading(true);
    setCopied(false);

    try {
      const file = new File([item.blob], item.name, {
        type: item.blob.type || "application/octet-stream",
      });

      const res = await createShareLinkApi(file);
      setShareData(res.data);
    } catch (err) {
      console.error("Paylaşım hatası:", err);
      alert("Paylaşım bağlantısı oluşturulamadı: " + (err.response?.data?.detail || err.message));
      setSharingItem(null);
    } finally {
      setShareLoading(false);
    }
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const getFileBadge = (name) => {
    const ext = name.split('.').pop()?.toLowerCase();
    if (['mp3', 'wav', 'm4a', 'ogg'].includes(ext)) {
      return { icon: FileAudio, color: 'text-amber-500 bg-amber-500/10 border-amber-500/30' };
    }
    if (['pdf'].includes(ext)) {
      return { icon: FileText, color: 'text-rose-500 bg-rose-500/10 border-rose-500/30' };
    }
    if (['xlsx', 'csv'].includes(ext)) {
      return { icon: FileSpreadsheet, color: 'text-emerald-500 bg-emerald-500/10 border-emerald-500/30' };
    }
    if (['jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
      return { icon: ImageIcon, color: 'text-purple-500 bg-purple-500/10 border-purple-500/30' };
    }
    return { icon: FileCode2, color: 'text-sky-500 bg-sky-500/10 border-sky-500/30' };
  };

  if (!outputs || outputs.length === 0) return null;

  return (
    <>
      <div className="w-full md:w-88 bg-[var(--bg-card)] backdrop-blur-xl border border-[var(--border-main)] rounded-3xl p-4 flex flex-col gap-3.5 shadow-sm shrink-0 max-h-[calc(100vh-4rem)] sticky top-6 transition-colors duration-200">
        <div className="flex items-center justify-between border-b border-[var(--border-subtle)] pb-3">
          <div className="flex items-center gap-2.5">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
            </span>
            <span className="text-xs font-bold text-[var(--text-main)] tracking-wide flex items-center gap-1.5 font-display">
              <Inbox className="w-4 h-4 text-emerald-500" /> Çıktı Havuzu
            </span>
            <span className="text-[10px] bg-[var(--bg-card-subtle)] text-[var(--text-muted)] font-mono font-bold px-2 py-0.5 rounded-full border border-[var(--border-subtle)]">
              {outputs.length}
            </span>
          </div>
          <button
            onClick={handleClearAll}
            className="text-[11px] text-[var(--text-muted)] hover:text-rose-500 transition font-medium cursor-pointer"
          >
            Tümünü Sil
          </button>
        </div>

        <div className="flex flex-col gap-2.5 overflow-y-auto max-h-[520px] pr-1 custom-scrollbar">
          {outputs.map((item, idx) => {
            const badge = getFileBadge(item.name);
            const FileIcon = badge.icon;

            return (
              <div
                key={idx}
                className="bg-[var(--bg-card-subtle)] border border-[var(--border-subtle)] hover:border-[var(--border-main)] rounded-2xl p-3 flex flex-col gap-2.5 transition-all duration-150 shadow-xs"
              >
                <div className="flex items-start justify-between gap-2.5">
                  <div className="flex items-center gap-2.5 truncate min-w-0">
                    <span className={`p-2 rounded-xl border ${badge.color} shrink-0`}>
                      <FileIcon className="w-4 h-4" />
                    </span>
                    <div className="flex flex-col truncate min-w-0">
                      <span className="text-xs text-[var(--text-main)] font-semibold truncate" title={item.name}>
                        {item.name}
                      </span>
                      <span className="text-[10px] text-[var(--text-muted)] font-mono truncate">
                        {item.toolSource || "İşlem Çıktısı"}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => handleRemoveOutput(idx)}
                    className="text-[var(--text-muted)] hover:text-rose-500 p-1 rounded-lg hover:bg-rose-500/10 transition shrink-0 cursor-pointer"
                    title="Kaldır"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div className="flex items-center justify-between border-t border-[var(--border-subtle)] pt-2 gap-1.5">
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => openPreview(item)}
                      className="flex items-center gap-1 text-[11px] bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] text-[var(--text-main)] px-2.5 py-1.5 rounded-xl border border-[var(--border-main)] transition cursor-pointer font-medium shadow-xs"
                      title="İndirmeden İncele"
                    >
                      <Eye className="w-3.5 h-3.5 text-sky-500" />
                      <span>İncele</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => handleShareClick(item)}
                      className="flex items-center gap-1 text-[11px] bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400 px-2.5 py-1.5 rounded-xl border border-emerald-500/30 font-medium transition cursor-pointer"
                      title="QR & PIN ile Telefona Aktar"
                    >
                      <QrCode className="w-3.5 h-3.5" />
                      <span>Paylaş</span>
                    </button>
                  </div>

                  <CloudDownloadAction
                    fileBlob={item.blob}
                    fileName={item.name}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Paylaşım Modalı (QR Kod & PIN) */}
      {sharingItem && (
        <div
          onClick={() => setSharingItem(null)}
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-md flex justify-center items-center p-4 animate-in fade-in duration-150"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-[var(--bg-card)] border border-[var(--border-main)] rounded-3xl w-full max-w-sm p-6 flex flex-col items-center gap-4 text-center shadow-2xl relative"
          >
            <button
              onClick={() => setSharingItem(null)}
              className="absolute top-4 right-4 text-[var(--text-muted)] hover:text-[var(--text-main)] p-1 rounded-xl hover:bg-[var(--bg-card-subtle)] transition cursor-pointer"
            >
              <X className="w-4 h-4" />
            </button>

            <div className="flex flex-col items-center">
              <span className="p-3.5 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-500 mb-2 shadow-xs">
                <QrCode className="w-6 h-6" />
              </span>
              <span className="text-sm font-bold text-[var(--text-main)] font-display">
                Mobil Cihaza Aktar
              </span>
              <span className="text-xs text-[var(--text-muted)] truncate max-w-[240px] mt-1 font-mono">
                {sharingItem.name}
              </span>
            </div>

            {shareLoading ? (
              <div className="py-12 flex flex-col items-center gap-2 text-[var(--text-muted)] text-xs">
                <Loader2 className="w-7 h-7 text-emerald-500 animate-spin" />
                <span>QR Kod Hazırlanıyor...</span>
              </div>
            ) : shareData ? (
              <div className="flex flex-col items-center gap-3.5 w-full">
                <div className="p-3 rounded-2xl bg-white shadow-xl border border-slate-200">
                  <img
                    src={shareData.qr_code}
                    alt="QR Code"
                    className="w-44 h-44 object-contain"
                  />
                </div>

                <div className="bg-[var(--bg-card-subtle)] border border-[var(--border-main)] rounded-2xl px-4 py-2.5 w-full flex items-center justify-between shadow-xs">
                  <div className="flex flex-col text-left">
                    <span className="text-[10px] text-[var(--text-muted)] uppercase tracking-wider font-bold">
                      İndirme PIN Kodu
                    </span>
                    <span className="text-xl font-mono font-bold tracking-widest text-emerald-500">
                      {shareData.pin}
                    </span>
                  </div>
                  <button
                    onClick={() => copyToClipboard(shareData.pin)}
                    className="p-2 rounded-xl bg-[var(--bg-card)] hover:bg-[var(--bg-card-subtle)] text-[var(--text-main)] border border-[var(--border-main)] transition cursor-pointer"
                    title="PIN Kopyala"
                  >
                    {copied ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      )}

      {/* Standart PDF ve Resim Önizleme Modalı */}
      {previewItem && (
        <div
          onClick={closePreview}
          className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex justify-center items-center p-4 animate-in fade-in duration-150"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-[var(--bg-card)] border border-[var(--border-main)] rounded-3xl w-full max-w-4xl h-[86vh] flex flex-col shadow-2xl overflow-hidden"
          >
            <div className="flex items-center justify-between px-5 py-3.5 border-b border-[var(--border-subtle)] bg-[var(--bg-card-subtle)]">
              <div className="flex items-center gap-2.5 truncate">
                <FileText className="w-4 h-4 text-sky-500 shrink-0" />
                <span className="text-xs font-bold text-[var(--text-main)] truncate max-w-md">
                  {previewItem.name}
                </span>
                <span className="text-[10px] text-sky-500 bg-sky-500/10 border border-sky-500/20 px-2 py-0.5 rounded-full font-mono font-semibold">
                  Önizleme
                </span>
              </div>
              <button
                onClick={closePreview}
                className="text-[var(--text-muted)] hover:text-[var(--text-main)] p-1.5 rounded-xl hover:bg-[var(--bg-card)] transition cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex-1 bg-[var(--bg-page)] p-3 overflow-auto flex justify-center items-center">
              {previewItem.isPdf ? (
                <iframe
                  src={previewItem.url}
                  title="PDF Preview"
                  className="w-full h-full rounded-2xl border border-[var(--border-main)] bg-white"
                />
              ) : previewItem.isImage ? (
                <img
                  src={previewItem.url}
                  alt="Preview"
                  className="max-h-full max-w-full object-contain rounded-2xl shadow-xl"
                />
              ) : (
                <div className="text-center text-[var(--text-muted)] text-xs">
                  Bu dosya türü için tarayıcı içi önizleme desteklenmiyor.
                </div>
              )}
            </div>

            <div className="flex items-center justify-between px-5 py-3 border-t border-[var(--border-subtle)] bg-[var(--bg-card-subtle)]">
              <span className="text-xs font-mono text-[var(--text-muted)]">
                Boyut: {(previewItem.blob.size / 1024).toFixed(1)} KB
              </span>
              <a
                href={previewItem.url}
                download={previewItem.name}
                className="bg-sky-500 hover:bg-sky-400 text-white font-semibold px-4 py-2 rounded-xl text-xs flex items-center gap-2 shadow-md shadow-sky-500/20 transition active:scale-[0.99]"
              >
                <Download className="w-3.5 h-3.5" /> Dosyayı İndir
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Gelişmiş Kod & Metin İnceleme Modalı */}
      {codeViewerFile && (
        <CodeViewerModal
          file={codeViewerFile}
          textContent={codeViewerText}
          onClose={() => {
            setCodeViewerFile(null);
            setCodeViewerText("");
          }}
        />
      )}
    </>
  );
}