import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:sura_driver/customerscreen.dart';
import '../color/color.dart';
import '../mainscreen.dart';
import '../network/api.dart';

class Login extends StatefulWidget {
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passwordVisible = false;
  TextEditingController passcont = TextEditingController();
  TextEditingController phonecont = TextEditingController(); // Phone only
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordVisible = false;
    _loadRememberMeStatus();
  }

  Future<void> _loadRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('rememberMe') ?? false;
      if (_rememberMe) {
        phonecont.text = prefs.getString('phone') ?? '';
        passcont.text = prefs.getString('password') ?? '';
      }
    });
  }

  Future<void> _saveRememberMeStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rememberMe', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('phone', phonecont.text);
      await prefs.setString('password', passcont.text);
    } else {
      await prefs.remove('phone');
      await prefs.remove('password');
    }
  }

  Color getColor(Set<MaterialState> states) {
    return Color(0xFF0035ad);
  }

  @override
  Widget build(BuildContext context) {
    double totalHeight = MediaQuery.of(context).size.height;
    double totalWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Stack(
          children: <Widget>[
            SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 70),
                  Padding(
                    padding: EdgeInsets.only(
                        left: totalWidth * 0.0, top: totalHeight * 0.08),
                    child: Image.asset('assets/superlogo.png', width: 150),
                  ),
                  SizedBox(height: 50),

                  // Phone Input Field
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: totalWidth * 0.05),
                    child: TextFormField(
                      controller: phonecont,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Утасны дугаараа оруулна уу';
                        }
                        if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                          return 'Зөвхөн тоо оруулна уу';
                        }
                        if (value.length < 8) {
                          return 'Богино дугаар байна';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Утасны дугаар',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixText: '+976 ',
                        prefixStyle: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF8FAFB),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primaryColor),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.red),
                        ),
                      ),
                      cursorColor: Color(0xFF30C6CC),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Password Input Field
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: totalWidth * 0.05),
                    child: TextFormField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Нууц үгээ оруулна уу';
                        }
                        if (value.length < 6) {
                          return 'Хамгийн багадаа 6 тэмдэгт';
                        }
                        return null;
                      },
                      obscureText: !_passwordVisible,
                      controller: passcont,
                      decoration: InputDecoration(
                        hintText: 'Нууц үг',
                        hintStyle: TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Color(0xFFF8FAFB),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primaryColor),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Theme.of(context).primaryColorDark,
                          ),
                          onPressed: () {
                            setState(() {
                              _passwordVisible = !_passwordVisible;
                            });
                          },
                        ),
                      ),
                      cursorColor: Color(0xFF30C6CC),
                    ),
                  ),

                  // Remember Me Checkbox
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: totalWidth * 0.05,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value!;
                            });
                            _saveRememberMeStatus();
                          },
                          checkColor: Colors.white,
                          fillColor: MaterialStateProperty.resolveWith(getColor),
                        ),
                        Text(
                          'Намайг сануулах',
                          style: GoogleFonts.rubik(),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30),

                  // Version Text
                  Center(
                    child: Text(
                      'v2.0.0',
                      style: GoogleFonts.rubik(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Login Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: totalWidth * 0.05),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: AppColors.primaryColor,
                      ),
                      child: TextButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : Text(
                          'НЭВТРЭХ',
                          style: GoogleFonts.rubik(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Prepare data for phone login
        Map<String, dynamic> data = {
          'phone': phonecont.text.trim(),  // Changed from username to phone
          'password': passcont.text.trim(),
        };

        final uri = Uri.parse(Url.url + "/api/auth/login");

        final response = await http.post(
          uri,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(data),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);

          if (responseData['success'] == true) {
            int role = responseData['user']['role'] ?? -1;
            int userId = responseData['user']['id'] ?? -1;
            String token = responseData['token'] ?? '';
            String phone = responseData['user']['phone'] ?? '';

            // Store login state
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('token', token);
            await prefs.setString('phone', phone);
            await prefs.setInt('role', role);
            await prefs.setInt('user_id', userId);
            await prefs.setBool('is_logged_in', true);

            // Save remember me
            _saveRememberMeStatus();

            // Check if user is a driver (role 3)
            if (role == 3) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainScreen(id: userId),
                ),
                    (route) => false,
              );
            } else {
              // Clear stored data if not a driver
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => Customerscreen(id: userId),
                ),
                    (route) => false,
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Буруу утасны дугаар эсвэл нууц үг'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Серверийн алдаа: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}