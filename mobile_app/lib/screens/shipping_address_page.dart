import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/shipping_address_model.dart';
import '../services/api_service.dart';
import '../utils/custom_toast.dart';

class ShippingAddressPage extends StatefulWidget {
  const ShippingAddressPage({super.key});

  @override
  State<ShippingAddressPage> createState() => _ShippingAddressPageState();
}

class _ShippingAddressPageState extends State<ShippingAddressPage> {
  late Future<List<ShippingAddress>> _addressFuture;
  bool _isEditing = false;
  ShippingAddress? _editingAddress;

  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _subDistrictController = TextEditingController();
  final _districtController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  void _loadAddresses() {
    setState(() {
      _addressFuture = ApiService.getShippingAddresses();
    });
  }

  void _startEditing(ShippingAddress? addr) {
    setState(() {
      _isEditing = true;
      _editingAddress = addr;
      if (addr != null) {
        _recipientController.text = addr.recipientName;
        _phoneController.text = addr.phoneNumber;
        _addressLineController.text = addr.addressLine1;
        _subDistrictController.text = addr.subDistrict;
        _districtController.text = addr.district;
        _provinceController.text = addr.province;
        _postalCodeController.text = addr.postalCode;
      } else {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _recipientController.clear();
    _phoneController.clear();
    _addressLineController.clear();
    _subDistrictController.clear();
    _districtController.clear();
    _provinceController.clear();
    _postalCodeController.clear();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final address = ShippingAddress(
      id: _editingAddress?.id ?? 0,
      userId: 0, // Ignored by backend (uses token)
      recipientName: _recipientController.text,
      phoneNumber: _phoneController.text,
      addressLine1: _addressLineController.text,
      subDistrict: _subDistrictController.text,
      district: _districtController.text,
      province: _provinceController.text,
      postalCode: _postalCodeController.text,
    );

    final success = await ApiService.saveShippingAddress(address);
    if (success) {
      if (mounted) {
        CustomToast.show(context, 'บันทึกที่อยู่เรียบร้อยแล้ว');
        setState(() {
          _isEditing = false;
          _editingAddress = null;
        });
        _loadAddresses();
      }
    } else {
      if (mounted) {
        CustomToast.show(context, 'บันทึกข้อมูลไม่สำเร็จ', isSuccess: false);
      }
    }
  }

  Future<void> _deleteAddress(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('คุณต้องการลบที่อยู่นี้ใช่หรือไม่?', style: GoogleFonts.kanit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('ลบ', style: GoogleFonts.kanit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ApiService.deleteShippingAddress(id);
      if (success) {
        if (mounted) {
          CustomToast.show(context, 'ลบที่อยู่เรียบร้อยแล้ว');
          _loadAddresses();
        }
      } else {
        if (mounted) {
          CustomToast.show(context, 'ลบข้อมูลไม่สำเร็จ', isSuccess: false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('จัดการที่อยู่จัดส่ง', 
          style: GoogleFonts.kanit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<ShippingAddress>>(
        future: _addressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.kanit()));
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty || _isEditing) {
            return _buildForm();
          }

          return _buildAddressCard(addresses.first);
        },
      ),
    );
  }

  Widget _buildAddressCard(ShippingAddress addr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 8),
                    Text('ที่อยู่ของคุณ', style: GoogleFonts.kanit(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 32),
                Text(addr.recipientName, style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(addr.phoneNumber, style: GoogleFonts.kanit(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 12),
                Text(
                  '${addr.addressLine1}\n${addr.subDistrict}, ${addr.district}\n${addr.province} ${addr.postalCode}',
                  style: GoogleFonts.kanit(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _startEditing(addr),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text('แก้ไข', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueAccent,
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteAddress(addr.id),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: Text('ลบ', style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editingAddress == null ? 'เพิ่มที่อยู่จัดส่ง' : 'แก้ไขที่อยู่', 
              style: GoogleFonts.kanit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('ชื่อผู้รับ', _recipientController, 'ชื่อ-นามสกุล'),
            _buildTextField('เบอร์โทรศัพท์', _phoneController, '08xxxxxxxx', isPhone: true),
            _buildTextField('รายละเอียดที่อยู่', _addressLineController, 'เลขที่อาคาร, หมู่บ้าน, ถนน, ซอย', maxLines: 2),
            Row(
              children: [
                Expanded(child: _buildTextField('ตำบล/แขวง', _subDistrictController, '')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('อำเภอ/เขต', _districtController, '')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildTextField('จังหวัด', _provinceController, '')),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField('รหัสไปรษณีย์', _postalCodeController, '')),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('บันทึกข้อมูล', 
                  style: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _editingAddress = null;
                    });
                  },
                  child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.grey[600], fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isPhone = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.kanit(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blueGrey[700])),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: GoogleFonts.kanit(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.kanit(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) => value == null || value.isEmpty ? 'กรุณากรอกข้อมูล' : null,
          ),
        ],
      ),
    );
  }
}
