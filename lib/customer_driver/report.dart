import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../color/color.dart';

/// One row of the merchant report (same fields as admin/report for role 2).
class ReportRowData {
  final String dateRange;
  final String name;
  final int deliveredDeliveries;
  final int totalDeliveries;
  final double totalPrice;
  final double salary;
  final int status5Deliveries;
  final int orderCount;

  ReportRowData({
    required this.dateRange,
    required this.name,
    required this.deliveredDeliveries,
    required this.totalDeliveries,
    required this.totalPrice,
    required this.salary,
    required this.status5Deliveries,
    required this.orderCount,
  });

  double get difference => totalPrice - salary;
}

class CustomerReport extends StatefulWidget {
  @override
  State<CustomerReport> createState() => _CustomerReportState();
}

class _CustomerReportState extends State<CustomerReport> {
  List<ReportRowData> _reportData = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _startDate = DateTime(n.year, n.month, n.day);
    _endDate = DateTime(n.year, n.month, n.day);
  }

  int _statusNum(Map<String, dynamic> d) {
    final s = d['status'];
    if (s == null) {
      final sn = d['status_name'];
      if (sn is Map && sn['id'] != null) {
        return int.tryParse(sn['id'].toString()) ?? -1;
      }
      return -1;
    }
    if (s is int) return s;
    if (s is num) return s.toInt();
    return int.tryParse(s.toString()) ?? -1;
  }

  bool _isStatus3(Map<String, dynamic> d) {
    final n = _statusNum(d);
    return n == 3;
  }

  bool _isStatus5(Map<String, dynamic> d) {
    final n = _statusNum(d);
    return n == 5;
  }

  double _parsePrice(dynamic p) =>
      double.tryParse(p?.toString() ?? '0') ?? 0;

  Map<String, List<Map<String, dynamic>>> _groupDeliveriesMerchant(
      List<Map<String, dynamic>> deliveries) {
    const key = 'merchant_summary';
    if (deliveries.isEmpty) return {};
    return {key: List<Map<String, dynamic>>.from(deliveries)};
  }

  Map<String, List<Map<String, dynamic>>> _groupOrdersMerchant(
      List<Map<String, dynamic>> orders) {
    const key = 'merchant_summary';
    if (orders.isEmpty) return {};
    return {key: List<Map<String, dynamic>>.from(orders)};
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final res = await http.get(Uri.parse(url), headers: headers);
    final body = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['message']?.toString() ?? 'HTTP ${res.statusCode}');
    }
    if (body['success'] == false) {
      throw Exception(body['message']?.toString() ?? 'Амжилтгүй');
    }
    return body;
  }

  Future<void> _loadReport() async {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    if (start.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Эхлэх огноо нь дуусах огнооноос хойш байж болохгүй',
                style: GoogleFonts.rubik())),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Хэрэглэгчийн мэдээлэл олдсонгүй',
                style: GoogleFonts.rubik())),
      );
      return;
    }

    final startStr =
        '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final endStr =
        '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';

    setState(() => _isLoading = true);

    try {
      final base = Url.url;
      final deliveryUrl =
          '$base/api/delivery?page=1&limit=10000&merchant_id=$userId&start_date=$startStr&end_date=$endStr&status_ids=3,5';
      final orderUrl =
          '$base/api/order?page=1&limit=10000&status_ids=3&merchant_id=$userId&start_date=$startStr&end_date=$endStr';

      final results = await Future.wait([
        _getJson(deliveryUrl),
        _getJson(orderUrl),
      ]);

      final deliveries = (results[0]['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      final orders = (results[1]['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];

      final filtered = deliveries
          .where((d) => _isStatus3(d) || _isStatus5(d))
          .toList();
      final status3 =
          filtered.where((d) => _isStatus3(d)).toList();
      final status5 =
          filtered.where((d) => _isStatus5(d)).toList();

      // Merchant (role 2): same as web — all status 3 / 5, no now/later filter
      final deliveriesToProcess = status3;
      final status5ToProcess = status5;

      final groupedData =
          _groupDeliveriesMerchant(deliveriesToProcess);
      final groupedStatus5 =
          _groupDeliveriesMerchant(status5ToProcess);
      final groupedOrders = _groupOrdersMerchant(orders);

      final reportRows = <ReportRowData>[];

      for (final entry in groupedData.entries) {
        final id = entry.key;
        final groupDeliveries = entry.value;
        final deliveredCount = groupDeliveries.length;
        final totalPrice = groupDeliveries.fold<double>(
            0, (sum, d) => sum + _parsePrice(d['price']));
        final rp =
            _parsePrice(groupDeliveries.first['merchant']?['report_price']);
        final pricePerDelivery = rp > 0 ? rp : 7000.0;

        final status5Group = groupedStatus5[id] ?? [];
        final status5Count = status5Group.length;

        var salary = deliveredCount * pricePerDelivery;
        final rp5 = status5Group.isNotEmpty
            ? _parsePrice(status5Group.first['merchant']?['report_price'])
            : 0.0;
        final status5PricePer = rp5 > 0 ? rp5 : 7000.0;
        salary += status5Count * status5PricePer;

        final groupOrdersList = groupedOrders[id] ?? [];
        final orderCount = groupOrdersList.length;
        salary += orderCount * 5000;

        final name = groupDeliveries.first['merchant']?['username']
                ?.toString() ??
            '—';

        reportRows.add(ReportRowData(
          dateRange: '$startStr ~ $endStr',
          name: name,
          deliveredDeliveries: deliveredCount,
          totalDeliveries: deliveredCount + status5Count,
          totalPrice: totalPrice,
          salary: salary,
          status5Deliveries: status5Count,
          orderCount: orderCount,
        ));
      }

      // Status 5 only (no status 3 in group)
      for (final entry in groupedStatus5.entries) {
        final id = entry.key;
        if (groupedData.containsKey(id)) continue;
        final status5Group = entry.value;
        final status5Count = status5Group.length;
        final rp5 =
            _parsePrice(status5Group.first['merchant']?['report_price']);
        final status5PricePer = rp5 > 0 ? rp5 : 7000.0;
        var salary = status5Count * status5PricePer;
        final groupOrdersList = groupedOrders[id] ?? [];
        final orderCount = groupOrdersList.length;
        salary += orderCount * 5000;

        final name = status5Group.first['merchant']?['username']?.toString() ??
            '—';

        reportRows.add(ReportRowData(
          dateRange: '$startStr ~ $endStr',
          name: name,
          deliveredDeliveries: 0,
          totalDeliveries: status5Count,
          totalPrice: 0,
          salary: salary,
          status5Deliveries: status5Count,
          orderCount: orderCount,
        ));
      }

      // Orders only
      for (final entry in groupedOrders.entries) {
        final id = entry.key;
        if (groupedData.containsKey(id) || groupedStatus5.containsKey(id)) {
          continue;
        }
        final groupOrdersList = entry.value;
        final orderCount = groupOrdersList.length;
        final salary = orderCount * 5000.0;
        final name = groupOrdersList.first['merchant']?['username']
                ?.toString() ??
            '—';

        reportRows.add(ReportRowData(
          dateRange: '$startStr ~ $endStr',
          name: name,
          deliveredDeliveries: 0,
          totalDeliveries: 0,
          totalPrice: 0,
          salary: salary,
          status5Deliveries: 0,
          orderCount: orderCount,
        ));
      }

      setState(() {
        _reportData = reportRows;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _reportData = [];
        _isLoading = false;
        _hasSearched = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа: $e', style: GoogleFonts.rubik()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF204a35),
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
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  static final NumberFormat _moneyFmt = NumberFormat('#,###', 'en_US');

  String _fmtMoney(double v) => _moneyFmt.format(v.round());

  @override
  Widget build(BuildContext context) {
    int td = 0, dd = 0, s5 = 0, oc = 0;
    double tp = 0, sal = 0;
    for (final r in _reportData) {
      td += r.totalDeliveries;
      dd += r.deliveredDeliveries;
      s5 += r.status5Deliveries;
      oc += r.orderCount;
      tp += r.totalPrice;
      sal += r.salary;
    }
    final diff = tp - sal;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Тайлан',
          style: GoogleFonts.rubik(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: const Color(0xFF204a35),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, color: Color(0xFF204a35)),
                  label: Text(
                    '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}  ~  ${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                    style: GoogleFonts.rubik(
                        fontSize: 14, color: const Color(0xFF204a35)),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF204a35)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadReport,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                  label: Text('Хайх', style: GoogleFonts.rubik(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF204a35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_reportData.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _hasSearched
                        ? 'Сонгосон хугацаанд тайлангийн өгөгдөл олдсонгүй.'
                        : 'Огнооны интервал сонгоод «Хайх» дарна уу.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(fontSize: 15, color: Colors.grey[700]),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                        MaterialStateProperty.all(Colors.grey.shade200),
                    columnSpacing: 14,
                    horizontalMargin: 12,
                    columns: [
                      DataColumn(
                          label: Text('Огноо',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Нийт хүргэлт',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Хүргэсэн хүргэлт',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Хаягаар очсон',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Захиалгын тоо',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Нийт тооцоо',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Тооцоо',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(
                          label: Text('Зөрүү',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: [
                      ..._reportData.map((r) => DataRow(cells: [
                            DataCell(Text(r.dateRange,
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${r.totalDeliveries}',
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${r.deliveredDeliveries}',
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${r.status5Deliveries}',
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${r.orderCount}',
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${_fmtMoney(r.totalPrice)} ₮',
                                style: GoogleFonts.rubik(fontSize: 12))),
                            DataCell(Text('${_fmtMoney(r.salary)} ₮',
                                style: GoogleFonts.rubik(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text('${_fmtMoney(r.difference)} ₮',
                                style: GoogleFonts.rubik(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600))),
                          ])),
                      DataRow(
                        color: MaterialStateProperty.all(Colors.grey.shade100),
                        cells: [
                          DataCell(Text('Нийт',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('$td',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('$dd',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('$s5',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('$oc',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('${_fmtMoney(tp)} ₮',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('${_fmtMoney(sal)} ₮',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text('${_fmtMoney(diff)} ₮',
                              style: GoogleFonts.rubik(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
