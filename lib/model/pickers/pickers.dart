class Pickers {
  String? id;
  String? name;
  String? type;

  Pickers({this.id, this.name, this.type});

  @override
  String toString() => 'Pickers(User: $id, name: $name, type: $type)';

  factory Pickers.fromJson(Map<String, dynamic> json) => Pickers(
        id: json['User'] as String?,
        name: json['Name'] as String?,
        type: json['Type'] as String?,
      );

  Map<String, dynamic> toJson() => {'User': id, 'Name': name, 'Type': type};

  Pickers copyWith({String? id, String? name, String? type}) {
    return Pickers(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }
}
