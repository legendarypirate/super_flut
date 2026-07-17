import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/customer_driver/cust_dashboard.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../deliverydriver/createDelivery.dart';
import '../screen/login.dart';
import '../deliverydriver/createDelivery.dart';

class DeliveryItem {
  final int id;
  final int quantity;
  final int? goodId;
  final String? goodName;

  DeliveryItem({
    required this.id,
    required this.quantity,
    this.goodId,
    this.goodName,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      id: json['id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      goodId: json['good_id'],
      goodName: json['good'] != null ? json['good']['name'] : null,
    );
  }
}

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  final DateTime? deliveryDate; // Delivery date for filtering
  String comment;
  final String address;
  final String? driverComment;
  final String? color; // Make color nullable since it might not come from API
  final DateTime updatedAt;
  final double price;
  final List<DeliveryItem> items;
  List<String> possibleStatuses;

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    this.deliveryDate, // Optional delivery date
    required this.comment,
    required this.address,
    this.driverComment,
    this.color, // Make color optional
    required this.updatedAt,
    required this.price,
    this.items = const [],
    this.possibleStatuses = const [
      "шинэ",
      "жолоочид",
      "хүргэгдсэн",
      "цуцалсан",
      "хаягаар очсон",
      "дараа авна",
      "маргааш авна",
      "утсаа аваагүй"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    // Handle phone field - convert to string if it's int
    String phone = '';
    if (json['phone'] != null) {
      phone = json['phone'].toString();
    }

    // Handle status field - if it's int, map to Mongolian text; if string, use as is
    String status = 'шинэ';
    if (json['status'] != null) {
      if (json['status'] is int) {
        // Map integer status to Mongolian text based on your actual backend IDs
        status = _statusFromCode(json['status']);
      } else {
        status = json['status'].toString();
      }
    }

    // Handle comment field - convert to string if it's int or null
    String comment = '';
    if (json['comment'] != null) {
      comment = json['comment'].toString();
    }

    // Handle address field - convert to string if it's int or null
    String address = '';
    if (json['address'] != null) {
      address = json['address'].toString();
    }

    // Handle driver_comment field
    String? driverComment;
    if (json['driver_comment'] != null) {
      driverComment = json['driver_comment'].toString();
    } else if (json['driverComment'] != null) {
      driverComment = json['driverComment'].toString();
    }

    // Handle color field - might not be present in delivery data
    String? color;
    if (json['color'] != null) {
      color = json['color'].toString();
    }

    // Handle price field
    double price = 0.0;
    if (json['price'] != null) {
      if (json['price'] is num) {
        price = json['price'].toDouble();
      } else {
        price = double.tryParse(json['price'].toString()) ?? 0.0;
      }
    }

    // Handle items field
    List<DeliveryItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((item) => DeliveryItem.fromJson(item))
          .toList();
    }

    // Handle delivery_date field
    DateTime? deliveryDate;
    if (json['delivery_date'] != null && json['delivery_date'].toString().isNotEmpty) {
      try {
        deliveryDate = DateTime.parse(json['delivery_date']);
      } catch (e) {
        print('Error parsing delivery_date: $e');
      }
    }

    return Delivery(
      id: json['id'] ?? 0,
      phone: phone,
      status: status,
      createdDate: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      deliveryDate: deliveryDate, // Include delivery_date
      comment: comment,
      address: address,
      driverComment: driverComment,
      color: color, // Can be null
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      price: price,
      items: items,
    );
  }

  // Map integer status codes to Mongolian status names based on your actual backend
  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "шинэ";
      case 2:
        return "жолоочид";
      case 3:
        return "хүргэгдсэн";
      case 4:
        return "цуцалсан";
      case 6:
        return "дараа авна";
      case 7:
        return "утсаа аваагүй";
      case 8:
        return "маргааш авна";
      default:
        return "шинэ";
    }
  }

  // Convert Mongolian status back to integer code for API calls
  static int _codeFromStatus(String status) {
    switch (status) {
      case "шинэ":
        return 1;
      case "жолоочид":
        return 2;
      case "хүргэгдсэн":
        return 3;
      case "цуцалсан":
        return 4;
      case "утсаа аваагүй":
        return 7;
      case "хаягаар очсон":
        return 5;
      case "дараа авна":
        return 6;
      case "маргааш авна":
        return 8;
      default:
        return 1;
    }
  }

  // Get status code for API calls
  int get statusCode => _codeFromStatus(status);
}

class DeliveryCustomer extends StatefulWidget {
  @override
  _DeliveryCustomerState createState() => _DeliveryCustomerState();
}

