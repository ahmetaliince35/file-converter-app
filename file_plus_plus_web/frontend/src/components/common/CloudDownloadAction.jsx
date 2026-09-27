import React, { useState, useEffect } from 'react';
import { Download, CheckCircle2, Loader2 } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { saveToGoogleDrive } from '../../services/CloudEngines';

export default function CloudDownloadAction({ fileBlob, fileName, defaultDownloadUrl }) {
  const { provider, token } = useAuth();
  const [syncState, setSyncState] = useState('idle');
  const [downloadUrl, setDownloadUrl] = useState(defaultDownloadUrl || '');

  // Blob varsa ve harici url yoksa tarayıcı object URL üret
  useEffect(() => {
    if (defaultDownloadUrl) {
      setDownloadUrl(defaultDownloadUrl);
    } else if (fileBlob) {
      const url = URL.createObjectURL(fileBlob);
      setDownloadUrl(url);
      return () => URL.revokeObjectURL(url);
    }
  }, [fileBlob, defaultDownloadUrl]);

  const handleDriveSync = async () => {
    if (!fileBlob || !token || syncState === 'syncing') return;
    setSyncState('syncing');

    try {
      await saveToGoogleDrive(fileBlob, fileName, token);
      setSyncState('synced');
      setTimeout(() => setSyncState('idle'), 3500);
    } catch (err) {
      alert('Google Drive senkronizasyon hatası: ' + (err.response?.data?.error?.message || err.message));
      setSyncState('idle');
    }
  };

  return (
    <div className="flex items-center gap-1.5">
      {provider === 'google' && (
        <button
          type="button"
          onClick={handleDriveSync}
          disabled={syncState === 'syncing'}
          className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold border transition ${
            syncState === 'synced'
              ? 'bg-emerald-950/50 border-emerald-500/50 text-emerald-400'
              : 'bg-slate-900 border-slate-700 hover:bg-slate-800 text-slate-200'
          }`}
          title="Google Drive'a Gönder"
        >
          {syncState === 'syncing' ? (
            <>
              <Loader2 className="w-3.5 h-3.5 animate-spin text-sky-400" />
              <span>Aktarılıyor...</span>
            </>
          ) : syncState === 'synced' ? (
            <>
              <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" />
              <span>Eklendi ✓</span>
            </>
          ) : (
            <>
              <img
                src="https://www.svgrepo.com/show/475656/google-color.svg"
                className="w-3.5 h-3.5"
                alt="Google Drive"
              />
              <span className="hidden sm:inline">Drive</span>
            </>
          )}
        </button>
      )}

      {/* İndir Butonu - downloadUrl boşsa tıklanmaz */}
      <a
        href={downloadUrl || '#'}
        download={fileName}
        className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold px-3 py-1.5 rounded-lg text-xs flex items-center gap-1.5 transition shrink-0 shadow-sm"
      >
        <Download className="w-3.5 h-3.5" />
        <span>İndir</span>
      </a>
    </div>
  );
}