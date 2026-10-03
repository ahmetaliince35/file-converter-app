import React, { useState } from 'react';
import Header from './components/Header';
import Sidebar from './components/Sidebar';
import OutputDock from './components/OutputDock';
import LoadingOverlay from './components/LoadingOverlay';
import { ThemeProvider } from './context/ThemeContext';
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
    <ThemeProvider>
      <OutputProvider>
        <div className="min-h-screen bg-[var(--bg-page)] text-[var(--text-main)] flex flex-col font-sans selection:bg-sky-500 selection:text-white transition-colors duration-200">
          {loading && <LoadingOverlay />}
          
          <div className="w-full max-w-[1600px] mx-auto p-4 sm:p-6 flex flex-col gap-5 flex-1">
            <Header />

            {/* 3 Sütunlu Stüdyo Mimarisi */}
            <main className="flex flex-col lg:flex-row gap-5 flex-1 items-start">
              {/* 1. Sol: Araç Çubuğu */}
              <Sidebar activeTool={activeTool} onSelectTool={setActiveTool} />

              {/* 2. Orta: Aktif Çalışma Masası */}
              <section className="flex-1 w-full bg-[var(--bg-card)] border border-[var(--border-main)] rounded-3xl p-5 sm:p-6 shadow-sm backdrop-blur-sm min-h-[580px] transition-colors duration-200">
                {activeTool === 'converter' && <FormatConverterTool setLoading={setLoading} />}
                {activeTool === 'images-to-pdf' && <ImagesToPdfTool setLoading={setLoading} />}
                {activeTool === 'ocr' && <OcrTool setLoading={setLoading} />}
                {activeTool === 'office-to-pdf' && <OfficeToPdfTool setLoading={setLoading} />}
                {activeTool === 'pdf-extract' && <PdfExtractTool setLoading={setLoading} />}
                {activeTool === 'pdf-merge' && <PdfMergeTool setLoading={setLoading} />}
                {activeTool === 'camscanner' && <CamScannerTool setLoading={setLoading} />}
                {activeTool === 'audio-to-text' && <AudioTranscribeTool setLoading={setLoading} />}
              </section>

              {/* 3. Sağ: Çıktı Havuzu & Dağıtım İstasyonu */}
              <OutputDock />
            </main>
          </div>
        </div>
      </OutputProvider>
    </ThemeProvider>
  );
}