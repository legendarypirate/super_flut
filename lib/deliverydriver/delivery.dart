import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sura_driver/deliverydriver/detaildelivery.dart';
import 'package:http/http.dart' as http;

import '../color/color.dart';
import '../screen/login.dart';
import 'dashboard.dart';

class Delivery {
  final int id;
  final String phone;
  String status;
  final DateTime createdDate;
  DateTime? deliveryDate; // 🔹 Delivery date for filtering
  String comment;
  String price;
  final String address;
  final String? driverComment;
  List<String> possibleStatuses;
  final String merchantUsername;
  String? selectedColor; // 🔹 New property for color tag

  Delivery({
    required this.id,
    required this.phone,
    required this.status,
    required this.createdDate,
    this.deliveryDate, // 🔹 Optional delivery date
    required this.comment,
    required this.price,
    required this.address,
    this.driverComment,
    required this.merchantUsername,
    this.selectedColor, // 🔹 Initialize with null (no color)
    this.possibleStatuses = const [
      "Pending",
      "In Transit",
      "Delivered",
      "Cancelled"
    ],
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    // Parse delivery_date if available
    DateTime? deliveryDate;
    if (json['delivery_date'] != null && json['delivery_date'].toString().isNotEmpty) {
      try {
        // Handle both date-only (YYYY-MM-DD) and datetime formats
        String dateStr = json['delivery_date'].toString();
        if (dateStr.length == 10) {
          // Date-only format, add time
          dateStr = '${dateStr}T00:00:00';
        }
        deliveryDate = DateTime.parse(dateStr);
      } catch (e) {
        print('Error parsing delivery_date: $e');
      }
    }

    String? driverComment;
    if (json['driver_comment'] != null &&
        json['driver_comment'].toString().trim().isNotEmpty) {
      driverComment = json['driver_comment'].toString();
    } else if (json['driverComment'] != null &&
        json['driverComment'].toString().trim().isNotEmpty) {
      driverComment = json['driverComment'].toString();
    }

    return Delivery(
      id: json['id'],
      phone: json['phone'],
      status: _statusFromCode(json['status']),
      createdDate: DateTime.parse(json['createdAt']),
      deliveryDate: deliveryDate, // 🔹 Include delivery_date
      comment: json['comment'] ?? '',
      address: json['address'],
      driverComment: driverComment,
      merchantUsername: json['merchant']?['username'] ?? '-',
      price: json['price'],
    );
  }

  static String _statusFromCode(int statusCode) {
    switch (statusCode) {
      case 1:
        return "Pending";
      case 2:
        return "Жолоочид";
      case 3:
        return "Delivered";
      case 4:
        return "Cancelled";
      default:
        return "Unknown";
    }
  }

  static int _codeFromStatus(String status) {
    switch (status) {
      case "Pending":
        return 1;
      case "Жолоочид":
        return 2;
      case "Delivered":
        return 3;
      case "Cancelled":
        return 4;
      default:
        return 0;
    }
  }

  int get statusCode => _codeFromStatus(status);
}

class DeliveryListScreen extends StatefulWidget {
  @override
  _DeliveryListScreenState createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> {
  List<Delivery> deliveries = [];
  List<Delivery> filteredDeliveries = []; // 🔹 Filtered deliveries for display
  bool isLoading = true;
  Set<int> selectedDeliveries = Set<int>(); // 🔹 Track selected deliveries
  bool isSelectionMode = false; // 🔹 Selection mode state
  DateTime? startDate; // 🔹 Date range filter start
  DateTime? endDate; // 🔹 Date range filter end

  // Available colors for tagging
  final List<Map<String, dynamic>> availableColors = [
    {'name': 'blue', 'color': Colors.blue[100]!, 'border': Colors.blue},
    {'name': 'green', 'color': Colors.green[100]!, 'border': Colors.green},
    {'name': 'orange', 'color': Colors.orange[100]!, 'border': Colors.orange},
  ];

  List<String> statuses = [
    'Pending',
    'Жолоочид',
    'Delivered',
    'Cancelled',
  ];

  // Load color tags from SharedPreferences
  Future<Map<int, String>> _loadColorTags() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? colorTagsJson = prefs.getString('delivery_color_tags');
    if (colorTagsJson != null) {
      Map<String, dynamic> tagsMap = json.decode(colorTagsJson);
      return tagsMap.map((key, value) => MapEntry(int.parse(key), value.toString()));
    }
    return {};
  }

