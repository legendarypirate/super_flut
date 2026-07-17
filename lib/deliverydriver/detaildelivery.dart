import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../color/color.dart';
import '../mainscreen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final int deliveryId;

  DeliveryDetailScreen({required this.deliveryId});

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  Map<String, dynamic>? delivery;
  bool isLoading = true;
  String? error;
  List<dynamic> items = [];
  List<dynamic> statuses = [];
  int? selectedStatusId;
  TextEditingController commentController = TextEditingController();
  File? _deliveryImage;
  final ImagePicker _picker = ImagePicker();
  DateTime? selectedDeliveryDate;


  Future<void> fetchItems() async {
    final url = Uri.parse('${Url.url}/api/delivery/${widget.deliveryId}/items');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            items = jsonResponse['data'];
          });
        }
      } else {
        print('Item fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Item fetch error: $e');
    }
  }

  Future<void> _callPhoneNumber(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Утасны дугаарыг дуудахад алдаа гарлаа')),
      );
    }
  }

  Future<void> _fetchStatuses() async {
    final url = Uri.parse('${Url.url}/api/status');
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final jsonData = jsonDecode(res.body);
      statuses = jsonData['data'];
      setState(() {}); // refresh dropdown
    } else {
      throw Exception('Failed to load statuses');
    }
  }

  Future<void> _submitPostpone() async {
    if (selectedStatusId == null) return;

    final url = Uri.parse(
        '${Url.url}/api/mobile/delivery/complete/${delivery!['id']}');

    final requestBody = {
      "status": selectedStatusId,
      "driver_comment": commentController.text.trim(),
    };

    // Add delivery_date if status is 6 (postpone) and date is selected
    if (selectedStatusId == 6 && selectedDeliveryDate != null) {
      requestBody["delivery_date"] = 
          "${selectedDeliveryDate!.year}-${selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${selectedDeliveryDate!.day.toString().padLeft(2, '0')}";
    }

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Төлөв амжилттай шинэчлэгдлээ')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Амжилтгүй боллоо')),
      );
    }
  }


  @override
  void initState() {
    super.initState();
    fetchDelivery();
    fetchDelivery().then((_) {
      fetchItems();
    });
  }

  Future<void> fetchDelivery() async {
    final url = Uri.parse(Url.url + '/api/delivery/${widget.deliveryId}');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            delivery = jsonResponse['data'];
            isLoading = false;
            error = null;
          });
        } else {
          setState(() {
            error = 'Failed to load delivery details';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = 'Server error: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Color(0xFF204a35),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Хүргэлтийн дэлгэрэнгүй',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: Color(0xFF204a35),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: Text(error!)),
      );
    }

    // Static items as requested

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Хүргэлтийн дэлгэрэнгүй',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Color(0xFF204a35),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General Delivery Info Card
            // Inside your Column children:
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "👤 Дэлгүүр: ${delivery!['merchant']?['username'] + ' 📞 ' + delivery!['merchant']?['phone'] ?? 'N/A' ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📞 Утас: ${delivery!['phone'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "📍 Хаяг: ${delivery!['address'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "⏰ Цаг: ${formatDate(delivery!['createdAt'] ?? '')}",
                      style: GoogleFonts.rubik(
                          fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "🚚 Төлөв: ${delivery!['status_name']?['status'] ?? 'N/A'}",
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "💰 Үнэ: ${delivery!['price']?.toString() ?? '0'}₮",
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

            ),

            SizedBox(height: 24),
            // Static items section
            if (items.isNotEmpty) ...[
              Text(
                "📦 Бараанууд",
                style: GoogleFonts.rubik(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final name = item['good']?['name'] ?? 'Нэргүй бараа';
                final qty = item['quantity'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.toString(),
                        style: GoogleFonts.rubik(fontSize: 14),
                      ),
                      Text(
                        "Тоо: $qty",
                        style: GoogleFonts.rubik(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList()
            ],
            const SizedBox(height: 24),
            // Action Buttons
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _actionButton("Хүргэсэн", Icons.check_circle, Colors.green,
                    () async {
                  commentController.text = '';
                  _deliveryImage = null;
                  _showDeliveredSheet();
                }),
                _actionButton("Цуцалсан", Icons.cancel, Colors.red, () async {
                  selectedStatusId = 4;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Утсаар ярих", Icons.phone, Colors.indigo, () {
                  final phone = delivery?['phone'] ?? '';
                  if (phone.isNotEmpty) {
                    _callPhoneNumber(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Утасны дугаар олдсонгүй')));
                  }
                }),
                _actionButton("Хаягаар очсон", Icons.camera_alt, Colors.orange, () {
                  selectedStatusId = 5;
                  commentController.text = '';
                  _showPostponeSheet();
                }),
                _actionButton("Дараа авна", Icons.map, Colors.teal, () {
                  selectedStatusId = 6;
                  commentController.text = '';
                  selectedDeliveryDate = null;
                  _showPostponeSheet();
                }),
              ],
            )
          ],
        ),
      ),
    );
  }
  void _showPostponeSheet() {
    final isPostpone = selectedStatusId == 6;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(isPostpone ? 'Дараа авна - Огноо сонгох' : 'Тайлбар нэмэх',
                      style: GoogleFonts.rubik(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  // Date picker for postpone (status 6)
                  if (isPostpone) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDeliveryDate == null
                                ? 'Огноо сонгох'
                                : '${selectedDeliveryDate!.year}-${selectedDeliveryDate!.month.toString().padLeft(2, '0')}-${selectedDeliveryDate!.day.toString().padLeft(2, '0')}',
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              color: selectedDeliveryDate == null
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.calendar_today, color: Colors.teal),
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors.teal,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: Colors.black87,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDeliveryDate = picked;
                                });
                                setModalState(() {}); // Update modal UI
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Тайлбар',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (isPostpone) {
                              selectedDeliveryDate = null;
                            }
                            Navigator.pop(context);
                          },
                          child: const Text('Болих'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            // Validate date selection for postpone
                            if (isPostpone && selectedDeliveryDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Огноо сонгох шаардлагатай'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            await _submitPostpone();
                            if (mounted) Navigator.pop(context);
                          },
                          child: Text('Хадгалах',
                              style: GoogleFonts.rubik(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeliveredSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Хүргэлт хийх',
                      style: GoogleFonts.rubik(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Тайлбар *',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Image picker section
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _showImageSourceDialog(setModalState);
                          },
                          icon: Icon(Icons.camera_alt),
                          label: Text(_deliveryImage != null 
                              ? 'Зураг сонгосон' 
                              : 'Зураг авах (сонголттой)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _deliveryImage != null 
                                ? Colors.green 
                                : Colors.grey.shade700,
                            side: BorderSide(
                              color: _deliveryImage != null 
                                  ? Colors.green 
                                  : Colors.grey.shade400,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_deliveryImage != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _deliveryImage = null;
                            });
                            setModalState(() {}); // Update modal UI
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _deliveryImage = null;
                            Navigator.pop(context);
                          },
                          child: const Text('Болих'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            // Validate comment requirement
                            if (commentController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Тайлбар оруулах шаардлагатай'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            
                            if (mounted) Navigator.pop(context);
                            final confirmed = await showConfirmationDialog(
                                context, 'Та итгэлтэй байна уу?');
                            if (confirmed == true) {
                              await _markAsDelivered();
                            }
                          },
                          child: Text('Хүргэх',
                              style: GoogleFonts.rubik(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        textStyle: GoogleFonts.rubik(fontSize: 11),
      ),
    );
  }

  Future<bool?> showConfirmationDialog(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange),
              SizedBox(width: 8),
              Text(
                'Анхааруулга',
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.rubik(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          actions: [
            TextButton.icon(
              icon: Icon(Icons.close, color: Colors.red),
              label: Text(
                'Үгүй',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton.icon(
              icon: Icon(Icons.check_circle, color: Colors.green),
              label: Text(
                'Тийм',
                style: GoogleFonts.rubik(
                  fontSize: 14,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      developer.log('[IMAGE_COMPRESS] Starting image compression', name: 'DeliveryDetail');
      developer.log('[IMAGE_COMPRESS] Original file path: ${imageFile.path}', name: 'DeliveryDetail');
      final originalSize = await imageFile.length();
      developer.log('[IMAGE_COMPRESS] Original file size: $originalSize bytes', name: 'DeliveryDetail');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Compress and resize image
      // Max width/height: 1280px (will scale down if larger), quality: 70, format: jpeg
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        minWidth: 1280,
        minHeight: 1280,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      
      if (compressedFile != null) {
        final compressedSize = await compressedFile.length();
        developer.log('[IMAGE_COMPRESS] Compressed file path: ${compressedFile.path}', name: 'DeliveryDetail');
        developer.log('[IMAGE_COMPRESS] Compressed file size: $compressedSize bytes', name: 'DeliveryDetail');
        developer.log('[IMAGE_COMPRESS] Compression ratio: ${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%', name: 'DeliveryDetail');
        return File(compressedFile.path);
      } else {
        developer.log('[IMAGE_COMPRESS] Compression returned null, using original file', name: 'DeliveryDetail');
        return imageFile;
      }
    } catch (e, stackTrace) {
      developer.log('[IMAGE_COMPRESS] Error compressing image: $e', name: 'DeliveryDetail', error: e, stackTrace: stackTrace);
      // Return original file if compression fails
      return imageFile;
    }
  }

  Future<void> _showImageSourceDialog(StateSetter setModalState) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.blue),
                title: Text('Камераар зураг авах'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera, setModalState);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.green),
                title: Text('Галерейноос сонгох'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery, setModalState);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, StateSetter? setModalState) async {
    developer.log('[IMAGE_PICK] Starting image pick process', name: 'DeliveryDetail');
    try {
      developer.log('[IMAGE_PICK] Calling ImagePicker.pickImage with source: $source', name: 'DeliveryDetail');
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      developer.log('[IMAGE_PICK] ImagePicker returned: ${image != null ? "Image selected" : "null"}', name: 'DeliveryDetail');
      
      if (image != null) {
        developer.log('[IMAGE_PICK] Image path: ${image.path}', name: 'DeliveryDetail');
        developer.log('[IMAGE_PICK] Image name: ${image.name}', name: 'DeliveryDetail');
        developer.log('[IMAGE_PICK] Image size: ${image.length()} bytes', name: 'DeliveryDetail');
        
        final file = File(image.path);
        final fileExists = await file.exists();
        developer.log('[IMAGE_PICK] File exists: $fileExists', name: 'DeliveryDetail');
        
        if (fileExists) {
          final fileSize = await file.length();
          developer.log('[IMAGE_PICK] Original file size: $fileSize bytes', name: 'DeliveryDetail');
          
          // Compress and resize the image
          final compressedFile = await _compressImage(file);
          if (compressedFile != null) {
            final compressedSize = await compressedFile.length();
            developer.log('[IMAGE_PICK] Compressed file size: $compressedSize bytes', name: 'DeliveryDetail');
            
            setState(() {
              _deliveryImage = compressedFile;
            });
            if (setModalState != null) {
              setModalState(() {}); // Update modal UI
            }
            developer.log('[IMAGE_PICK] Compressed image successfully set in state', name: 'DeliveryDetail');
          } else {
            setState(() {
              _deliveryImage = file;
            });
            if (setModalState != null) {
              setModalState(() {}); // Update modal UI
            }
            developer.log('[IMAGE_PICK] Using original image (compression failed)', name: 'DeliveryDetail');
          }
        }
      } else {
        developer.log('[IMAGE_PICK] No image selected by user', name: 'DeliveryDetail');
      }
    } catch (e, stackTrace) {
      developer.log('[IMAGE_PICK] Error picking image: $e', name: 'DeliveryDetail', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Зургийн алдаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _markAsDelivered() async {
    developer.log('[DELIVERY_COMPLETE] Starting mark as delivered process', name: 'DeliveryDetail');
    
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    developer.log('[DELIVERY_COMPLETE] User ID: $userId', name: 'DeliveryDetail');
    
    developer.log('[DELIVERY_COMPLETE] Current delivery image state: ${_deliveryImage != null ? "Image exists" : "No image"}', name: 'DeliveryDetail');
    
    final url = Uri.parse(Url.url + '/api/mobile/delivery/complete/${delivery!['id']}');
    developer.log('[DELIVERY_COMPLETE] Request URL: $url', name: 'DeliveryDetail');
    developer.log('[DELIVERY_COMPLETE] Delivery ID: ${delivery!['id']}', name: 'DeliveryDetail');
    
    try {
      http.Response response;
      
      if (_deliveryImage != null) {
        developer.log('[DELIVERY_COMPLETE] Preparing multipart request with image', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Image path: ${_deliveryImage!.path}', name: 'DeliveryDetail');
        
        // Verify file exists before sending
        final fileExists = await _deliveryImage!.exists();
        developer.log('[DELIVERY_COMPLETE] Image file exists: $fileExists', name: 'DeliveryDetail');
        
        if (!fileExists) {
          developer.log('[DELIVERY_COMPLETE] ERROR: Image file does not exist at path: ${_deliveryImage!.path}', name: 'DeliveryDetail');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Зурагны файл олдсонгүй'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        final fileSize = await _deliveryImage!.length();
        developer.log('[DELIVERY_COMPLETE] Image file size: $fileSize bytes', name: 'DeliveryDetail');
        
        // Send multipart request with image
        var request = http.MultipartRequest('POST', url);
        request.fields['status'] = '3';
        request.fields['driver_comment'] = commentController.text.trim();
        developer.log('[DELIVERY_COMPLETE] Added status field: 3', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Added driver_comment field', name: 'DeliveryDetail');
        
        // Add image file
        developer.log('[DELIVERY_COMPLETE] Creating MultipartFile from path...', name: 'DeliveryDetail');
        try {
          // Determine content type from file extension
          final fileExtension = _deliveryImage!.path.split('.').last.toLowerCase();
          final contentType = fileExtension == 'jpg' || fileExtension == 'jpeg'
              ? MediaType('image', 'jpeg')
              : fileExtension == 'png'
                  ? MediaType('image', 'png')
                  : MediaType('image', 'jpeg'); // Default to jpeg
          
          developer.log('[DELIVERY_COMPLETE] File extension: $fileExtension', name: 'DeliveryDetail');
          developer.log('[DELIVERY_COMPLETE] Content type: ${contentType.toString()}', name: 'DeliveryDetail');
          
          final multipartFile = await http.MultipartFile.fromPath(
            'delivery_image',
            _deliveryImage!.path,
            contentType: contentType,
          );
          developer.log('[DELIVERY_COMPLETE] MultipartFile created successfully', name: 'DeliveryDetail');
          developer.log('[DELIVERY_COMPLETE] MultipartFile field name: ${multipartFile.field}', name: 'DeliveryDetail');
          developer.log('[DELIVERY_COMPLETE] MultipartFile filename: ${multipartFile.filename}', name: 'DeliveryDetail');
          developer.log('[DELIVERY_COMPLETE] MultipartFile length: ${multipartFile.length}', name: 'DeliveryDetail');
          developer.log('[DELIVERY_COMPLETE] MultipartFile content type: ${multipartFile.contentType}', name: 'DeliveryDetail');
          
          request.files.add(multipartFile);
          developer.log('[DELIVERY_COMPLETE] MultipartFile added to request', name: 'DeliveryDetail');
        } catch (e, stackTrace) {
          developer.log('[DELIVERY_COMPLETE] ERROR creating MultipartFile: $e', name: 'DeliveryDetail', error: e, stackTrace: stackTrace);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Зураг бэлтгэхэд алдаа гарлаа: $e'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        developer.log('[DELIVERY_COMPLETE] Sending multipart request...', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Request fields: ${request.fields}', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Request files count: ${request.files.length}', name: 'DeliveryDetail');
        
        final streamedResponse = await request.send();
        developer.log('[DELIVERY_COMPLETE] StreamedResponse received, status code: ${streamedResponse.statusCode}', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] StreamedResponse headers: ${streamedResponse.headers}', name: 'DeliveryDetail');
        
        response = await http.Response.fromStream(streamedResponse);
        developer.log('[DELIVERY_COMPLETE] Response body length: ${response.body.length}', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Response body: ${response.body}', name: 'DeliveryDetail');
      } else {
        developer.log('[DELIVERY_COMPLETE] No image selected, sending JSON request', name: 'DeliveryDetail');
        // Send regular JSON request without image
        response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'status': 3,
            'driver_comment': commentController.text.trim(),
          }),
        );
        developer.log('[DELIVERY_COMPLETE] JSON request sent, status code: ${response.statusCode}', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Response body: ${response.body}', name: 'DeliveryDetail');
      }

      developer.log('[DELIVERY_COMPLETE] Final response status code: ${response.statusCode}', name: 'DeliveryDetail');
      
      if (response.statusCode == 200) {
        developer.log('[DELIVERY_COMPLETE] Response status is 200, parsing JSON...', name: 'DeliveryDetail');
        final data = jsonDecode(response.body);
        developer.log('[DELIVERY_COMPLETE] Parsed response data: $data', name: 'DeliveryDetail');
        
        if (data['success'] == true) {
          developer.log('[DELIVERY_COMPLETE] Success! Delivery marked as completed', name: 'DeliveryDetail');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Хүргэлт амжилттай хүргэгдлээ'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to MainScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(id: userId!),
            ),
          );
        } else {
          developer.log('[DELIVERY_COMPLETE] Response success is false: ${data['message']}', name: 'DeliveryDetail');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['message'] ?? 'Алдаа гарлаа'),
                backgroundColor: Colors.red),
          );
        }
      } else {
        developer.log('[DELIVERY_COMPLETE] ERROR: Response status code is not 200: ${response.statusCode}', name: 'DeliveryDetail');
        developer.log('[DELIVERY_COMPLETE] Response body: ${response.body}', name: 'DeliveryDetail');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Сервертэй холбогдож чадсангүй (Status: ${response.statusCode})'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e, stackTrace) {
      developer.log('[DELIVERY_COMPLETE] EXCEPTION: $e', name: 'DeliveryDetail', error: e, stackTrace: stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

}
