// class DocMasterReturn {
//   String? company;
//   String? custID;
//   String? custName;
//   String? docNum;
//   String? stat;
//   String? userId;
//   String? scanTime;

//   DocMasterReturn({
//     this.company,
//     this.docNum,
//     this.custID,
//     this.custName,
//     this.stat,
//     this.userId,
//     this.scanTime,
//   });

//   @override
//   String toString() {
//     return 'DocMasterReturn(company: $company,$custID, custName: $custName, docNum: $docNum, custNum:  stat: $stat, userId: $userId, scanTime: $scanTime)';
//   }

//   factory DocMasterReturn.fromDB(Map<String, dynamic> json) => DocMasterReturn(
//         company: json['CompanyDocMasterReturn'] as String?,
//         docNum: json['docNumDocMasterReturn'] as String?,
//         custID: json['CustIDDocMasterReturn'] as String?,
//         custName: json['CustNameDocMasterReturn'] as String?,
//         stat: json['statusDocMasterReturn'] as String?,
//         userId: json['UserIDDocMasterReturn'] as String?,
//         scanTime: json['TimeDocMasterReturn'] as String?,
//       );

//   // Map<String, dynamic> toJson() => {
//   //       'Company': company,
//   //       'DocNum': docNum,
//   //       'DocDate': docDate,
//   //       'CustNum': custID,
//   //       'CustName': custName,
//   //       'Stat': stat,
//   //       'UserID': userId,
//   //       'ScanTime': scanTime,
//   //       'DocDetails': docDetails?.map((e) => e.toJson()).toList(),
//   //     };

//   // Map<String, dynamic> toDB() => {
//   //       'Company': company,
//   //       'DocNum': docNum,
//   //       'DocDate': docDate,
//   //       'CustNum': custID,
//   //       'CustName': custName,
//   //       'Stat': stat,
//   //       'UserID': userId,
//   //       'ScanTime': scanTime,
//   //     };
// }
