
class NameCharacter {
  final String char;
  final bool isBad;

  NameCharacter({
    required this.char,
    required this.isBad,
  });

  factory NameCharacter.fromJson(Map<String, dynamic> json) {
    bool isBadVal = false;
    final val = json['is_bad'] ?? json['is_klakini'];
    if (val is bool) {
      isBadVal = val;
    } else if (val is String) {
      isBadVal = val.toLowerCase() == 'true';
    }

    return NameCharacter(
      char: json['char'] ?? '',
      isBad: isBadVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'char': char,
      'is_bad': isBad,
    };
  }
}
