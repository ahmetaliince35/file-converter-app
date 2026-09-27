import React, { useState, useEffect } from 'react';
import { useDropzone } from 'react-dropzone';
import { 
  Mic, 
  Key, 
  Sparkles, 
  UploadCloud, 
  FileAudio, 
  CheckCircle2, 
  RotateCcw, 
  Copy, 
  Check, 
  X,
  Volume2,
  FileText
} from 'lucide-react';
import { useOutputs } from '../../context/OutputContext';

const MAX_UPLOAD_LIMIT = 1024 * 1024 * 1024; // 1024 MB

export default function AudioTranscribeTool({ setLoading }) {
  const [file, setFile] = useState(null);
  const [audioUrl, setAudioUrl] = useState(null);
  const [transcriptText, setTranscriptText] = useState('');
  const [copied, setCopied] = useState(false);
  const [deepgramKey, setDeepgramKey] = useState(
    () => localStorage.getItem('deepgram_api_key') || ''
  );
  const { addOutput } = useOutputs();

  useEffect(() => {
    if (!file) {
      setAudioUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setAudioUrl(url);

    return () => {
      URL.revokeObjectURL(url);
    };
  }, [file]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    accept: {
      'audio/*': ['.mp3', '.wav', '.m4a', '.ogg', '.flac', '.aac', '.wma', '.webm', '.opus', '.aiff']
    },
    maxFiles: 1,
    maxSize: MAX_UPLOAD_LIMIT,
    onDrop: (acceptedFiles, fileRejections) => {
      if (fileRejections.length > 0) {
        const isMultiple = fileRejections.some(r => r.errors.some(e => e.code === 'too-many-files'));
        const isSizeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-too-large'));
        const isTypeErr = fileRejections.some(r => r.errors.some(e => e.code === 'file-invalid-type'));

        if (isMultiple) {
          alert('Ses Transkripsiyon Aracı tek seferde yalnızca 1 dosya kabul eder.');
          return;
        }
        if (isSizeErr) {
          alert('Dosya boyutu 1024 MB (1 GB) sınırını aşıyor.');
          return;
        }
        if (isTypeErr) {
          alert('Lütfen geçerli bir ses dosyası seçin (.mp3, .wav, .m4a, .ogg, .flac vb.).');
          return;
        }
      }

      if (acceptedFiles[0]) {
        setFile(acceptedFiles[0]);
        setTranscriptText('');
      }
    },
  });

  const handleTranscribe = async () => {
    if (!file) return;
    if (!deepgramKey.trim()) {
      alert('Lütfen geçerli bir Deepgram API anahtarı girin.');
      return;
    }

    setLoading(true);
    localStorage.setItem('deepgram_api_key', deepgramKey.trim());

    try {
      const response = await fetch(
        'https://api.deepgram.com/v1/listen?model=nova-2&smart_format=true&punctuate=true&detect_language=true',
        {
          method: 'POST',
          headers: {
            Authorization: `Token ${deepgramKey.trim()}`,
            'Content-Type': file.type || 'audio/*',
          },
          body: file,
        }
      );

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.err_msg || errorData.message || 'Deepgram API hatası.');
      }

      const result = await response.json();
      const channel = result.results?.channels?.[0];
      const text =
        channel?.alternatives?.[0]?.transcript ||
        channel?.alternatives?.[0]?.paragraphs?.transcript ||
        '';

      if (!text.trim()) {
        alert('Ses dosyasında konuşma tespit edilemedi.');
        return;
      }

      setTranscriptText(text);
    } catch (err) {
      alert('Transkripsiyon Hatası: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveToDock = () => {
    if (!transcriptText.trim()) return;
    const blob = new Blob([transcriptText], { type: 'text/plain;charset=utf-8' });
    const baseName = file?.name?.substring(0, file.name.lastIndexOf('.')) || 'ses';
    const outputName = `${baseName}_transkript.txt`;

    addOutput({
      blob,
      name: outputName,
      toolSource: 'Deepgram Nova-2 (Ses > TXT)'
    });
  };

  const handleCopy = () => {
    if (!transcriptText) return;
    navigator.clipboard.writeText(transcriptText);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const wordCount = transcriptText.trim() ? transcriptText.trim().split(/\s+/).length : 0;

  return (
    <div className="flex flex-col gap-5 max-w-3xl mx-auto w-full">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-lg font-semibold text-slate-100 flex items-center gap-2.5">
            <span className="p-2 rounded-lg bg-sky-500/10 border border-sky-500/20 text-sky-400">
              <Mic className="w-5 h-5" />
            </span>
            Ses Transkripsiyon Aracı
          </h2>
          <p className="text-xs text-slate-400 mt-1">
            Deepgram Nova-2 modeli ile yüksek doğrulukta ses çözümleme ve düzenleme.
          </p>
        </div>
      </div>

      <div className="bg-slate-900/60 border border-slate-800/80 rounded-xl p-3 flex flex-col gap-1.5 focus-within:border-sky-500/40 transition-colors">
        <label className="text-[11px] font-medium text-slate-400 flex items-center gap-1.5">
          <Key className="w-3.5 h-3.5 text-sky-400" /> Deepgram API Anahtarı
        </label>
        <input
          type="password"
          value={deepgramKey}
          onChange={(e) => setDeepgramKey(e.target.value)}
          placeholder="Token girin (örn: 3df8...)"
          className="bg-slate-950/60 border border-slate-800 rounded-lg px-3 py-2 text-xs text-slate-200 placeholder:text-slate-600 outline-none focus:ring-1 focus:ring-sky-500 transition"
        />
      </div>

      {!file ? (
        <div
          {...getRootProps()}
          className={`border-2 border-dashed rounded-2xl p-8 text-center cursor-pointer transition-all duration-200 flex flex-col items-center justify-center gap-3 ${
            isDragActive
              ? 'border-sky-500 bg-sky-500/10 scale-[0.99]'
              : 'border-slate-800 hover:border-slate-700 bg-slate-900/30 hover:bg-slate-900/50'
          }`}
        >
          <input {...getInputProps()} />
          <div className="p-3.5 rounded-full bg-slate-800/80 border border-slate-700/50 text-sky-400 shadow-inner">
            <UploadCloud className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-medium text-slate-200">
              Ses dosyasını buraya sürükleyin veya <span className="text-sky-400 underline underline-offset-2">seçin</span>
            </p>
            <p className="text-[11px] text-slate-500 mt-1">
              MP3, WAV, M4A, OGG, FLAC, AAC (Tek Dosya • Maks. 1024 MB)
            </p>
          </div>
        </div>
      ) : (
        <div className="bg-slate-900/70 border border-slate-800 rounded-xl p-3.5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-lg bg-sky-500/10 text-sky-400 border border-sky-500/20">
              <FileAudio className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-medium text-slate-200 truncate max-w-xs sm:max-w-md">
                {file.name}
              </p>
              <p className="text-[11px] text-slate-500 font-mono">
                {(file.size / (1024 * 1024)).toFixed(2)} MB
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => { setFile(null); setTranscriptText(''); }}
            className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition"
            title="Dosyayı Kaldır"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {file && !transcriptText && (
        <button
          type="button"
          onClick={handleTranscribe}
          className="w-full bg-gradient-to-r from-sky-500 to-indigo-600 hover:from-sky-400 hover:to-indigo-500 text-white font-medium py-2.5 rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-sky-500/20 active:scale-[0.99] transition duration-150"
        >
          <Sparkles className="w-4 h-4" /> Nova-2 ile Çözümle & Önizle
        </button>
      )}

      {transcriptText && (
        <div className="bg-slate-900/40 border border-slate-800 rounded-2xl p-4 flex flex-col gap-4 shadow-xl backdrop-blur-sm">
          <div className="flex items-center justify-between border-b border-slate-800/80 pb-3">
            <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-400" /> Transkript Hazır
            </span>
            <button
              onClick={() => { setTranscriptText(''); setFile(null); }}
              className="text-xs text-slate-400 hover:text-slate-200 flex items-center gap-1.5 transition"
            >
              <RotateCcw className="w-3.5 h-3.5" /> Baştan Başla
            </button>
          </div>

          {audioUrl && (
            <div className="bg-slate-950/80 border border-slate-800 p-2.5 rounded-xl flex items-center gap-2">
              <Volume2 className="w-4 h-4 text-slate-400 ml-1" />
              <audio controls src={audioUrl} className="w-full h-8 accent-sky-500" />
            </div>
          )}

          <div className="flex flex-col gap-2">
            <div className="flex justify-between items-center px-1">
              <span className="text-[11px] font-medium text-slate-400 flex items-center gap-1.5">
                <FileText className="w-3.5 h-3.5 text-slate-500" /> Metin Alanı
              </span>
              <div className="flex items-center gap-3 text-[11px] text-slate-500 font-mono">
                <span>{wordCount} kelime</span>
                <span>•</span>
                <span>{transcriptText.length} karakter</span>
              </div>
            </div>

            <div className="relative group">
              <textarea
                value={transcriptText}
                onChange={(e) => setTranscriptText(e.target.value)}
                rows={9}
                className="w-full bg-slate-950/90 text-slate-200 font-sans text-xs p-4 rounded-xl border border-slate-800 focus:border-sky-500/50 focus:ring-1 focus:ring-sky-500/50 outline-none leading-relaxed resize-y transition shadow-inner"
                placeholder="Transkript metni..."
              />
              <button
                type="button"
                onClick={handleCopy}
                className="absolute top-3 right-3 p-1.5 rounded-lg bg-slate-900 border border-slate-800 text-slate-400 hover:text-slate-200 opacity-0 group-hover:opacity-100 transition duration-150"
                title="Panoya Kopyala"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
              </button>
            </div>
          </div>

          <div className="flex justify-end pt-1">
            <button
              type="button"
              onClick={handleSaveToDock}
              className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-semibold px-4 py-2.5 rounded-xl text-xs flex items-center gap-2 shadow-lg shadow-emerald-500/20 active:scale-[0.99] transition duration-150"
            >
              <CheckCircle2 className="w-4 h-4" /> Çıktı Havuzuna Aktar
            </button>
          </div>
        </div>
      )}
    </div>
  );
}