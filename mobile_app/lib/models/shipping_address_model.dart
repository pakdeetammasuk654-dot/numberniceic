class ShippingAddress {
  final int id;
  final int userId;
  final String recipientName;
  final String phoneNumber;
  final String addressLine1;
  final String subDistrict;
  final String district;
  final String province;
  final String postalCode;
  final bool isDefault;

  ShippingAddress({
    required this.id,
    required this.userId,
    required this.recipientName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.subDistrict,
    required this.district,
    required this.province,
    required this.postalCode,
    this.isDefault = false,
  });

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['id'] ?? json['ID'] ?? 0,
      userId: json['user_id'] ?? json['UserID'] ?? 0,
      recipientName: json['recipient_name'] ?? json['RecipientName'] ?? '',
      phoneNumber: json['phone_number'] ?? json['PhoneNumber'] ?? '',
      addressLine1: json['address_line1'] ?? json['AddressLine1'] ?? '',
      subDistrict: json['sub_district'] ?? json['SubDistrict'] ?? '',
      district: json['district'] ?? json['District'] ?? '',
      province: json['province'] ?? json['Province'] ?? '',
      postalCode: json['postal_code'] ?? json['PostalCode'] ?? '',
      isDefault: json['is_default'] ?? json['IsDefault'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'recipient_name': recipientName,
      'phone_number': phoneNumber,
      'address_line1': addressLine1,
      'sub_district': subDistrict,
      'district': district,
      'province': province,
      'postal_code': postalCode,
      'is_default': isDefault,
    };
  }
}
