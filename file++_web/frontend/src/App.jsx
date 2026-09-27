import React, { useState } from 'react';
import Header from './components/Header';
import Sidebar from './components/Sidebar';
import OutputDock from './components/OutputDock';
import LoadingOverlay from './components/LoadingOverlay';
import { OutputProvider } from './context/OutputContext';

// Araçlar
import FormatConverterTool from './components/tools/FormatConverterTool';
import ImagesToPdfTool from './components/tools/ImagesToPdfTool';
import OcrTool from './components/tools/OcrTool';
import OfficeToPdfTool from './components/tools/OfficeToPdfTool';
import PdfExtractTool from './components/tools/PdfExtractTool';
import PdfMergeTool from './components/tools/PdfMergeTool';
import CamScannerTool from './components/tools/CamScannerTool';
import AudioTranscribeTool from './components/tools/AudioTranscribeTool';

export default function App() {
  const [activeTool, setActiveTool] = useState('converter');
  const [loading, setLoading] = useState(false);

  return (
    <OutputProvider>
      <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-sky-500 selection:text-slate-950">
        {loading && <LoadingOverlay />}
        
        <div className="w-full max-w-[1600px] mx-auto p-4 sm:p-6 flex flex-col gap-5 flex-1">
          <Header />

          {/* 3 Sütunlu Stüdyo Mimarisi */}
          <main className="flex flex-col lg:flex-row gap-5 flex-1 items-start">
            {/* 1. Sol: Araç Çubuğu */}
            <Sidebar activeTool={activeTool} onSelectTool={setActiveTool} />

            {/* 2. Orta: Aktif Çalışma Masası */}
            <section className="flex-1 w-full bg-slate-900/40 border border-slate-800/80 rounded-2xl p-5 shadow-lg backdrop-blur-sm min-h-[550px]">
              {activeTool === 'converter' && <FormatConverterTool setLoading={setLoading} />}
              {activeTool === 'images-to-pdf' && <ImagesToPdfTool setLoading={setLoading} />}
              {activeTool === 'ocr' && <OcrTool setLoading={setLoading} />}
              {activeTool === 'office-to-pdf' && <OfficeToPdfTool setLoading={setLoading} />}
              {activeTool === 'pdf-extract' && <PdfExtractTool setLoading={setLoading} />}
              {activeTool === 'pdf-merge' && <PdfMergeTool setLoading={setLoading} />}
              {activeTool === 'camscanner' && <CamScannerTool setLoading={setLoading} />}
              {activeTool === 'audio-to-text' && <AudioTranscribeTool setLoading={setLoading} />}
            </section>

            {/* 3. Sağ: Çıktı Havuzu & WiFi Dağıtım İstasyonu */}
            <OutputDock />
          </main>
        </div>
      </div>
    </OutputProvider>
  );
}