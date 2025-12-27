class Article {
  final int id;
  final String title;
  final String titleShort;
  final String slug;
  final String category;
  final String excerpt;
  final String imageUrl;
  final String content;
  final int pinOrder;
  final DateTime? publishedAt;

  Article({
    required this.id,
    required this.title,
    required this.titleShort,
    required this.slug,
    required this.category,
    required this.excerpt,
    required this.imageUrl,
    required this.content,
    required this.pinOrder,
    this.publishedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['art_id'] ?? json['message_id'] ?? 0, // Fallback support
      title: json['title'] ?? '',
      titleShort: json['title_short'] ?? '',
      slug: json['slug'] ?? '',
      category: json['category'] ?? '',
      excerpt: json['excerpt'] ?? '',
      imageUrl: json['image_url'] ?? '',
      content: json['content'] ?? '',
      pinOrder: json['pin_order'] ?? 0,
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at']) 
          : null,
    );
  }
}
