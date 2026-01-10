
class TakhsaUtils {
  static const Map<String, List<String>> groups = {
    '1': ['ะ', 'า', 'ิ', 'ี', 'ุ', 'ู', 'เ', 'แ', 'โ', 'ใ', 'ไ', 'ั', '็', '่', '้', '๊', '๋', 'ื', 'ึ', 'ํ', '์', 'ำ'], 
    '2': ['ก', 'ข', 'ค', 'ฆ', 'ง'],
    '3': ['จ', 'ฉ', 'ช', 'ซ', 'ฌ', 'ญ'],
    '4': ['ฎ', 'ฏ', 'ฐ', 'ฑ', 'ฒ', 'ณ'],
    '5': ['บ', 'ป', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ม'],
    '6': ['ศ', 'ษ', 'ส', 'ห', 'ฬ', 'ฮ'],
    '7': ['ด', 'ต', 'ถ', 'ท', 'ธ', 'น'],
    '8': ['ย', 'ร', 'ล', 'ว'],
  };

  static const Map<String, String> klakiniMap = {
    'sunday': '6',
    'monday': '1',
    'tuesday': '2',
    'wednesday1': '3',
    'saturday': '4',
    'thursday': '7',
    'wednesday2': '5',
    'friday': '8',
  };

  static bool isKlakini(String char, String birthday) {
    String klakiniGroupId = klakiniMap[birthday.toLowerCase().trim()] ?? '';
    if (klakiniGroupId.isEmpty) return false;
    List<String>? group = groups[klakiniGroupId];
    if (group == null) return false;
    return group.contains(char);
  }
}
