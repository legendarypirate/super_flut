import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import '../color/color.dart';

class GoodListScreen extends StatefulWidget {
  @override
  _GoodListScreenState createState() => _GoodListScreenState();
}

class _GoodListScreenState extends State<GoodListScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> goods = [];
  List<dynamic> requests = [];
  List<dynamic> wares = [];
  bool isLoading = true;
  bool isLoadingRequests = false;
  late TabController _tabController;
  int? userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Update UI when tab changes
    });
    _loadUserAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('user_id');
    await Future.wait([fetchGoods(), fetchWares(), fetchRequests()]);
  }

  Future<void> fetchGoods() async {
    if (userId == null) return;
    try {
      final response = await http.get(
        Uri.parse(Url.url + '/api/mobile/good/merchant?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true) {
          setState(() {
            goods = jsonBody['data'];
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
          print('API returned success: false');
        }
      } else {
        setState(() => isLoading = false);
        print('Failed to load goods, status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching goods: $e');
    }
  }

  Future<void> fetchWares() async {
    try {
      final response = await http.get(
        Uri.parse(Url.url + '/api/ware'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true) {
          setState(() {
            wares = jsonBody['data'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error fetching wares: $e');
    }
  }

  Future<void> fetchRequests() async {
    if (userId == null) return;
    setState(() => isLoadingRequests = true);
    try {
      final response = await http.get(
        Uri.parse(Url.url + '/api/request?merchant_id=$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody = json.decode(response.body);
        if (jsonBody['success'] == true) {
          setState(() {
            requests = jsonBody['data'] ?? [];
            isLoadingRequests = false;
          });
        } else {
          setState(() => isLoadingRequests = false);
        }
      } else {
        setState(() => isLoadingRequests = false);
        print('Failed to load requests, status: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => isLoadingRequests = false);
      print('Error fetching requests: $e');
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'Хүлээгдэж байна';
      case 2:
        return 'Зөвшөөрөгдсөн';
      case 3:
        return 'Татгалзсан';
      default:
        return 'Тодорхойгүй';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeText(int type) {
    switch (type) {
      case 1:
        return 'Шинэ бараа';
      case 2:
        return 'Нэмэх';
      case 3:
        return 'Хасах';
      default:
        return 'Тодорхойгүй';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF204a35),
        title: Text('Барааны жагсаалт',
            style: GoogleFonts.rubik(fontSize: 15, color: Colors.white)),
        centerTitle: true,
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Бараа',
              icon: Icon(Icons.shopping_basket),
            ),
            Tab(
              text: 'Хүсэлт',
              icon: Icon(Icons.request_quote),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Goods Tab
          isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF204a35)))
              : goods.isEmpty
                  ? Center(
                      child: Text(
                        'Бараа олдсонгүй',
                        style: GoogleFonts.rubik(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchGoods,
                      color: Color(0xFF204a35),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: goods.length,
                        itemBuilder: (context, index) {
                          final item = goods[index];
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.deepOrange.withOpacity(0.2),
                                child: Icon(Icons.shopping_basket,
                                    color: Color(0xFF204a35)),
                              ),
                              title: Text(
                                item['name'] ?? 'No name',
                                style: GoogleFonts.rubik(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Color(0xFF204a35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item['stock'] ?? 0} ш',
                                  style: GoogleFonts.rubik(
                                      color: Colors.white, fontSize: 14),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

          // Requests Tab
          isLoadingRequests
              ? Center(child: CircularProgressIndicator(color: Color(0xFF204a35)))
              : RefreshIndicator(
                  onRefresh: fetchRequests,
                  color: Color(0xFF204a35),
                  child: requests.isEmpty
                      ? Center(
                          child: Text(
                            'Хүсэлт олдсонгүй',
                            style: GoogleFonts.rubik(
                                fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final request = requests[index];
                            final status = request['status'] ?? 0;
                            final type = request['type'] ?? 0;
                            final goodName = request['good']?['name'] ??
                                request['name'] ??
                                'Тодорхойгүй';
                            final wareName =
                                request['ware']?['name'] ?? 'Тодорхойгүй';
                            final stock = request['stock'] ?? 0;
                            final approvedStock = request['approved_stock'];

                            return Container(
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getStatusColor(status).withOpacity(0.2),
                                  child: Icon(Icons.request_quote,
                                      color: _getStatusColor(status)),
                                ),
                                title: Text(
                                  goodName,
                                  style: GoogleFonts.rubik(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 4),
                                    Text(
                                      'Агуулах: $wareName',
                                      style: GoogleFonts.rubik(
                                          fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'Төрөл: ${_getTypeText(type)}',
                                      style: GoogleFonts.rubik(
                                          fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    if (approvedStock != null)
                                      Text(
                                        'Зөвшөөрсөн: $approvedStock ш',
                                        style: GoogleFonts.rubik(
                                            fontSize: 12, color: Colors.green),
                                      ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getStatusText(status),
                                        style: GoogleFonts.rubik(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                      Text(
                                        '$stock ш',
                                        style: GoogleFonts.rubik(
                                            color: Colors.white, fontSize: 10),
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
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => _RequestStockDialog(
                    goods: goods,
                    wares: wares,
                    onSuccess: fetchRequests,
                  ),
                );
              },
              backgroundColor: Color(0xFF204a35),
              child: Icon(Icons.add, color: Colors.white),
              tooltip: 'Шинэ хүсэлт үүсгэх',
            )
          : null,
    );
  }
}

String _goodDisplayLabel(Map<String, dynamic> good) {
  final name = good['name']?.toString() ?? '';
  final stock = good['stock'] ?? 0;
  return '$name ($stock ш)';
}

class _RequestStockDialog extends StatefulWidget {
  final List<dynamic> goods;
  final List<dynamic> wares;
  final Future<void> Function() onSuccess;

  const _RequestStockDialog({
    required this.goods,
    required this.wares,
    required this.onSuccess,
  });

  @override
  State<_RequestStockDialog> createState() => _RequestStockDialogState();
}

class _RequestStockDialogState extends State<_RequestStockDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  TextEditingController? _goodFieldController;

  int? _selectedWareId;
  int? _selectedGoodId;
  Map<String, dynamic>? _selectedGood;

  List<Map<String, dynamic>> get _goodsForWarehouse {
    if (_selectedWareId == null) return [];
    return widget.goods
        .where((good) =>
            good['ware_id'] == _selectedWareId ||
            good['ware']?['id'] == _selectedWareId)
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        })
        .toList();
  }

  static int? _parseGoodId(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is num) return id.toInt();
    return int.tryParse(id.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _goodFieldController?.removeListener(_onGoodFieldTextChanged);
    super.dispose();
  }

  void _onGoodFieldTextChanged() {
    final c = _goodFieldController;
    final sel = _selectedGood;
    if (c == null || sel == null) return;
    if (c.text != _goodDisplayLabel(sel)) {
      setState(() {
        _selectedGood = null;
        _selectedGoodId = null;
      });
    }
  }

  Iterable<Map<String, dynamic>> _goodOptions(TextEditingValue value) {
    final list = _goodsForWarehouse;
    if (list.isEmpty) return const [];
    final q = value.text.trim().toLowerCase();
    if (q.isEmpty) return list.take(80);
    return list
        .where((g) =>
            (g['name'] ?? '').toString().toLowerCase().contains(q))
        .take(80);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWareId == null || _selectedGoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бүх талбарыг бөглөнө үү')),
      );
      return;
    }

    final int amount = int.parse(_amountController.text);
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Хэрэглэгчийн мэдээлэл олдсонгүй. Дахин нэвтэрнэ үү.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final requestPayload = {
      'type': 2,
      'amount': amount,
      'ware_id': _selectedWareId,
      'merchant_id': userId,
      'good_id': _selectedGoodId,
    };

    try {
      final url = Uri.parse(Url.url + '/api/request/stock');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Холболт удаан байна. Дахин оролдоно уу.');
            },
          );

      Map<String, dynamic>? resBody;
      try {
        resBody = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (resBody != null && resBody['success'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Алдаа: ${resBody['message'] ?? resBody['error'] ?? 'Алдаа гарлаа'}',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Хүсэлт амжилттай үүсгэгдлээ'),
            backgroundColor: Colors.green,
          ),
        );
        await widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resBody != null
                  ? 'Алдаа (${response.statusCode}): ${resBody['message'] ?? resBody['error'] ?? ''}'
                  : 'Алдаа гарлаа (${response.statusCode})',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } on TimeoutException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Холболт удаан байна.'),
          backgroundColor: Colors.red,
        ),
      );
    } on http.ClientException {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Сүлжээний алдаа. Интернэт холболтоо шалгана уу.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Алдаа гарлаа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Шинэ хүсэлт үүсгэх',
        style: GoogleFonts.rubik(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Агуулах',
                  border: OutlineInputBorder(),
                ),
                value: _selectedWareId,
                items: widget.wares.map((ware) {
                  return DropdownMenuItem<int>(
                    value: ware['id'],
                    child: Text(ware['name'] ?? 'Тодорхойгүй'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedWareId = value;
                    _selectedGoodId = null;
                    _selectedGood = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'Агуулах сонгоно уу' : null,
              ),
              SizedBox(height: 16),
              if (_selectedWareId != null && _goodsForWarehouse.isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Энэ агуулахад бараа байхгүй байна',
                    style: GoogleFonts.rubik(
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ),
              if (_selectedWareId != null && _goodsForWarehouse.isNotEmpty)
                Autocomplete<Map<String, dynamic>>(
                  key: ValueKey(_selectedWareId),
                  displayStringForOption: _goodDisplayLabel,
                  optionsBuilder: (TextEditingValue value) async =>
                      _goodOptions(value),
                  onSelected: (Map<String, dynamic> option) {
                    setState(() {
                      _selectedGood = option;
                      _selectedGoodId = _parseGoodId(option['id']);
                    });
                  },
                  fieldViewBuilder: (
                    BuildContext context,
                    TextEditingController textEditingController,
                    FocusNode focusNode,
                    VoidCallback onFieldSubmitted,
                  ) {
                    if (_goodFieldController != textEditingController) {
                      _goodFieldController?.removeListener(
                          _onGoodFieldTextChanged);
                      _goodFieldController = textEditingController;
                      _goodFieldController!
                          .addListener(_onGoodFieldTextChanged);
                    }
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      style: GoogleFonts.rubik(),
                      decoration: InputDecoration(
                        labelText: 'Бараа',
                        hintText: 'Нэрээр хайж сонгоно уу',
                        border: OutlineInputBorder(),
                        suffixIcon: _selectedGoodId != null
                            ? Icon(Icons.check_circle,
                                color: Color(0xFF204a35), size: 22)
                            : Icon(Icons.search, color: Colors.grey),
                      ),
                      validator: (_) => _selectedGoodId == null
                          ? 'Жагсаалтаас сонгоно уу'
                          : null,
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  optionsViewBuilder: (
                    BuildContext context,
                    AutocompleteOnSelected<Map<String, dynamic>> onSelected,
                    Iterable<Map<String, dynamic>> options,
                  ) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 260,
                            minWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Text(
                                    _goodDisplayLabel(option),
                                    style: GoogleFonts.rubik(fontSize: 14),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                )
              else if (_selectedWareId == null)
                TextFormField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Бараа',
                    hintText: 'Эхлээд агуулах сонгоно уу',
                    border: OutlineInputBorder(),
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                style: GoogleFonts.rubik(),
                decoration: InputDecoration(
                  labelText: 'Тоо ширхэг',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Тоо ширхэг оруулна уу';
                  if (int.tryParse(value) == null) return 'Тоон утга оруулна уу';
                  if (int.parse(value) <= 0) return '0-ээс их байх ёстой';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Болих', style: GoogleFonts.rubik()),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF204a35),
          ),
          child: Text('Хүсэлт үүсгэх',
              style: GoogleFonts.rubik(color: Colors.white)),
        ),
      ],
    );
  }
}
