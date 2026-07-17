import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../color/color.dart';

class CreateDelivery extends StatefulWidget {
  const CreateDelivery({Key? key}) : super(key: key);

  @override
  State<CreateDelivery> createState() => _CreateDeliveryState();
}

class _CreateDeliveryState extends State<CreateDelivery> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _deliveryDateController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _goods = [];
  List<Map<String, dynamic>> _cartItems = [];
  int? _selectedDistrictId;
  bool _isSubmitting = false; // Add this loading state
  
  // Track item entries with unique IDs
  List<Map<String, dynamic>> _itemEntries = [];
  int _nextItemId = 0;
  
  // Store controllers and focus nodes by item entry ID
  final Map<int, TextEditingController> _priceControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, FocusNode> _priceFocusNodes = {};
  final Map<int, FocusNode> _quantityFocusNodes = {};

  // District data
  final List<Map<String, dynamic>> _districts = [
    {'id': 1, 'name': 'Баянзүрх'},
    {'id': 2, 'name': 'Хан Уул'},
    {'id': 3, 'name': 'Сүхбаатар'},
    {'id': 4, 'name': 'Чингэлтэй'},
    {'id': 5, 'name': 'Сонгинохайрхан'},
    {'id': 6, 'name': 'Баянгол'},
    {'id': 7, 'name': 'Орон нутаг'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize delivery date with today's date
    final today = DateTime.now();
    _deliveryDateController.text = 
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _priceController.dispose();
    _deliveryDateController.dispose();
    
    // Dispose all item entry controllers and focus nodes
    for (var controller in _priceControllers.values) {
      controller.dispose();
    }
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _priceFocusNodes.values) {
      focusNode.dispose();
    }
    for (var focusNode in _quantityFocusNodes.values) {
      focusNode.dispose();
    }
    
    super.dispose();
  }

  Future<void> _fetchGoods(int merchantId) async {
    if (_goods.isNotEmpty) return; // Already loaded
    
    final res = await http.get(Uri.parse(Url.url+'/api/good?merchant_id=$merchantId'));
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        final goodsList = (body['data'] as List).cast<Map<String, dynamic>>();
        // Sort goods alphabetically by name
        goodsList.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        setState(() => _goods = goodsList);
      }
    }
  }

  void _addItemEntry() async {
    // Fetch goods if not loaded
    if (_goods.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final merchantId = prefs.getInt('user_id');
      if (merchantId != null) {
        await _fetchGoods(merchantId);
      }
    }

    final itemId = _nextItemId++;
    setState(() {
      _itemEntries.add({
        'id': itemId,
        'good_id': null,
        'quantity': 1,
        'unit_price': 0.0,
      });
      
      // Initialize controllers for this item
      _priceControllers[itemId] = TextEditingController();
      _quantityControllers[itemId] = TextEditingController(text: '1');
      _priceFocusNodes[itemId] = FocusNode();
      _quantityFocusNodes[itemId] = FocusNode();
      
      // Set up focus listeners
      _priceFocusNodes[itemId]!.addListener(() {
        if (!_priceFocusNodes[itemId]!.hasFocus) {
          _updateItemEntry(itemId);
        }
      });
      
      _quantityFocusNodes[itemId]!.addListener(() {
        if (!_quantityFocusNodes[itemId]!.hasFocus) {
          _updateItemEntry(itemId);
        }
      });
    });
  }

  void _removeItemEntry(int itemId) {
    setState(() {
      _itemEntries.removeWhere((entry) => entry['id'] == itemId);
      
      // Dispose controllers
      _priceControllers[itemId]?.dispose();
      _quantityControllers[itemId]?.dispose();
      _priceFocusNodes[itemId]?.dispose();
      _quantityFocusNodes[itemId]?.dispose();
      
      _priceControllers.remove(itemId);
      _quantityControllers.remove(itemId);
      _priceFocusNodes.remove(itemId);
      _quantityFocusNodes.remove(itemId);
      
      // Update cart
      _syncCartFromEntries();
    });
  }

  void _updateItemEntry(int itemId) {
    final entryIndex = _itemEntries.indexWhere((e) => e['id'] == itemId);
    if (entryIndex == -1) return;
    
    final entry = _itemEntries[entryIndex];
    final goodId = entry['good_id'] as int?;
    final unitPrice = double.tryParse(_priceControllers[itemId]?.text ?? '0') ?? 0.0;
    final quantity = int.tryParse(_quantityControllers[itemId]?.text ?? '1') ?? 1;
    
    setState(() {
      _itemEntries[entryIndex] = {
        'id': itemId,
        'good_id': goodId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };
      
      _syncCartFromEntries();
    });
  }

  void _onGoodSelected(int itemId, int? goodId) {
    final entryIndex = _itemEntries.indexWhere((e) => e['id'] == itemId);
    if (entryIndex == -1) return;
    
    setState(() {
      _itemEntries[entryIndex]['good_id'] = goodId;
      _syncCartFromEntries();
    });
  }

  void _syncCartFromEntries() {
    _cartItems = _itemEntries
        .where((entry) =>
            entry['good_id'] != null &&
            (entry['unit_price'] as num) >= 0 &&
            entry['quantity'] > 0)
        .map((entry) => {
          'good_id': entry['good_id'],
          'quantity': entry['quantity'],
          'unit_price': entry['unit_price'],
        })
        .toList();
    
    // Update total price
    final total = calculateTotalPrice();
    _priceController.text = total.toStringAsFixed(2);
  }

  double calculateTotalPrice() {
    return _cartItems.fold(0.0, (sum, item) => sum + (item['unit_price'] * item['quantity']));
  }


  void _saveDelivery() async {
    // Prevent multiple clicks
    if (_isSubmitting) return;

    if (_formKey.currentState!.validate()) {
      if (_selectedDistrictId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Дүүрэг сонгоно уу!', style: GoogleFonts.rubik())),
        );
        return;
      }

      // Validate stock before submitting
      for (final item in _cartItems) {
        final goodId = item['good_id'] as int;
        final quantity = item['quantity'] as int;
        
        try {
          final good = _goods.firstWhere((g) => g['id'] == goodId);
          final stock = good['stock'] ?? 0;
          if (quantity > stock) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Агуулахын үлдэгдэл хүрэлцэхгүй', style: GoogleFonts.rubik()),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } catch (e) {
          // Good not found, skip validation for this item
          continue;
        }
      }

      setState(() => _isSubmitting = true); // Start loading

      try {
        final prefs = await SharedPreferences.getInstance();
        final merchantId = prefs.getInt('user_id');

        final payload = {
          'merchant_id': merchantId,
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'dist_id': _selectedDistrictId,
          'price': double.tryParse(_priceController.text.trim()) ?? 0,
          'delivery_date': _deliveryDateController.text.trim().isNotEmpty 
              ? _deliveryDateController.text.trim() 
              : null,
          'items': _cartItems.map((e) => {
            'good_id': e['good_id'],
            'quantity': e['quantity'],
          }).toList(),
        };

        final res = await http.post(
          Uri.parse(Url.url+'/api/delivery'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(Duration(seconds: 30)); // Add timeout

        if (res.statusCode == 200 || res.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Хүргэлт амжилттай үүслээ!', style: GoogleFonts.rubik()),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          final body = jsonDecode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(body['message'] ?? 'Алдаа гарлаа', style: GoogleFonts.rubik()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сүлжээний алдаа: $e', style: GoogleFonts.rubik()),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isSubmitting = false); // Stop loading
      }
    }
  }

  Widget _buildItemEntryCard(Map<String, dynamic> entry) {
    final itemId = entry['id'] as int;
    final selectedGoodId = entry['good_id'] as int?;
    
    final priceController = _priceControllers[itemId]!;
    final quantityController = _quantityControllers[itemId]!;
    final priceFocusNode = _priceFocusNodes[itemId]!;
    final quantityFocusNode = _quantityFocusNodes[itemId]!;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selectedGoodId != null ? Color(0xFF204a35).withOpacity(0.3) : Colors.grey[300]!,
          width: selectedGoodId != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Goods selection row
            Row(
              children: [
                Expanded(
                  child: DropdownSearch<Map<String, dynamic>>(
                    selectedItem: selectedGoodId != null
                        ? _goods.where((g) => g['id'] == selectedGoodId).isNotEmpty
                            ? _goods.firstWhere((g) => g['id'] == selectedGoodId)
                            : null
                        : null,
                    compareFn: (item1, item2) => item1['id'] == item2['id'],
                    items: _goods,
                    itemAsString: (good) => '${good['name']} (${good['stock'] ?? 0})',
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Хайх...',
                          hintStyle: GoogleFonts.rubik(fontSize: 13),
                          prefixIcon: Icon(Icons.search, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: GoogleFonts.rubik(fontSize: 13),
                      ),
                      menuProps: MenuProps(
                        backgroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      itemBuilder: (context, item, isSelected) {
                        final stock = item['stock'] ?? 0;
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            '${item['name']} ($stock)',
                            style: GoogleFonts.rubik(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        labelText: 'Бараа сонгох',
                        labelStyle: GoogleFonts.rubik(fontSize: 13),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Color(0xFF204a35), width: 1.5),
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        _onGoodSelected(itemId, value['id'] as int);
                      } else {
                        _onGoodSelected(itemId, null);
                      }
                    },
                    filterFn: (item, filter) {
                      final name = (item['name'] ?? '').toString().toLowerCase();
                      final stock = (item['stock'] ?? 0).toString();
                      final searchTerm = filter.toLowerCase();
                      return name.contains(searchTerm) || stock.contains(searchTerm);
                    },
                  ),
                ),
                SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                  onPressed: () => _removeItemEntry(itemId),
                  tooltip: 'Устгах',
                  padding: EdgeInsets.all(6),
                  constraints: BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Quantity and Unit Price row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    focusNode: quantityFocusNode,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Тоо ширхэг',
                      labelStyle: GoogleFonts.rubik(fontSize: 12),
                      prefixIcon: Icon(Icons.numbers, size: 16),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 1.5),
                      ),
                    ),
                    style: GoogleFonts.rubik(fontSize: 13),
                    onChanged: (value) => _updateItemEntry(itemId),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    focusNode: priceFocusNode,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Нэгж үнэ',
                      labelStyle: GoogleFonts.rubik(fontSize: 12),
                      prefixIcon: Icon(Icons.attach_money, size: 16),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 1.5),
                      ),
                    ),
                    style: GoogleFonts.rubik(fontSize: 13),
                    onChanged: (value) => _updateItemEntry(itemId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFF204a35).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_cart, color: Color(0xFF204a35), size: 18),
              SizedBox(width: 8),
              Text(
                'Сагсанд нэмэгдсэн бараанууд',
                style: GoogleFonts.rubik(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF204a35),
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFF204a35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_cartItems.length}',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        ListView.builder(
          itemCount: _cartItems.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final item = _cartItems[index];
            final matchingGoods = _goods.where((g) => g['id'] == item['good_id']).toList();
            final good = matchingGoods.isNotEmpty ? matchingGoods.first : null;
            return Container(
              key: ValueKey('cart_item_${item['good_id']}_$index'),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),

                title: Text(
                  good != null ? good['name'] : 'ID: ${item['good_id']}',
                  style: GoogleFonts.rubik(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Тоо: ${item['quantity']}',
                          style: GoogleFonts.rubik(
                            fontSize: 11,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '₮${item['unit_price']}/н',
                          style: GoogleFonts.rubik(
                            fontSize: 11,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '₮${(item['unit_price'] * item['quantity']).toStringAsFixed(2)}',
                      style: GoogleFonts.rubik(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF204a35),
                      ),
                    ),
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 18),
                      onPressed: () {
                        final goodId = item['good_id'];
                        final entry = _itemEntries.firstWhere(
                          (e) => e['good_id'] == goodId,
                          orElse: () => <String, dynamic>{},
                        );
                        if (entry.isNotEmpty) {
                          _removeItemEntry(entry['id']);
                        } else {
                          setState(() {
                            _cartItems.removeAt(index);
                            final total = calculateTotalPrice();
                            _priceController.text = total.toStringAsFixed(2);
                          });
                        }
                      },
                      padding: EdgeInsets.all(4),
                      constraints: BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_cartItems.isNotEmpty) ...[
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color(0xFF204a35).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Color(0xFF204a35).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Нийт дүн:',
                  style: GoogleFonts.rubik(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '₮${calculateTotalPrice().toStringAsFixed(2)}',
                  style: GoogleFonts.rubik(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF204a35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Шинэ хүргэлт нэмэх',
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Color(0xFF204a35),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            // Customer Information Section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFF204a35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.person_outline, color: Color(0xFF204a35), size: 18),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Харилцагчийн мэдээлэл',
                        style: GoogleFonts.rubik(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.rubik(),
                    decoration: InputDecoration(
                      labelText: 'Утасны дугаар',
                      labelStyle: GoogleFonts.rubik(),
                      prefixIcon: Icon(Icons.phone, color: Color(0xFF204a35)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Утас оруулна уу' : null,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _addressController,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 2,
                    maxLines: 8,
                    style: GoogleFonts.rubik(),
                    decoration: InputDecoration(
                      labelText: 'Хаяг',
                      alignLabelWithHint: true,
                      labelStyle: GoogleFonts.rubik(),
                      prefixIcon: Icon(Icons.location_on, color: Color(0xFF204a35)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Хаяг оруулна уу' : null,
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: _selectedDistrictId,
                    decoration: InputDecoration(
                      labelText: 'Дүүрэг',
                      labelStyle: GoogleFonts.rubik(),
                      prefixIcon: Icon(Icons.map, color: Color(0xFF204a35)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    style: GoogleFonts.rubik(color: Colors.black87),
                    dropdownColor: Colors.white,
                    icon: Icon(Icons.arrow_drop_down, color: Colors.black87),
                    items: _districts.map((district) {
                      return DropdownMenuItem<int>(
                        value: district['id'],
                        child: Text(
                          district['name'],
                          style: GoogleFonts.rubik(color: Colors.black87),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrictId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Дүүрэг сонгоно уу' : null,
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _deliveryDateController,
                    readOnly: true,
                    style: GoogleFonts.rubik(),
                    decoration: InputDecoration(
                      labelText: 'Хүргэх огноо *',
                      labelStyle: GoogleFonts.rubik(),
                      prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF204a35)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Хүргэх огноо сонгоно уу' : null,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: Color(0xFF204a35),
                                onPrimary: Colors.white,
                                onSurface: Colors.black87,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _deliveryDateController.text = 
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // Order Details Section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFF204a35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.receipt_long, color: Color(0xFF204a35), size: 18),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Захиалгын дэлгэрэнгүй',
                        style: GoogleFonts.rubik(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.rubik(),
                    decoration: InputDecoration(
                      labelText: 'Үнэ (нийт)',
                      labelStyle: GoogleFonts.rubik(),
                      prefixIcon: Icon(Icons.attach_money, color: Color(0xFF204a35)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Color(0xFF204a35), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Үнэ оруулна уу' : null,
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),

            // Goods Section
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Color(0xFF204a35).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.warehouse, color: Color(0xFF204a35), size: 18),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Бараа нэмэх',
                          style: GoogleFonts.rubik(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_itemEntries.isNotEmpty) ...[
                    SizedBox(height: 12),
                    ..._itemEntries.map((entry) => _buildItemEntryCard(entry)).toList(),
                  ],
                  SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _addItemEntry,
                    icon: Icon(Icons.add_circle_outline, color: Color(0xFF204a35), size: 18),
                    label: Text(
                      'Бараа нэмэх',
                      style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF204a35),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF204a35), width: 2),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize: Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),

            if (_cartItems.isNotEmpty) _buildCartList(),
            SizedBox(height: 12),

            // Submit Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_isSubmitting ? Colors.grey : Color(0xFF204a35)).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitting ? Colors.grey : Color(0xFF204a35),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Хадгалагдаж байна...',
                            style: GoogleFonts.rubik(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Хадгалах',
                            style: GoogleFonts.rubik(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
