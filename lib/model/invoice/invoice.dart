import 'inv_detail.dart';

class DocMaster {
  String? company;
  String? docNum;
  String? docDate;
  String? custID;
  String? custName;
  String? stat;
  String? userId;
  String? scanTime;
  List<DocDetail>? docDetails;

  DocMaster({
    this.company,
    this.docNum,
    this.docDate,
    this.custID,
    this.custName,
    this.stat,
    this.userId,
    this.scanTime,
    this.docDetails,
  });

  @override
  String toString() {
    return 'DocMaster(company: $company, docNum: $docNum, docDate: $docDate, custNum: $custID, custName: $custName, stat: $stat, userId: $userId, scanTime: $scanTime, docDetails: $docDetails)';
  }

  factory DocMaster.fromJson(Map<String, dynamic> json) => DocMaster(
        company: json['Company'] as String?,
        docNum: json['DocNum'] as String?,
        docDate: json['DocDate'] as String?,
        custID: json['CustNum'] as String?,
        custName: json['CustName'] as String?,
        stat: json['Stat'] as String?,
        userId: json['UserID'] as String?,
        scanTime: json['ScanTime'] as String?,
        docDetails: (json['DocDetails'] as List<dynamic>?)
            ?.map((e) => DocDetail.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'DocDate': docDate,
        'CustNum': custID,
        'CustName': custName,
        'Stat': stat,
        'UserID': userId,
        'ScanTime': scanTime,
        'DocDetails': docDetails?.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toDB() => {
        'Company': company,
        'DocNum': docNum,
        'DocDate': docDate,
        'CustNum': custID,
        'CustName': custName,
        'Stat': stat,
        'UserID': userId,
        'ScanTime': scanTime,
      };
}
