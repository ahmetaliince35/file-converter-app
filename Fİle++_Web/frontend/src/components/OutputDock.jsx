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
  FileCode,
  Image as ImageIcon
} from "lucide-react";
import CloudDownloadAction from "./common/CloudDownloadAction";
import { createShareLinkApi } from "../services/api";

export default function OutputDock() {
  const { outputs, removeOutput, clearOutputs } = useOutputs();
  const [previewItem, setPreviewItem] = useState(null);

  const [sharingItem, setSharingItem] = useState(null);
  const [shareData, setShareData] = useState(null);
  const [shareLoading, setShareLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const openPreview = async (item) => {
    const url = URL.createObjectURL(item.blob);
    const isText =
      item.blob.type.includes("text") ||
      item.name.endsWith(".txt") ||
      item.name.endsWith(".json") ||
      item.name.endsWith(".py") ||
      item.name.endsWith(".cs") ||
      item.name.endsWith(".js") ||
      item.name.endsWith(".html");

    let textContent = "";
    if (isText) {
      const fullText = await item.blob.text();
      textContent = fullText.length > 20000 
        ? fullText.slice(0, 20000) + "\n\n... [Önizleme amacıyla ilk 20.000 karakter gösterilmektedir] ..."
        : fullText;
    }

    setPreviewItem({
      ...item,
      url,
      isText,
      textContent,
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
      return { icon: FileAudio, color: 'text-amber-400 bg-amber-500/10 border-amber-500/20' };
    }
    if (['pdf'].includes(ext)) {
      return { icon: FileText, color: 'text-rose-400 bg-rose-500/10 border-rose-500/20' };
    }
    if (['xlsx', 'csv'].includes(ext)) {
      return { icon: FileSpreadsheet, color: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20' };
    }
    if (['jpg', 'jpeg', 'png', 'webp'].includes(ext)) {
      return { icon: ImageIcon, color: 'text-purple-400 bg-purple-500/10 border-purple-500/20' };
    }
    return { icon: FileCode, color: 'text-sky-400 bg-sky-500/10 border-sky-500/20' };
  };

  if (!outputs || outputs.length === 0) return null;

  return (
    <>
      <div className="w-full md:w-84 bg-slate-900/60 backdrop-blur-xl border border-slate-800/80 rounded-3xl p-4 flex flex-col gap-3 shadow-2xl shrink-0 max-h-[calc(100vh-4rem)] sticky top-6">
        <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
          <div className="flex items-center gap-2.5">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
            </span>
            <span className="text-xs font-bold text-slate-100 tracking-wide flex items-center gap-1.5">
              <Inbox className="w-4 h-4 text-emerald-400" /> Çıktı Havuzu
            </span>
            <span className="text-[10px] bg-slate-800/90 text-slate-300 font-mono px-2 py-0.5 rounded-full border border-slate-700/60">
              {outputs.length}
            </span>
          </div>
          <button
            onClick={handleClearAll}
            className="text-[11px] text-slate-400 hover:text-rose-400 transition font-medium"
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
                className="bg-slate-950/70 border border-slate-800/80 hover:border-slate-700/80 rounded-2xl p-3 flex flex-col gap-2.5 transition-all duration-150 shadow-sm"
              >
                <div className="flex items-start justify-between gap-2.5">
                  <div className="flex items-center gap-2.5 truncate">
                    <span className={`p-2 rounded-xl border ${badge.color} shrink-0`}>
                      <FileIcon className="w-4 h-4" />
                    </span>
                    <div className="flex flex-col truncate">
                      <span className="text-xs text-slate-200 font-medium truncate" title={item.name}>
                        {item.name}
                      </span>
                      <span className="text-[10px] text-slate-500 font-mono">
                        {item.toolSource || "İşlem Çıktısı"}
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => handleRemoveOutput(idx)}
                    className="text-slate-500 hover:text-rose-400 p-1 rounded-lg hover:bg-rose-500/10 transition shrink-0"
                    title="Kaldır"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>

                <div className="flex items-center justify-between border-t border-slate-900 pt-2 gap-1.5">
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => openPreview(item)}
                      className="flex items-center gap-1 text-[11px] bg-slate-900/90 hover:bg-slate-800 text-slate-300 hover:text-sky-300 px-2.5 py-1.5 rounded-xl border border-slate-800 transition"
                      title="İndirmeden İncele"
                    >
                      <Eye className="w-3.5 h-3.5 text-sky-400" />
                      <span>Önizle</span>
                    </button>

                    <button
                      type="button"
                      onClick={() => handleShareClick(item)}
                      className="flex items-center gap-1 text-[11px] bg-emerald-950/40 hover:bg-emerald-900/50 text-emerald-400 px-2.5 py-1.5 rounded-xl border border-emerald-500/20 font-medium transition"
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

      {sharingItem && (
        <div
          onClick={() => setSharingItem(null)}
          className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex justify-center items-center p-4 animate-in fade-in duration-150"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-sm p-6 flex flex-col items-center gap-4 text-center shadow-2xl relative"
          >
            <button
              onClick={() => setSharingItem(null)}
              className="absolute top-4 right-4 text-slate-400 hover:text-white p-1 rounded-xl hover:bg-slate-800 transition"
            >
              <X className="w-4 h-4" />
            </button>

            <div className="flex flex-col items-center">
              <span className="p-3 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 mb-2">
                <QrCode className="w-6 h-6" />
              </span>
              <span className="text-sm font-bold text-slate-100">
                Mobil Cihaza Aktar
              </span>
              <span className="text-xs text-slate-400 truncate max-w-[240px] mt-1 font-mono">
                {sharingItem.name}
              </span>
            </div>

            {shareLoading ? (
              <div className="py-12 flex flex-col items-center gap-2 text-slate-400 text-xs">
                <Loader2 className="w-7 h-7 text-emerald-400 animate-spin" />
                <span>QR Kod Oluşturuluyor...</span>
              </div>
            ) : shareData ? (
              <div className="flex flex-col items-center gap-3.5 w-full">
                <div className="p-2.5 rounded-2xl bg-white shadow-xl">
                  <img
                    src={shareData.qr_code}
                    alt="QR Code"
                    className="w-44 h-44 object-contain"
                  />
                </div>

                <div className="bg-slate-950/80 border border-slate-800 rounded-2xl px-4 py-2.5 w-full flex items-center justify-between">
                  <div className="flex flex-col text-left">
                    <span className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">
                      İndirme PIN Kodu
                    </span>
                    <span className="text-xl font-mono font-bold tracking-widest text-emerald-400">
                      {shareData.pin}
                    </span>
                  </div>
                  <button
                    onClick={() => copyToClipboard(shareData.pin)}
                    className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 text-slate-300 hover:text-white border border-slate-800 transition"
                    title="PIN Kopyala"
                  >
                    {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            ) : null}
          </div>
        </div>
      )}

      {previewItem && (
        <div
          onClick={closePreview}
          className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex justify-center items-center p-4 animate-in fade-in duration-150"
        >
          <div
            onClick={(e) => e.stopPropagation()}
            className="bg-slate-900 border border-slate-800 rounded-3xl w-full max-w-4xl h-[86vh] flex flex-col shadow-2xl overflow-hidden"
          >
            <div className="flex items-center justify-between px-5 py-3.5 border-b border-slate-800/80 bg-slate-950/80">
              <div className="flex items-center gap-2.5 truncate">
                <FileText className="w-4 h-4 text-sky-400 shrink-0" />
                <span className="text-xs font-bold text-slate-200 truncate max-w-md">
                  {previewItem.name}
                </span>
                <span className="text-[10px] text-sky-400 bg-sky-500/10 border border-sky-500/20 px-2 py-0.5 rounded-full font-mono">
                  Önizleme
                </span>
              </div>
              <button
                onClick={closePreview}
                className="text-slate-400 hover:text-white p-1.5 rounded-xl hover:bg-slate-800 transition"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="flex-1 bg-slate-950 p-3 overflow-auto flex justify-center items-center">
              {previewItem.blob.type === "application/pdf" || previewItem.name.endsWith(".pdf") ? (
                <iframe
                  src={previewItem.url}
                  title="PDF Preview"
                  className="w-full h-full rounded-2xl border border-slate-800 bg-white"
                />
              ) : previewItem.isText ? (
                <div className="w-full h-full p-4 overflow-auto bg-slate-900/90 rounded-2xl border border-slate-800 font-mono text-xs text-slate-200 leading-relaxed custom-scrollbar">
                  <pre className="whitespace-pre-wrap select-text">
                    {previewItem.textContent}
                  </pre>
                </div>
              ) : previewItem.blob.type.startsWith("image/") ? (
                <img
                  src={previewItem.url}
                  alt="Preview"
                  className="max-h-full max-w-full object-contain rounded-2xl shadow-xl"
                />
              ) : (
                <div className="text-center text-slate-500 text-xs">
                  Bu dosya türü için tarayıcı içi önizleme desteklenmiyor.
                </div>
              )}
            </div>

            <div className="flex items-center justify-between px-5 py-3 border-t border-slate-800/80 bg-slate-950/80">
              <span className="text-xs font-mono text-slate-500">
                Boyut: {(previewItem.blob.size / 1024).toFixed(1)} KB
              </span>
              <a
                href={previewItem.url}
                download={previewItem.name}
                className="bg-sky-500 hover:bg-sky-400 text-slate-950 font-semibold px-4 py-2 rounded-xl text-xs flex items-center gap-2 shadow-lg shadow-sky-500/20 transition active:scale-[0.99]"
              >
                <Download className="w-3.5 h-3.5" /> Dosyayı İndir
              </a>
            </div>
          </div>
        </div>
      )}
    </>
  );
}