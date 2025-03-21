class DocDetail {
  String? company;
  String? docNum;
  int? slNo;
  String? partNum;
  String? partName;
  String? brand;
  String? barcode;
  int? shipQty;
  int? checkQty;
  String? stat;
  String? docType;
  String? reasonCode;
  String? reasonName;
  String? expiryDate;

  DocDetail({
    this.company,
    this.docNum,
    this.slNo,
    this.partNum,
    this.partName,
    this.brand,
    this.barcode,
    this.shipQty,
    this.checkQty,
    this.stat,
    this.docType,
    this.reasonCode,
    this.reasonName,
    this.expiryDate,
  });

  DocDetail copyWith({
    String? company,
    String? docNum,
    int? slNo,
    String? partNum,
    String? partName,
    String? brand,
    String? barcode,
    int? shipQty,
    int? checkQty,
    String? stat,
    String? docType,
    String? reasonCode,
    String? reasonName,
    String? expiryDate,
  }) {
    return DocDetail(
      company: company ?? this.company,
      docNum: docNum ?? this.docNum,
      slNo: slNo ?? this.slNo,
      partNum: partNum ?? this.partNum,
      partName: partName ?? this.partName,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      shipQty: shipQty ?? this.shipQty,
      checkQty: checkQty ?? this.checkQty,
      stat: stat ?? this.stat,
      docType: docType ?? this.docType,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonName: reasonName ?? this.reasonName,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  String toString() {
    return 'DocDetail(company: $company, docNum: $docNum, slNo: $slNo, partNum: $partNum, partName: $partName, brand: $brand, barcode: $barcode, shipQty: $shipQty, checkQty: $checkQty, stat: $stat, docType: $docType, reasonCode: $reasonCode, reasonName: $reasonName, expiryDate: $expiryDate)\n';
  }

  factory DocDetail.fromJson(Map<String, dynamic> json) {
    String? docNum = json['DocNum'] as String?;
    String? docType = json['DocType'] as String?;

    // If docType is 'R' and docNum starts with the first 4 digits, remove them
    if (docType == 'R' && docNum != null && docNum.length > 4) {
      docNum = docNum.substring(4);
    }

    return DocDetail(
      company: json['Company'] as String?,
      docNum: docNum,
      slNo: json['SlNo'] as int?,
      partNum: json['PartNum'] as String?,
      partName: json['PartName'] as String?,
      brand: json['Brand'] as String?,
      barcode: json['Barcode'] as String?,
      shipQty: json['ShipQty'] as int?,
      checkQty: json['CheckQty'] as int?,
      stat: json['Stat'] as String?,
      docType: docType,
      reasonCode: json['ReasonCode'] as String?,
      reasonName: json['ReasonName'] as String?,
      expiryDate: json['ExpDate'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'SlNo': slNo,
        'PartNum': partNum,
        'Brand': brand,
        'ShipQty': shipQty,
        'CheckQty': checkQty,
        'Stat': stat,
        'DocType': docType,
        'ReasonCode': reasonCode,
        'ReasonName': reasonName,
        'ExpDate': expiryDate,
      };

  Map<String, dynamic> toDB() => {
        'Company': company,
        'DocNum': docNum,
        'DocType': docType,
        'SlNo': slNo,
        'Barcode': barcode,
        'PartNum': partNum,
        'PartName': partName,
        'Brand': brand,
        'ShipQty': shipQty,
        'CheckQty': checkQty,
        'Stat': stat,
        'ReasonCode': reasonCode,
        'ReasonName': reasonName,
        'ExpDate': expiryDate
      };
}
