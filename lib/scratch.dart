import 'package:excel/excel.dart';

void main() {
  try {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // Add some rows
    sheetObject.appendRow([
      TextCellValue('Question'),
      TextCellValue('Opt A'),
      TextCellValue('Opt B'),
      TextCellValue('Opt C'),
      TextCellValue('Opt D'),
      TextCellValue('Ans'),
    ]);

    var bytes = excel.save();

    var parsedExcel = Excel.decodeBytes(bytes!);

    for (var table in parsedExcel.tables.keys) {
      var sheet = parsedExcel.tables[table];
      for (int i = 0; i < sheet!.maxRows; i++) {
        var row = sheet.rows[i];
        print(row);
        print(row[0]?.value?.toString());
      }
    }
  } catch (e) {
    print("Caught: $e");
  }
}
