import 'package:flutter_test/flutter_test.dart';
import 'package:sahayi_android/model/invoice/doc_master.dart';
import 'package:sahayi_android/model/report/report.dart';

void main() {
  Map<String, dynamic> row(String custId, String docNum) =>
      {'DocType': 'R', 'CustNum': custId, 'DocNum': docNum, 'Company': 'EPIC01'};

  test('4-digit customer IDs: same result as before', () {
    expect(DocMaster.fromJson(row('1308', '1308R1')).docNum, 'R1');
    expect(DocMaster.fromJson(row('9110', '91102001977977')).docNum, '2001977977');
    expect(Report.fromJson(row('1308', '1308R1')).docNum, 'R1');
  });

  test('longer / shorter customer IDs: exactly the ID is removed', () {
    expect(DocMaster.fromJson(row('10234', '10234R1')).docNum, 'R1');
    expect(DocMaster.fromJson(row('995', '995R1')).docNum, 'R1'); // crashed before (substring(0, 4))
    expect(Report.fromJson(row('10234', '10234R1')).docNum, 'R1');
  });

  test('round trip used by resume / delete: custID + docNum gives the stored number', () {
    for (final id in ['1308', '10234', '995']) {
      final d = DocMaster.fromJson(row(id, '${id}R1'));
      expect('${d.custID}${d.docNum}', '${id}R1');
    }
  });

  test('not a return, or number without the ID prefix: untouched', () {
    expect(DocMaster.fromJson({'DocType': 'I', 'CustNum': '1308', 'DocNum': '13081234'}).docNum, '13081234');
    expect(DocMaster.fromJson(row('1308', 'R1')).docNum, 'R1');
  });
}
