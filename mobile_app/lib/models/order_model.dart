class OrderModel {
  final int id;
  final String refNo;
  final int? userId;
  final double amount;
  final String status;
  final String productName;
  final String? productImage;
  final String? slipUrl;
  final int? promoCodeId;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.refNo,
    this.userId,
    required this.amount,
    required this.status,
    required this.productName,
    this.productImage,
    this.slipUrl,
    this.promoCodeId,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      refNo: json['ref_no'] ?? '',
      userId: json['user_id'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? '',
      productName: json['product_name'] ?? '',
      productImage: json['product_image'],
      slipUrl: json['slip_url'],
      promoCodeId: json['promo_code_id'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isPaid => status == 'paid' || status == 'verified';
  bool get isPending => status == 'pending';
}
