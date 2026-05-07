import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  Sheet sheetObject = excel['Sheet1'];

  // Add header
  sheetObject.appendRow([
    TextCellValue('Baslik'),
    TextCellValue('Kategori'),
    TextCellValue('Konum'),
    TextCellValue('Tarih'),
    TextCellValue('Aciklama'),
    TextCellValue('Gorsel URL'),
    TextCellValue('Enlem (Lat)'),
    TextCellValue('Boylam (Lng)'),
  ]);

  // Add dummy events
  sheetObject.appendRow([
    TextCellValue('Yaz Festivali 2026'),
    TextCellValue('Festival'),
    TextCellValue('Istanbul - Kilyos'),
    TextCellValue('2026-07-20 18:00:00'),
    TextCellValue('Yazin en eglenceli muzik festivali.'),
    TextCellValue('https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&q=80&w=1000'),
    DoubleCellValue(41.25),
    DoubleCellValue(29.03),
  ]);

  sheetObject.appendRow([
    TextCellValue('Cem Yilmaz Stand-up'),
    TextCellValue('Stand-up'),
    TextCellValue('Istanbul - Zorlu PSM'),
    TextCellValue('2026-06-10 21:00:00'),
    TextCellValue('Kahkaha tufanina hazir olun.'),
    TextCellValue('https://images.unsplash.com/photo-1585699324551-f6c309eedeca?auto=format&fit=crop&q=80&w=1000'),
    DoubleCellValue(41.066),
    DoubleCellValue(29.016),
  ]);

  sheetObject.appendRow([
    TextCellValue('Kucuk Prens Tiyatrosu'),
    TextCellValue('Tiyatro'),
    TextCellValue('Ankara - Cermodern'),
    TextCellValue('2026-05-15 15:00:00'),
    TextCellValue('Klasik eserin sahne uyarlamasi.'),
    TextCellValue('assets/images/placeholder.png'),
    DoubleCellValue(39.925),
    DoubleCellValue(32.836),
  ]);

  var fileBytes = excel.save();
  if (fileBytes != null) {
    File('ornek_etkinlikler.xlsx')
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes);
    print('ornek_etkinlikler.xlsx basariyla olusturuldu!');
  }
}
