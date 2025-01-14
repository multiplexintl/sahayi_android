import 'package:intl/intl.dart';

class Report {
  String? company;
  String? docNum;
  String? custNum;
  String? custName;
  String? userId;
  String? scanTime;

  Report({
    this.company,
    this.docNum,
    this.custNum,
    this.custName,
    this.userId,
    this.scanTime,
  });

  @override
  String toString() {
    return 'Report(company: $company, docNum: $docNum, custNum: $custNum, custName: $custName, userId: $userId, scanTime: $scanTime)';
  }

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        company: json['Company'] as String?,
        docNum: json['DocNum'] as String?,
        custNum: json['CustNum'] as String?,
        custName: json['CustName'] as String?,
        userId: json['UserID'] as String?,
        scanTime: json['ScanTime'] != null
            ? DateFormat('dd-MM-yyyy HH:mm:ss')
                .format(DateTime.parse(json['ScanTime']))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'CustNum': custNum,
        'CustName': custName,
        'UserID': userId,
        'ScanTime': scanTime,
      };
}
