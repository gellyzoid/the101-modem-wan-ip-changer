import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

// THIS LINE SOLVES THE SSL CERTIFICATE ISSUE!
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides(); // Enable self-signed certificates
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'the101 IP Refresher',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: const RouterScreen(),
    );
  }
}

class RouterScreen extends StatefulWidget {
  const RouterScreen({super.key});

  @override
  State<RouterScreen> createState() => _RouterScreenState();
}

class _RouterScreenState extends State<RouterScreen> {
  String previousIP = '—';
  String currentIP = '—';
  bool loading = false;
  bool initialLoading = true;
  bool? ipChanged;
  bool? internetAccessible;
  int attempts = 0;
  bool showRetry = false;
  List<Map<String, String>> logs = [];
  bool showLogs = true; // Changed to true (open by default)
  String cookies = '';

  // Add ScrollController for auto-scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchCurrentIP();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Clean up controller
    super.dispose();
  }

  void _addLog(String message) {
    final time = TimeOfDay.now().format(context);
    setState(() {
      logs.add({'time': time, 'message': message});
    });

    // Auto-scroll to bottom after adding log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _login() async {
    try {
      _addLog('Logging into router...');

      final response = await http.post(
        Uri.parse('https://192.168.0.1/cgi-bin/login.cgi'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'username=yourusername&password=yourpassword', // Replace with actual credentials
      );

      cookies = response.headers['set-cookie']?.split(';')[0] ?? '';
      _addLog('✓ Login successful');
    } catch (e) {
      _addLog('✗ Login error: ${e.toString()}');
      rethrow;
    }
  }

  Future<String> _getWanIP() async {
    try {
      final response = await http.get(
        Uri.parse('https://192.168.0.1/cgi-bin/devinfo.cgi'),
        headers: {'Cookie': cookies},
      );

      final data = json.decode(response.body);
      final ip = (data['data']['ccmni_ipv4'] as String).split(':')[1].trim();
      _addLog('WAN IP: $ip');
      return ip;
    } catch (e) {
      _addLog('✗ Get WAN IP error: ${e.toString()}');
      rethrow;
    }
  }

  Future<String> _getNetworkMode() async {
    try {
      final response = await http.get(
        Uri.parse('https://192.168.0.1/cgi-bin/netmoderat.cgi'),
        headers: {'Cookie': cookies},
      );

      final data = json.decode(response.body);
      final ratMode = data['ratMode'] as String;
      final ratName = data['ratName'] as String;
      _addLog('Current Network Mode: $ratMode ($ratName)');
      return ratMode;
    } catch (e) {
      _addLog('✗ Get network mode error: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _setNetworkMode(String mode) async {
    try {
      await http.post(
        Uri.parse('https://192.168.0.1/cgi-bin/netmode.cgi'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': cookies,
        },
        body: 'ratMode=$mode',
      );
      _addLog('✓ Network mode changed to: $mode');
    } catch (e) {
      _addLog('✗ Set network mode error: ${e.toString()}');
      rethrow;
    }
  }

  Future<bool> _checkGoogleAccessibility() async {
    try {
      _addLog('Checking Google accessibility...');
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      _addLog('✓ Google is accessible (Status: ${response.statusCode})');
      return true;
    } catch (e) {
      _addLog('✗ Google is not accessible');
      return false;
    }
  }

  Future<void> _fetchCurrentIP() async {
    try {
      _addLog('Initializing...');
      await _login();
      final ip = await _getWanIP();
      setState(() {
        currentIP = ip;
        initialLoading = false;
      });
      _addLog('Current IP: $ip');
    } catch (e) {
      setState(() {
        initialLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _refreshWanIP() async {
    setState(() {
      loading = true;
      ipChanged = null;
      internetAccessible = null;
      showRetry = false;
      showLogs = true;
      logs.clear();
    });

    try {
      _addLog('=== Starting WAN IP Refresh ===');

      await _login();

      final oldIP = await _getWanIP();
      setState(() {
        previousIP = oldIP;
      });
      _addLog('Old IP: $oldIP');

      final currentMode = await _getNetworkMode();

      // Toggle between 21 and 19
      String nextMode;
      if (currentMode == '21') {
        nextMode = '19';
      } else if (currentMode == '19') {
        nextMode = '21';
      } else {
        throw Exception('Unknown network mode detected: $currentMode');
      }

      _addLog('Switching network mode from $currentMode to $nextMode');

      // Changed from 5 to 10 retries
      const maxAttempts = 10;
      int attemptCount = 0;
      bool googleAccessible = false;

      while (attemptCount < maxAttempts && !googleAccessible) {
        attemptCount++;
        _addLog('--- Attempt $attemptCount/$maxAttempts ---');

        await _setNetworkMode(nextMode);

        _addLog('Waiting 10 seconds for reconnect...');
        await Future.delayed(const Duration(seconds: 10));

        googleAccessible = await _checkGoogleAccessibility();

        if (googleAccessible) {
          _addLog('✓ Success! Google is now accessible');
          break;
        } else {
          _addLog('✗ Google still not accessible, will try toggling again...');
          nextMode = nextMode == '21' ? '19' : '21';
        }
      }

      final newIP = await _getWanIP();
      _addLog('New IP: $newIP');

      final changed = oldIP != newIP;

      _addLog('=== Results ===');
      _addLog('Old IP: $oldIP');
      _addLog('New IP: $newIP');
      _addLog('IP Changed: ${changed ? "Yes" : "No"}');
      _addLog('Internet Accessible: ${googleAccessible ? "Yes" : "No"}');
      _addLog('Total Attempts: $attemptCount');
      _addLog('=== Process Complete ===');

      setState(() {
        currentIP = newIP;
        ipChanged = changed;
        internetAccessible = googleAccessible;
        attempts = attemptCount;
        showRetry = !googleAccessible;
      });

      if (mounted) {
        if (googleAccessible) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Success! IP changed and internet is accessible!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('IP changed but internet is not accessible'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      _addLog('✗ Unexpected error: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }

    setState(() {
      loading = false;
    });
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1e293b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563eb), Color(0xFF3b82f6)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.warning, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm IP Refresh',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'This process will temporarily disconnect your internet connection and may take 1-2 minutes.',
          style: TextStyle(color: Color(0xFF94a3b8)),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94a3b8)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshWanIP();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563eb),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 16),
                SizedBox(width: 8),
                Text('Start Refresh'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020617), Color(0xFF1e3a8a), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563eb), Color(0xFF3b82f6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wifi, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'the101 5G Modem\nController',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'WAN IP Management',
                                style: TextStyle(
                                  color: Color(0xFF94a3b8),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: Color(0xFF4ade80),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Color(0xFF4ade80),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // WAN Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e293b).withOpacity(0.38),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.language,
                            color: Color(0xFF60a5fa),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'WAN IP Information',
                            style: TextStyle(
                              color: Color(0xFFcbd5e1),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Previous Address
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: const Color(0xFF52525b),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PREVIOUS ADDRESS',
                                style: TextStyle(
                                  color: const Color(0xFF94a3b8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1e293b).withOpacity(0.48),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Text(
                              previousIP,
                              style: const TextStyle(
                                color: Color(0xFF94a3b8),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Current Address
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: const Color(0xFF3b82f6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CURRENT ADDRESS',
                                style: TextStyle(
                                  color: const Color(0xFF94a3b8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1e3a8a).withOpacity(0.25),
                                  const Color(0xFF1e4ed8).withOpacity(0.13),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF60a5fa,
                                ).withOpacity(0.15),
                              ),
                            ),
                            child: initialLoading
                                ? const Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF60a5fa),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Loading...',
                                        style: TextStyle(
                                          color: Color(0xFF60a5fa),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    currentIP,
                                    style: const TextStyle(
                                      color: Color(0xFF60a5fa),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      // IP Change Status
                      if (ipChanged != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ipChanged!
                                ? const Color(0xFF054028).withOpacity(0.13)
                                : const Color(0xFF78350f).withOpacity(0.13),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ipChanged!
                                  ? const Color(0xFF16a34a).withOpacity(0.19)
                                  : const Color(0xFFeab308).withOpacity(0.19),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ipChanged! ? Icons.check_circle : Icons.warning,
                                color: ipChanged!
                                    ? const Color(0xFF4ade80)
                                    : const Color(0xFFfacc15),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                ipChanged!
                                    ? 'IP changed successfully'
                                    : 'IP did not change',
                                style: TextStyle(
                                  color: ipChanged!
                                      ? const Color(0xFF86efac)
                                      : const Color(0xFFfde047),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Internet Status
                      if (internetAccessible != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: internetAccessible!
                                ? const Color(0xFF054028).withOpacity(0.13)
                                : const Color(0xFF450008).withOpacity(0.13),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: internetAccessible!
                                  ? const Color(0xFF16a34a).withOpacity(0.19)
                                  : const Color(0xFFdc2626).withOpacity(0.19),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                internetAccessible!
                                    ? Icons.check_circle
                                    : Icons.wifi_off,
                                color: internetAccessible!
                                    ? const Color(0xFF4ade80)
                                    : const Color(0xFFf87171),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      internetAccessible!
                                          ? 'Internet accessible'
                                          : 'Internet not accessible',
                                      style: TextStyle(
                                        color: internetAccessible!
                                            ? const Color(0xFF86efac)
                                            : const Color(0xFFfca5a5),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      internetAccessible!
                                          ? (attempts > 1
                                                ? 'Succeeded after $attempts attempts'
                                                : 'Connected on first try')
                                          : 'Failed after $attempts attempts',
                                      style: TextStyle(
                                        color:
                                            (internetAccessible!
                                                    ? const Color(0xFF86efac)
                                                    : const Color(0xFFfca5a5))
                                                .withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Logs Panel (with auto-scroll)
                if (showLogs && logs.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF22c55e).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.terminal,
                                  size: 16,
                                  color: Color(0xFF4ade80),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'System Logs',
                                  style: TextStyle(
                                    color: Color(0xFF4ade80),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Color(0xFF71717a),
                              ),
                              onPressed: () => setState(() => showLogs = false),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            controller:
                                _scrollController, // Add controller here
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '[${log['time']}] ',
                                        style: const TextStyle(
                                          color: Color(0xFF16a34a),
                                        ),
                                      ),
                                      TextSpan(
                                        text: log['message'],
                                        style: const TextStyle(
                                          color: Color(0xFF4ade80),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Show Logs Button
                if (!showLogs && logs.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => setState(() => showLogs = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e293b).withOpacity(0.38),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terminal,
                              size: 16,
                              color: Color(0xFFa1a1aa),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Show System Logs',
                              style: TextStyle(
                                color: Color(0xFF94a3b8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Refresh Button
                SizedBox(
                  width: double.infinity,
                  child: showRetry
                      ? ElevatedButton(
                          onPressed: _refreshWanIP,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: const Color(0xFFea580c),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh, size: 20),
                              SizedBox(width: 12),
                              Text(
                                'Retry Connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.bolt, size: 16),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: loading || initialLoading
                              ? null
                              : _showConfirmDialog,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: const Color(0xFF2563eb),
                            disabledBackgroundColor: const Color(
                              0xFF2563eb,
                            ).withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Refreshing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: 12),
                                    Text(
                                      'Refresh WAN IP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.chevron_right, size: 16),
                                  ],
                                ),
                        ),
                ),

                const SizedBox(height: 16),

                // Info Text
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF64748b),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will toggle your network mode and may take 1-2 minutes',
                        style: TextStyle(
                          color: const Color(0xFF64748b),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
