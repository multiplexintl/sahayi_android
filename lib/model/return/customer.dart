class Customer {
  String? custId;
  String? custName;

  Customer({this.custId, this.custName});

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        custId: json['ID'],
        custName: json['Name'],
      );

  Map<String, dynamic> toJson() {
    return {
      'ID': custId,
      'Name': custName,
    };
  }

  @override
  String toString() {
    return "Customer(custId: $custId, custName: $custName)";
  }
}
