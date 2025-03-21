class Part {
  String? company;
  String? partNum;
  String? barcode;
  String? partName;
  String? brand;

  Part({
    this.company,
    this.partNum,
    this.barcode,
    this.partName,
    this.brand,
  });

  @override
  String toString() {
    return 'Part(company: $company, partNum: $partNum, barcode: $barcode, partName: $partName, brand: $brand)';
  }

  factory Part.fromJson(Map<String, dynamic> json) => Part(
        company: json['Company'] as String?,
        partNum: json['PartNum'] as String?,
        barcode: json['Barcode'] as String?,
        partName: json['PartName'] as String?,
        brand: json['Brand'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'Company': company,
        'PartNum': partNum,
        'Barcode': barcode,
        'PartName': partName,
        'Brand': brand,
      };
}