  // Save color tags to SharedPreferences
  Future<void> _saveColorTags(Map<int, String> colorTags) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, String> tagsMap = colorTags.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString('delivery_color_tags', json.encode(tagsMap));
  }

  // Apply color to selected deliveries
  Future<void> _applyColorToSelected(String colorName) async {
    Map<int, String> colorTags = await _loadColorTags();

    for (int deliveryId in selectedDeliveries) {
      colorTags[deliveryId] = colorName;
    }

    await _saveColorTags(colorTags);

    // Update local state
    setState(() {
      for (var delivery in deliveries) {
        if (selectedDeliveries.contains(delivery.id)) {
          delivery.selectedColor = colorName;
        }
      }
      selectedDeliveries.clear();
      isSelectionMode = false;
    });
  }

  // Get background color for delivery
  Color _getDeliveryBackgroundColor(Delivery delivery) {
    if (selectedDeliveries.contains(delivery.id)) {
      return Colors.grey[300]!; // Grey background for selected items
    }

    if (delivery.selectedColor != null) {
      final colorConfig = availableColors.firstWhere(
            (color) => color['name'] == delivery.selectedColor,
        orElse: () => availableColors[0],
      );
      return colorConfig['color'];
    }

    return Colors.white; // Default background
  }

  // Get border color for delivery
  Color _getDeliveryBorderColor(Delivery delivery) {
    if (delivery.selectedColor != null) {
      final colorConfig = availableColors.firstWhere(
            (color) => color['name'] == delivery.selectedColor,
        orElse: () => availableColors[0],
      );
      return colorConfig['border'];
    }

    return Colors.grey[300]!; // Default border
  }

