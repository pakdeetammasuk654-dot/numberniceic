class SampleName {
  final int id;
  final String name;
  final String avatarUrl;
  final bool isActive;

  SampleName({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isActive,
  });

  factory SampleName.fromJson(Map<String, dynamic> json) {
    return SampleName(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      isActive: json['is_active'] ?? false,
    );
  }
}
