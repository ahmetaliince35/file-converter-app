import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../data/pdf_merger_service.dart';

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key});

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final List<File> _pdfList = [];
  bool _isProcessing = false;

  Future<void> _pdfEkle() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        for (var path in result.paths) {
          if (path != null) _pdfList.add(File(path));
        }
      });
    }
  }

  Future<void> _birlestirVeKaydet() async {
    if (_pdfList.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birleştirmek için en az 2 PDF eklemelisiniz.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final File birlestirilen = await PdfMergerService.mergePdfFiles(_pdfList);
      if (!mounted) return;
      Navigator.pop(context, birlestirilen);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Birleştir & Ekle (${_pdfList.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'PDF Ekle',
            onPressed: _isProcessing ? null : _pdfEkle,
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _pdfList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 70, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Birleştirilecek PDF belgelerini seçin.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('PDF Dosyaları Seç'),
              onPressed: _pdfEkle,
            ),
          ],
        ),
      )
          : ReorderableListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pdfList.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = _pdfList.removeAt(oldIndex);
            _pdfList.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final file = _pdfList[index];
          final name = file.uri.pathSegments.last;
          return Card(
            key: ValueKey(file.path + index.toString()),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade100,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _pdfList.removeAt(index)),
                  ),
                  const Icon(Icons.drag_handle),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _pdfList.length >= 2
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.merge_type),
            label: const Text('PDF\'LERİ SIRASIYLA BİRLEŞTİR', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _isProcessing ? null : _birlestirVeKaydet,
          ),
        ),
      )
          : null,
    );
  }
}