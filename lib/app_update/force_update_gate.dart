import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../color/color.dart';
import 'app_version.dart';

/// Wraps your post-login / auth root widget. If the API says the installed
/// version is below [minimum_version], shows a blocking screen with only
/// "Шинэчлэх" (opens store). Back button is disabled.
///
/// On network/API failure the app is allowed to open (so users are not
/// bricked offline). Tune in [AppVersionService] if you prefer strict mode.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  bool _loading = true;
  bool _needsUpdate = false;
  String _message =
      'Шинэ хувилбар гарсан тул апп-аа App Store / Play Store-оос шинэчилж ашиглана уу.';
  String _storeUrl = '';
  String _currentVersion = '';
  String _minimumVersion = '';

  @override
  void initState() {
    super.initState();
    _checkVersion();
  }

  Future<void> _checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _currentVersion = info.version;

      final uri = Uri.parse('${Url.url}/api/mobile/app/version');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        _allowApp();
        return;
      }

      final body = jsonDecode(res.body);
      if (body is! Map || body['success'] != true || body['data'] == null) {
        _allowApp();
        return;
      }

      final data = body['data'] as Map<String, dynamic>;
      final minRaw = (data['minimum_version'] ?? '1.0.0').toString();
      final androidUrl = (data['android_store_url'] ?? '').toString().trim();
      final iosUrl = (data['ios_store_url'] ?? '').toString().trim();
      final msg = (data['message_mn'] ?? _message).toString();

      final storeUrl = Platform.isIOS ? iosUrl : androidUrl;

      if (isBelowMinimum(_currentVersion, minRaw)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _needsUpdate = true;
          _minimumVersion = minRaw;
          _message = msg.isNotEmpty ? msg : _message;
          _storeUrl = storeUrl;
        });
        return;
      }
    } catch (_) {
      // Offline / server error: do not block the app.
    }

    _allowApp();
  }

  void _allowApp() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _needsUpdate = false;
    });
  }

  Future<void> _openStore() async {
    var url = _storeUrl;
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Дэлгүүрийн холбоос тохируулаагүй байна (IOS_STORE_URL).'),
        ),
      );
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsUpdate) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update, size: 64, color: Colors.deepOrange),
                    const SizedBox(height: 24),
                    Text(
                      'Шинэ хувилбар шаардлагатай',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Одоогийн: v$_currentVersion\nШаардлагатай: v$_minimumVersion',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                          ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _openStore,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Шинэчлэх',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
