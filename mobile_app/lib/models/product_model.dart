class ProductModel {
  final String id;
  final String name;
  final String description;
  final int price;
  final String imageColor1;
  final String imageColor2;
  final String iconType;
  final String? imagePath;

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageColor1,
    required this.imageColor2,
    required this.iconType,
    this.imagePath,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] ?? 0,
      imageColor1: json['image_color_1'] ?? '#CCCCCC',
      imageColor2: json['image_color_2'] ?? '#999999',
      iconType: json['icon_type'] ?? 'coin',
      imagePath: json['image_path'],
    );
  }
}