  Future<void> saveOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> order = deliveries.map((d) => d.id.toString()).toList();
    await prefs.setStringList('delivery_order', order);
  }

  Future<void> loadOrderLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedOrder = prefs.getStringList('delivery_order');
    if (savedOrder != null && deliveries.isNotEmpty) {
      deliveries.sort((a, b) {
        int indexA = savedOrder.indexOf(a.id.toString());
        int indexB = savedOrder.indexOf(b.id.toString());
        if (indexA == -1) indexA = deliveries.length;
        if (indexB == -1) indexB = deliveries.length;
        return indexA.compareTo(indexB);
      });
    }
  }

  Future<void> fetchDeliveries() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userId = prefs.getInt('user_id');
    
    // Build URL with date filter query parameters if active
    String query = '';
    if (startDate != null && endDate != null) {
      final DateFormat formatter = DateFormat('yyyy-MM-dd');
      query = '?startDate=${formatter.format(startDate!)}&endDate=${formatter.format(endDate!)}';
    }
    
    final url = Uri.parse(Url.url + '/api/mobile/delivery/driver/$userId/status-2$query');
    print('Fetching deliveries from: $url (filtered by delivery_date)');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List data = jsonResponse['data'];

        // Load color tags
        Map<int, String> colorTags = await _loadColorTags();

        // Assign without setState so we never paint API order
        deliveries = data.map((item) {
          final delivery = Delivery.fromJson(item);
          delivery.selectedColor = colorTags[delivery.id];
          return delivery;
        }).toList();
        filteredDeliveries = List.from(deliveries);

        await loadOrderLocally(); // Apply saved order (sorts deliveries in place)
        _applyDateFilter();       // Sync filteredDeliveries with sorted order
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Failed to load deliveries: $e');
    } finally {
      if (mounted) setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int index, String newStatus) async {
    final delivery = deliveries[index];
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
        });
      } else {
        print('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating status: $e');
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'жолоочид':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  void _toggleDeliverySelection(int deliveryId) {
    setState(() {
      if (selectedDeliveries.contains(deliveryId)) {
        selectedDeliveries.remove(deliveryId);
      } else {
        selectedDeliveries.add(deliveryId);
      }

      // Enable selection mode if any items are selected
      isSelectionMode = selectedDeliveries.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      selectedDeliveries.clear();
      isSelectionMode = false;
    });
  }

  // 🔹 Date range picker method
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
        isLoading = true;
      });
      // Refetch deliveries with date filter from backend
      await fetchDeliveries();
    }
  }

  // 🔹 Clear date filter
  Future<void> _clearDateFilter() async {
    setState(() {
      startDate = null;
      endDate = null;
      isLoading = true;
    });
    // Refetch deliveries without date filter
    await fetchDeliveries();
  }

  // 🔹 Apply date filter to deliveries
  void _applyDateFilter() {
    if (startDate == null || endDate == null) {
      filteredDeliveries = List.from(deliveries);
      return;
    }

    // Set time to start of day for startDate and end of day for endDate
    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);

    filteredDeliveries = deliveries.where((delivery) {
      // Filter by delivery_date only (not createdDate)
      if (delivery.deliveryDate == null) {
        return false; // Exclude deliveries without delivery_date
      }
      final dateToFilter = delivery.deliveryDate!;
      return dateToFilter.isAfter(start.subtract(Duration(seconds: 1))) &&
          dateToFilter.isBefore(end.add(Duration(seconds: 1)));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    fetchDeliveries();
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
                context, MaterialPageRoute(builder: (_) => Dashboard()));
          },
        ),
        title: Text('Хүргэлт',
            style: GoogleFonts.rubik(color: Colors.white, fontSize: 13)),
        backgroundColor: Color(0xFF204a35),
        actions: [
          // 🔹 Date filter button
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
          // 🔹 Clear date filter button (only show when filter is active)
          if (startDate != null && endDate != null)
            IconButton(
              icon: Icon(Icons.clear_all, color: Colors.white),
              onPressed: _clearDateFilter,
              tooltip: 'Огнооны шүүлтийг цэвэрлэх',
            ),
          if (isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.clear, color: Colors.white),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
          ],
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
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
          // Selection info and color options
          if (isSelectionMode)
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.grey[50],
              child: Column(
                children: [
                  Text(
                    '${selectedDeliveries.length} хүргэлт сонгогдлоо',
                    style: GoogleFonts.rubik(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Өнгө сонгох:',
                    style: GoogleFonts.rubik(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: availableColors.map((colorConfig) {
                      return GestureDetector(
                        onTap: () => _applyColorToSelected(colorConfig['name']),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorConfig['color'],
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: colorConfig['border'],
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            color: colorConfig['border'],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                Text(
                  startDate != null && endDate != null
                      ? 'Шүүсэн хүргэлт: ${filteredDeliveries.length} / ${deliveries.length}'
                      : 'Нийт хүргэлт: ${deliveries.length}',
                  style: GoogleFonts.rubik(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (startDate != null && endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${DateFormat('yyyy-MM-dd').format(startDate!)} - ${DateFormat('yyyy-MM-dd').format(endDate!)}',
                      style: GoogleFonts.rubik(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: filteredDeliveries.isEmpty
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
                        if (startDate != null && endDate != null) ...[
                          SizedBox(height: 8),
                          TextButton(
                            onPressed: _clearDateFilter,
                            child: Text(
                              'Шүүлтийг цэвэрлэх',
                              style: GoogleFonts.rubik(color: Color(0xFF204a35)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = filteredDeliveries.removeAt(oldIndex);
                        filteredDeliveries.insert(newIndex, item);
                        
                        // Update the main deliveries list to match the filtered order
                        // Remove from main list
                        final deliveryId = item.id;
                        final mainIndex = deliveries.indexWhere((d) => d.id == deliveryId);
                        if (mainIndex != -1) {
                          deliveries.removeAt(mainIndex);
                          
                          // Insert at the correct position in main list
                          // Find the position based on the next item in filtered list
                          if (newIndex < filteredDeliveries.length - 1) {
                            final nextFilteredId = filteredDeliveries[newIndex + 1].id;
                            final nextMainIndex = deliveries.indexWhere((d) => d.id == nextFilteredId);
                            if (nextMainIndex != -1) {
                              deliveries.insert(nextMainIndex, item);
                            } else {
                              deliveries.add(item);
                            }
                          } else {
                            // If it's the last item in filtered list, add it at the end
                            deliveries.add(item);
                          }
                        }
                      });
                      saveOrderLocally(); // Save order after reordering
                    },
                    padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    children: [
                      for (int index = 0; index < filteredDeliveries.length; index++)
                        InkWell(
                          key: ValueKey(filteredDeliveries[index].id),
                          onTap: () {
                            if (isSelectionMode) {
                              _toggleDeliverySelection(filteredDeliveries[index].id);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DeliveryDetailScreen(
                                      deliveryId: filteredDeliveries[index].id),
                                ),
                              );
                            }
                          },
                          onDoubleTap: () {
                            _toggleDeliverySelection(filteredDeliveries[index].id);
                          },
                          child: Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: _getDeliveryBorderColor(filteredDeliveries[index]),
                                width: 2,
                              ),
                            ),
                            color: _getDeliveryBackgroundColor(filteredDeliveries[index]),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🔹 Title Row
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (selectedDeliveries.contains(filteredDeliveries[index].id))
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor(
                                              filteredDeliveries[index].status),
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          filteredDeliveries[index].status,
                                          style: GoogleFonts.rubik(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // 🔹 Phone Row
                                  Row(
                                    children: [
                                      const Icon(Icons.phone,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        filteredDeliveries[index].phone,
                                        style: GoogleFonts.rubik(
                                            color: Colors.grey[700],
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // 🔹 Created Date
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 14, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Үүссэн: ${formatDate(filteredDeliveries[index].createdDate)}',
                                        style: GoogleFonts.rubik(
                                            color: Colors.grey[700],
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),

                                  if (filteredDeliveries[index].driverComment !=
                                          null &&
                                      filteredDeliveries[index]
                                          .driverComment!
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              Colors.purple.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.drive_eta,
                                            color: Colors.purple,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Жолоочийн тайлбар: ${filteredDeliveries[index].driverComment!}',
                                              style: GoogleFonts.rubik(
                                                fontSize: 11,
                                                color: Colors.purple[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const Divider(height: 16, thickness: 0.5),

                                  // 🔹 Price
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Үнэ',
                                        style: GoogleFonts.rubik(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${filteredDeliveries[index].price}₮',
                                        style: GoogleFonts.rubik(
                                          color: Colors.orange,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // 🔹 Address
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.location_on,
                                          size: 14, color: Colors.redAccent),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          filteredDeliveries[index].address,
                                          style: GoogleFonts.rubik(
                                            fontSize: 12,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // 🔹 Color tag indicator
                                  if (filteredDeliveries[index].selectedColor != null)
                                    Container(
                                      margin: EdgeInsets.only(top: 8),
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: availableColors.firstWhere(
                                              (color) => color['name'] == filteredDeliveries[index].selectedColor,
                                          orElse: () => availableColors[0],
                                        )['border'].withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Өнгөтэй',
                                        style: GoogleFonts.rubik(
                                          fontSize: 10,
                                          color: availableColors.firstWhere(
                                                (color) => color['name'] == filteredDeliveries[index].selectedColor,
                                            orElse: () => availableColors[0],
                                          )['border'],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          )
        ],
      ),
      floatingActionButton: isSelectionMode
          ? FloatingActionButton(
        onPressed: _clearSelection,
        child: Icon(Icons.clear),
        backgroundColor: Colors.red,
      )
          : null,
    );
  }
}