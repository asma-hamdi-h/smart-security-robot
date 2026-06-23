import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/thingspeak_service.dart';
import '../theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ThingSpeakService _service = ThingSpeakService();
  bool _isGenerating = false;

  Future<void> _generateExcelReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      // 1. Fetch historical data
      final data = await _service.fetchHistory(results: 50);

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune donnée disponible pour le rapport.')),
          );
        }
        return;
      }

      // 2. Create Excel
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Rapport Sécurité'];
      excel.setDefaultSheet('Rapport Sécurité');

      // Headers
      sheetObject.appendRow([
        TextCellValue('Date'),
        TextCellValue('Heure'),
        TextCellValue('Score Risque'),
        TextCellValue('Gaz (ppm)'),
        TextCellValue('Flamme'),
        TextCellValue('Mouvement'),
        TextCellValue('Son'),
        TextCellValue('Luminosité'),
      ]);

      // Data Rows
      for (var entry in data) {
        sheetObject.appendRow([
          TextCellValue("${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}"),
          TextCellValue("${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}"),
          IntCellValue(entry.score),
          IntCellValue(entry.gas),
          TextCellValue(entry.flame == 1 ? "OUI" : "NON"),
          TextCellValue(entry.motion == 1 ? "OUI" : "NON"),
          TextCellValue(entry.sound == 1 ? "OUI" : "NON"),
          IntCellValue(entry.ldr),
        ]);
      }

      // 3. Save File
      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final String filePath = '${directory.path}/Rapport_Securite_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        // 4. Share/Open File
        await Share.shareXFiles([XFile(filePath)], text: 'Rapport de Sécurité ESP32');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Logs'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.fileSpreadsheet,
                size: 80,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Générer un Rapport',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Téléchargez l\'historique des événements et des paramètres enregistrés au format Excel (.xlsx)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateExcelReport,
                  icon: _isGenerating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.download),
                  label: Text(_isGenerating ? 'Génération...' : 'Exporter en Excel'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
