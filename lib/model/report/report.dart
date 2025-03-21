import 'package:intl/intl.dart';

class Report {
  String? company;
  String? docNum;
  String? custId;
  String? custName;
  String? userId;
  String? scanTime;
  String? docType;

  Report({
    this.company,
    this.docNum,
    this.custId,
    this.custName,
    this.userId,
    this.scanTime,
    this.docType,
  });

  @override
  String toString() {
    return 'Report(company: $company, docNum: $docNum, custId: $custId, custName: $custName, userId: $userId, scanTime: $scanTime, DocType: $docType)';
  }

  factory Report.fromJson(Map<String, dynamic> json) {
    String? docNum = json['DocNum'] as String?;
    String? docType = json['DocType'] as String?;
    String? custID = json['CustNum'] as String?;

    // If docType is 'R' and docNum starts with first 4 digits of custID, remove them
    if (docType == 'R' &&
        docNum != null &&
        custID != null &&
        docNum.length > 4 &&
        docNum.startsWith(custID.substring(0, 4))) {
      docNum = docNum.substring(4); // Remove first 4 digits
    }
    return Report(
      company: json['Company'] as String?,
      docNum: docNum,
      custId: custID,
      custName: json['CustName'] as String?,
      userId: json['UserID'] as String?,
      scanTime: json['ScanTime'] != null
          ? DateFormat('dd-MM-yyyy HH:mm:ss')
              .format(DateTime.parse(json['ScanTime']))
          : null,
      docType: docType,
    );
  }

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'CustNum': custId,
        'CustName': custName,
        'UserID': userId,
        'ScanTime': scanTime,
      };
}