class _DeliveryCustomerState extends State<DeliveryCustomer> {
  List<Delivery> deliveries = [];
  List<Delivery> filteredDeliveries = []; // Filtered deliveries for display
  int? expandedIndex;
  bool isLoading = true;
  DateTime? startDate; // Date range filter start
  DateTime? endDate; // Date range filter end
  TextEditingController phoneFilterController = TextEditingController(); // Phone filter controller

  // Statuses from your backend (in Mongolian)
  List<String> statuses = [
    "шинэ",
    "жолоочид",
    "хүргэгдсэн",
    "буцаасан",
    "хаягаар очсон",
    "дараа авна",
    "маргааш авна",
    "утсаа аваагүй"
  ];

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/merchant?user_id=$userId');
    print(url);
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        setState(() {
          deliveries = data.map((item) => Delivery.fromJson(item)).toList();
          _applyFilters(); // Apply filters after fetching
          isLoading = false;
        });
        print('Fetched ${deliveries.length} deliveries');
        // Debug: print first delivery to see the status mapping
        if (deliveries.isNotEmpty) {
          print('First delivery status: ${deliveries[0].status}');
          print('First delivery color: ${deliveries[0].color}');
        }
      } else {
        print('Error: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = filteredDeliveries[index];
    final url =
    Uri.parse(Url.url + '/api/mobile/delivery/${delivery.id}/status');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': Delivery._codeFromStatus(newStatus)}),
      );

      if (response.statusCode == 200) {
        setState(() {
          delivery.status = newStatus;
          expandedIndex = null;
          _applyFilters(); // Reapply filter after status update
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус амжилттай шинэчлэгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to update status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус шинэчлэхэд алдаа гарлаа'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "шинэ":
        return Colors.amber[700]!; // Darker amber
      case "жолоочид":
        return Colors.blue;
      case "хүргэгдсэн":
        return Colors.green;
      case "цуцалсан":
        return Colors.red;
      case "хаягаар очсон":
        return Colors.indigo;
      case "дараа авна":
        return Colors.brown;
      case "маргааш авна":
        return Colors.cyan;
      case "утсаа аваагүй":
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  // Date range picker method
  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF204a35),
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
        startDate = picked.start;
        endDate = picked.end;
        _applyFilters();
      });
    }
  }

  // Clear date filter
  void _clearDateFilter() {
    setState(() {
      startDate = null;
      endDate = null;
      _applyFilters();
    });
  }

  // Clear phone filter
  void _clearPhoneFilter() {
    setState(() {
      phoneFilterController.clear();
      _applyFilters();
    });
  }

  // Apply combined filters (date and phone) to deliveries
  void _applyFilters() {
    List<Delivery> filtered = List.from(deliveries);

    // Apply date filter if dates are set
    if (startDate != null && endDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);

      filtered = filtered.where((delivery) {
        final dateToFilter = delivery.deliveryDate ?? delivery.createdDate;
        return dateToFilter.isAfter(start.subtract(Duration(seconds: 1))) &&
            dateToFilter.isBefore(end.add(Duration(seconds: 1)));
      }).toList();
    }

    // Apply phone filter if phone filter text is not empty
    if (phoneFilterController.text.isNotEmpty) {
      final phoneQuery = phoneFilterController.text.toLowerCase().trim();
      filtered = filtered.where((delivery) {
        return delivery.phone.toLowerCase().contains(phoneQuery);
      }).toList();
    }

    setState(() {
      filteredDeliveries = filtered;
    });
  }

  @override
  void initState() {
    super.initState();
    phoneFilterController.addListener(_applyFilters); // Listen to phone filter changes
    fetchDeliveries();
  }

  @override
  void dispose() {
    phoneFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.dashboard, color: Colors.white),
          tooltip: 'Dashboard',
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => CustDashboard()));
          },
        ),
        title: Text(
          'Хүргэлт',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Color(0xFF204a35),
        actions: [
          // Date filter button
          IconButton(
            icon: Icon(
              startDate != null && endDate != null 
                  ? Icons.filter_alt 
                  : Icons.filter_alt_outlined,
              color: startDate != null && endDate != null 
                  ? Colors.orange 
                  : Colors.white,
            ),
            onPressed: _pickDateRange,
            tooltip: 'Огноогоор шүүх',
          ),
          // Clear date filter button (only show when filter is active)
          if (startDate != null && endDate != null)
            IconButton(
              icon: Icon(Icons.clear_all, color: Colors.white),
              onPressed: _clearDateFilter,
              tooltip: 'Огнооны шүүлтийг цэвэрлэх',
            ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              fetchDeliveries();
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => Login()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Phone filter search bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[50],
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: phoneFilterController,
              builder: (context, value, child) {
                return TextField(
                  controller: phoneFilterController,
                  decoration: InputDecoration(
                    hintText: 'Утасны дугаараар хайх...',
                    hintStyle: GoogleFonts.rubik(fontSize: 14),
                    prefixIcon: Icon(Icons.phone, color: Color(0xFF204a35)),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: _clearPhoneFilter,
                            tooltip: 'Утасны шүүлтийг цэвэрлэх',
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: GoogleFonts.rubik(fontSize: 14),
                );
              },
            ),
          ),
          // Filter info display
          if (startDate != null && endDate != null)
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Шүүсэн хүргэлт: ${filteredDeliveries.length} / ${deliveries.length}',
                          style: GoogleFonts.rubik(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(startDate!)} - ${DateFormat('yyyy-MM-dd').format(endDate!)}',
                          style: GoogleFonts.rubik(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: _clearDateFilter,
                    tooltip: 'Шүүлтийг цэвэрлэх',
                  ),
                ],
              ),
            ),
          Expanded(
            child: deliveries.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Хүргэлт олдсонгүй',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : filteredDeliveries.isEmpty && (startDate != null && endDate != null || phoneFilterController.text.isNotEmpty)
                    ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_off, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Хүргэлт олдсонгүй',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (startDate != null && endDate != null)
                        TextButton(
                          onPressed: _clearDateFilter,
                          child: Text(
                            'Огнооны шүүлтийг цэвэрлэх',
                            style: GoogleFonts.rubik(color: Color(0xFF204a35)),
                          ),
                        ),
                      if (phoneFilterController.text.isNotEmpty)
                        TextButton(
                          onPressed: _clearPhoneFilter,
                          child: Text(
                            'Утасны шүүлтийг цэвэрлэх',
                            style: GoogleFonts.rubik(color: Color(0xFF204a35)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filteredDeliveries.length,
              itemBuilder: (context, index) {
                final delivery = filteredDeliveries[index];
          final isExpanded = expandedIndex == index;

          return InkWell(
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => DeliveryDetailScreen(delivery: delivery),
              //   ),
              // );
            },
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status and Phone row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status badge - FIXED: Use getStatusColor method
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              expandedIndex = isExpanded ? null : index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: getStatusColor(delivery.status), // Use the method here
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              delivery.status,
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          delivery.phone,
                          style: GoogleFonts.rubik(
                              color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),

                    // Status selection chips (only when expanded)
                    if (isExpanded) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Статус солих:',
                        style: GoogleFonts.rubik(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: statuses.map((status) {
                          final selected = status == delivery.status;
                          return ChoiceChip(
                            label: Text(
                              status,
                              style: GoogleFonts.rubik(
                                fontSize: 11,
                                color: selected
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            selected: selected,
                            selectedColor: getStatusColor(status), // Use the method here too
                            onSelected: (selected) {
                              if (selected) {
                                updateStatus(index, status);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Driver Comment Tag - Only show if driver comment exists
                    if (delivery.driverComment != null &&
                        delivery.driverComment!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.drive_eta,
                              color: Colors.purple,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "Жолоочийн тайлбар: ${delivery.driverComment!}",
                                style: GoogleFonts.rubik(
                                  fontSize: 11,
                                  color: Colors.purple[800],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Price and Created Date in same row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: Colors.green[700],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Үнэ: ${delivery.price.toStringAsFixed(0)}₮',
                                style: GoogleFonts.rubik(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Created Date
                        Text(
                          'Үүссэн: ${formatDate(delivery.createdDate)}',
                          style: GoogleFonts.rubik(
                              color: Colors.grey[700], fontSize: 11),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Comment
                    if (delivery.comment.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Тайлбар:',
                            style: GoogleFonts.rubik(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            delivery.comment,
                            style: GoogleFonts.rubik(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),

                    if (delivery.comment.isNotEmpty) const SizedBox(height: 10),

                    // Items list
                    if (delivery.items.isNotEmpty) ...[
                      Text(
                        'Бараа:',
                        style: GoogleFonts.rubik(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...delivery.items.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.goodName ?? 'Барааны нэр олдсонгүй',
                                  style: GoogleFonts.rubik(
                                    fontSize: 11,
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${item.quantity}ш',
                                  style: GoogleFonts.rubik(
                                    fontSize: 10,
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 10),
                    ],

                    // Address
                    Text(
                      'Хаяг: ${delivery.address}',
                      style: GoogleFonts.rubik(
                        fontSize: 11,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateDelivery()),
          ).then((_) {
            // Refresh the list when returning from CreateDelivery
            fetchDeliveries();
          });
        },
        backgroundColor: Color(0xFF204a35),
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'Шинэ хүргэлт нэмэх',
      ),
    );
  }
}