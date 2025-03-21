class Reasons {
  String? reasonId;
  String? reason;

  Reasons({this.reasonId, this.reason});

  factory Reasons.fromJson(Map<String, dynamic> json) => Reasons(
        reasonId: json['ID'],
        reason: json['Name'],
      );
  Map<String, dynamic> toJson() {
    return {
      'ID': reasonId,
      'Name': reason,
    };
  }

  @override
  String toString() {
    return "Reasons(reasonId: $reasonId, reason: $reason)";
  }
}
