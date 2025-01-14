class Company {
  final String? companyId;
  final String? companyName;

  // Constructor
  Company({
    this.companyId,
    this.companyName,
  });

  // Named Constructor for JSON Parsing
  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      companyId: json['Company'] as String?,
      companyName: json['Name'] as String?,
    );
  }

  // Convert Object to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'Company': companyId,
      'Name': companyName,
    };
  }

  // Override toString for Better Debugging
  @override
  String toString() {
    return 'Company(companyId: $companyId, companyName: $companyName)';
  }
}
