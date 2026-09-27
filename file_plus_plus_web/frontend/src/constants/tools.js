import { 
  RefreshCw, FilePlus2, Scissors, 
  Images, ScanLine, FileText ,
  Mic
} from 'lucide-react';

export const TOOLS = [
  { id: 'converter', label: 'Format Çevirici', icon: RefreshCw},
  { id: 'pdf-merge', label: 'PDF Birleştir', icon: FilePlus2 },
  { id: 'pdf-extract', label: 'PDF Ayıkla', icon: Scissors},
  { id: 'images-to-pdf', label: 'PNG/JPG -> PDF', icon: Images},
  { id: 'camscanner', label: 'CamScanner', icon: ScanLine },
  { id: 'ocr', label: 'Metin Çıkar (OCR)', icon: FileText},
  {id: 'office-to-pdf', label: 'Office -> PDF', icon: FilePlus2},
  {id: 'audio-to-text', label: 'MP3/WAV -> Metin', icon: Mic}
];