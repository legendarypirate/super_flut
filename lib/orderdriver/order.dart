import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';
import 'detail.dart';

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = true;
  int? expandedIndex;
  int selectedStatus = 2; // Default to status 2 (Жолоочид хуваарилсан)

  // Status labels
  final Map<int, String> statusLabels = {
    1: 'Шинэ',
    2: 'Жолоочид хуваарилсан',
    3: 'Хүргэгдсэн',
    4: 'Буцаасан',
  };

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders({int? status}) async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? id = prefs.getInt('user_id');
    final statusToUse = status ?? selectedStatus;
    final url = Uri.parse(Url.url + '/api/mobile/order/driver/$id/status?status=$statusToUse');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'];

        setState(() {
          orders = data
              .map((item) => {
                    'id': item['id'],
                    'merchant': item['merchant']['username'],
                    'phone': item['phone'],
                    'address': item['address'],
                    'comment': item['comment'],
                    'status': item['status_text'],
                  })
              .toList();
          isLoading = false;
          selectedStatus = statusToUse;
        });
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      setState(() => isLoading = false);
    }
  }

  Color statusColor(String status) {
    // Map Mongolian status text to colors
    if (status.contains('Шинэ') || status.toLowerCase().contains('шинэ')) {
      return Colors.blue;
    } else if (status.contains('Жолоочид') || status.toLowerCase().contains('жолоочид')) {
      return Colors.orange;
    } else if (status.contains('Хүргэгдсэн') || status.toLowerCase().contains('хүргэгдсэн')) {
      return Colors.green;
    } else if (status.contains('Буцаасан') || status.toLowerCase().contains('буцаасан')) {
      return Colors.red;
    }
    return Colors.deepOrange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Orders',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: Color(0xFF204a35),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                Text(
                  'Төлөв: ',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: statusLabels.entries.map((entry) {
                        final status = entry.key;
                        final label = entry.value;
                        final isSelected = selectedStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              label,
                              style: GoogleFonts.rubik(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                fetchOrders(status: status);
                              }
                            },
                            selectedColor: Color(0xFF204a35),
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            side: BorderSide(
                              color: isSelected ? Color(0xFF204a35) : Colors.grey,
                              width: 1,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? Center(
                        child: Text('Хүргэлт алга',
                            style: GoogleFonts.rubik(fontSize: 14)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isExpanded = expandedIndex == index;

                    return InkWell(
                        onTap: () {
                          // Navigate to OrderDetailScreen, passing the order id
                          // Assuming your orders data has an 'id' field as well
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OrderDetailScreen(orderId: order['id']),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Merchant & Status Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      order['merchant'] ?? '',
                                      style: GoogleFonts.rubik(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor(order['status'] ?? ''),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        order['status'] ?? '',
                                        style: GoogleFonts.rubik(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                Text(order['address'] ?? '',
                                    style: GoogleFonts.rubik(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('📞 ${order['phone']}',
                                    style: GoogleFonts.rubik(fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('💬 ${order['comment']}',
                                    style: GoogleFonts.rubik(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ));
                  },
                ),
          ),
        ],
      ),
    );
  }
}
