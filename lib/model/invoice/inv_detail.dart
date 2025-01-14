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
  });

  @override
  String toString() {
    return 'DocDetail(company: $company, docNum: $docNum, slNo: $slNo, partNum: $partNum, partName: $partName, brand: $brand barcode: $barcode, shipQty: $shipQty, checkQty: $checkQty, stat: $stat)';
  }

  factory DocDetail.fromJson(Map<String, dynamic> json) => DocDetail(
        company: json['Company'] as String?,
        docNum: json['DocNum'] as String?,
        slNo: json['SlNo'] as int?,
        partNum: json['PartNum'] as String?,
        partName: json['PartName'] as String?,
        brand: json['Brand'] as String?,
        barcode: json['Barcode'] as String?,
        shipQty: json['ShipQty'] as int?,
        checkQty: json['CheckQty'] as int?,
        stat: json['Stat'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'Company': company,
        'DocNum': docNum,
        'SlNo': slNo,
        'PartNum': partNum,
        'Brand': brand,
        'ShipQty': shipQty,
        'CheckQty': checkQty,
        'Stat': stat,
      };

  Map<String, dynamic> toDB() => {
        'Company': company,
        'DocNum': docNum,
        'SlNo': slNo,
        'Barcode': barcode,
        'PartNum': partNum,
        'PartName': partName,
        'Brand': brand,
        'ShipQty': shipQty,
        'CheckQty': checkQty,
        'Stat': stat,
      };
}
