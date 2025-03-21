import 'doc_detail.dart';

class DocMaster {
  String? company;
  String? docNum;
  String? docDate;
  String? custID;
  String? custName;
  String? stat;
  String? userId;
  String? scanTime;
  String? docType;
  String? pickedBy;
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
    this.docType,
    this.pickedBy,
    this.docDetails,
  });

  DocMaster copyWith({
    String? company,
    String? docNum,
    String? docDate,
    String? custID,
    String? custName,
    String? stat,
    String? userId,
    String? scanTime,
    String? docType,
    String? pickedBy,
    List<DocDetail>? docDetails,
  }) {
    return DocMaster(
      company: company ?? this.company,
      docNum: docNum ?? this.docNum,
      docDate: docDate ?? this.docDate,
      custID: custID ?? this.custID,
      custName: custName ?? this.custName,
      stat: stat ?? this.stat,
      userId: userId ?? this.userId,
      scanTime: scanTime ?? this.scanTime,
      docType: docType ?? this.docType,
      pickedBy: pickedBy ?? this.pickedBy,
      docDetails: docDetails ?? this.docDetails,
    );
  }

  @override
  String toString() {
    return 'DocMaster(company: $company, docNum: $docNum, docDate: $docDate, custID: $custID, custName: $custName, stat: $stat, userId: $userId, scanTime: $scanTime, docType: $docType, pickedBy: $pickedBy, docDetails: $docDetails)';
  }

  factory DocMaster.fromJson(Map<String, dynamic> json) {
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

    return DocMaster(
      company: json['Company'] as String?,
      docNum: docNum,
      docDate: json['DocDate'] as String?,
      custID: custID,
      custName: json['CustName'] as String?,
      stat: json['Stat'] as String?,
      userId: json['UserID'] as String?,
      scanTime: json['ScanTime'] as String?,
      docType: docType,
      pickedBy: json['PickedBy'] as String?,
      docDetails: (json['DocDetails'] as List<dynamic>?)
          ?.map((e) => DocDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'DocDate': docDate,
        'CustNum': custID,
        'CustName': custName,
        'Stat': stat,
        'UserID': userId,
        'ScanTime': scanTime,
        'DocType': docType,
        'PickedBy': pickedBy,
        'DocDetails': docDetails?.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toDB() => {
        'Company': company,
        'DocNum': docNum,
        'DocDate': docDate,
        'CustNum': custID,
        'DocType': docType,
        'CustName': custName,
        'Stat': stat,
        'UserID': userId,
        'ScanTime': scanTime,
        'PickedBy': pickedBy
      };

  Map<String, dynamic> toJsonReturn() => {
        "SReturnMaster": {
          "Company": company,
          "DocNum": docNum,
          "DocType": docType,
          "DocDate": docDate,
          "CustID": custID,
          "Stat": stat,
          "UserID": userId,
          "ScanTime": scanTime,
          "PickedBy": pickedBy,
          "RtnDetails": docDetails?.map((e) => e.toJson()).toList(),
        }
      };
}
