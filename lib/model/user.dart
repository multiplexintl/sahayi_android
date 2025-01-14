class User {
  String? company;
  String? empName;
  String? empID;
  String? pwd;

  User({this.company, this.empID, this.empName, this.pwd});

  @override
  String toString() {
    return "User(company: $company, empName: $empName, empID: $empID, pwd: $pwd)";
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        company: json['Company'] as String?,
        empName: json['UserName'] as String?,
        empID: json['UserID'] as String?,
        pwd: json['Pwd'] as String?,
      );

  /// Convert User object to JSON Map for storage
  Map<String, dynamic> toJson() {
    return {
      'Company': company,
      'UserName': empName,
      'UserID': empID,
      'Pwd': pwd,
    };
  }
}
