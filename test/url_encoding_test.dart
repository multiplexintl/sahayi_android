import 'package:flutter_test/flutter_test.dart';
import 'package:global_configuration/global_configuration.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahayi_android/helper/http_client_helper.dart';
import 'package:sahayi_android/helper/url_query.dart';
import 'package:sahayi_android/repo/home_repo.dart';
import 'package:sahayi_android/repo/login_repo.dart';
import 'package:sahayi_android/repo/report_repo.dart';
import 'package:sahayi_android/repo/retrun_repo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Uri> sent;

  setUp(() {
    GlobalConfiguration().loadFromMap({'api_base_url': 'https://api.test/api/'});
    sent = [];
    HttpClientHelper.testClient = MockClient((req) async {
      sent.add(req.url);
      return http.Response('[]', 200);
    });
  });
  tearDown(() => HttpClientHelper.testClient = null);

  test('q(): normal values unchanged; special characters encoded', () {
    for (final v in ['MX1576', '25032700', '2025-39691', 'EPIC01', '2026-10-16', '', 'a_b.c~d']) {
      expect(q(v), v);
    }
    expect(q('Ab+12'), 'Ab%2B12');
    expect(q('M&S'), 'M%26S');
    expect(q('R#12'), 'R%2312');
  });

  test('normal values: exactly the same addresses as before the change', () async {
    await LoginRepo().getEmployee(empId: 'MX1576', pwd: 'Secret1');
    await HomeRepo().syncInvoice(company: 'EPIC01', docNum: '25032700', docType: 'I');
    await HomeRepo().updateInvoice(
        company: 'EPIC01', userId: 'MX1576', docNum: '2025-39691', docType: 'T', pickedBy: 'EX0085');
    await RetrunRepo().getPart(query: '6858475000001');
    await ReportRepo().fetchReports(
        company: '', empId: 'MX1576', fromDate: '2026-10-08', toDate: '2026-10-16',
        type: 'Date', docNum: '', docType: 'I');
    expect(sent.map((u) => u.toString()).toList(), [
      'https://api.test/api/Login/GetUsersLogin?UserID=MX1576&Pwd=Secret1',
      'https://api.test/api/Operational/Sync_Document?Company=EPIC01&DocNum=25032700&DocType=I',
      'https://api.test/api/Operational/UpdateDocument?UserID=MX1576&DocNum=2025-39691&DocType=T&Company=EPIC01&PickedBy=EX0085',
      'https://api.test/api/Return/GetPartData?barcode=6858475000001',
      'https://api.test/api/Operational/GetRecentActivity?UserID=MX1576&Company=&FromDate=2026-10-08&ToDate=2026-10-16&DocNum=&DDType=Date&DocType=I',
    ]);
  });

  test('special characters reach the server exactly as typed', () async {
    await LoginRepo().getEmployee(empId: 'MX1576', pwd: 'Ab+1&2#3%4 5');
    await RetrunRepo().fetchCustomer(company: 'EPIC01', query: 'M&S Store #2');
    try {
      await RetrunRepo().getReturnDetails(company: 'EPIC01', docNum: '1308R#12&A', docType: 'R');
    } catch (_) {}
    // what the server reads (same decoding rules as ASP.NET: %xx and + = space)
    expect(sent[0].queryParameters['Pwd'], 'Ab+1&2#3%4 5');
    expect(sent[0].queryParameters['UserID'], 'MX1576');
    expect(sent[1].queryParameters['query'], 'M&S Store #2');
    expect(sent[2].queryParameters['DocNum'], '1308R#12&A');
    expect(sent[2].queryParameters['Company'], 'EPIC01');
  });
}
