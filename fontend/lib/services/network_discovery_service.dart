import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/ai_config.dart';
import '../core/dio_client.dart';

/// Automatically discovers the OJT backend server on the local Wi-Fi network.
///
/// Discovery strategy (in order):
/// 1. HTTP subnet scan — gets the phone's IP, scans the subnet for port 3000
/// 2. UDP probe — sends "OJT_DISCOVER" broadcast, backend responds
/// 3. Fallback — loads previously saved IP from SharedPreferences
class NetworkDiscoveryService {
  static const int _udpPort = 41234;
  static const int _apiPort = 3000;
  static bool _discovered = false;

  /// Main discovery entry point. Tries subnet scan, then UDP, then cached IP.
  static Future<bool> discoverServer({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_discovered) {
      if (kDebugMode) print('[Discovery] Already discovered, skipping.');
      return true;
    }

    // Strategy 1: HTTP subnet scan (most reliable)
    if (kDebugMode) print('[Discovery] Trying HTTP subnet scan...');
    final scanResult = await _scanSubnet();
    if (scanResult != null) {
      await _applyDiscoveredIp(scanResult);
      return true;
    }

    // Strategy 2: UDP probe (works on some networks)
    if (kDebugMode) print('[Discovery] Trying UDP probe...');
    final udpResult = await _udpProbe();
    if (udpResult != null) {
      await _applyDiscoveredIp(udpResult);
      return true;
    }

    // Strategy 3: Fall back to cached IP
    if (kDebugMode) print('[Discovery] ⚠️ Auto-discovery failed. Loading cached IP...');
    await ApiConfig.init();
    await AiConfig.init();
    DioClient().dio.options.baseUrl = ApiConfig.baseUrl;

    if (kDebugMode) print('[Discovery] Using: ${ApiConfig.baseUrl}');
    return false;
  }

  /// Apply a discovered IP to all configs
  static Future<void> _applyDiscoveredIp(String ip) async {
    await ApiConfig.saveIp(ip);
    AiConfig.setIp(ip);
    DioClient().dio.options.baseUrl = ApiConfig.baseUrl;
    _discovered = true;

    if (kDebugMode) {
      print('[Discovery] ✅ Found backend at $ip');
      print('[Discovery] API URL: ${ApiConfig.baseUrl}');
    }
  }

  /// Scan the local subnet for the backend server.
  /// Gets the device's own IP to determine the subnet, then pings all IPs in parallel.
  static Future<String?> _scanSubnet() async {
    try {
      // Get the device's network interfaces to determine subnet
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface_ in interfaces) {
        for (final addr in interface_.addresses) {
          final ip = addr.address;
          // Skip non-private IPs
          if (!ip.startsWith('192.168.') && !ip.startsWith('10.') && !ip.startsWith('172.')) {
            continue;
          }

          if (kDebugMode) print('[Scan] Device IP: $ip on ${interface_.name}');

          // Calculate subnet prefix (e.g., "192.168.0.")
          final parts = ip.split('.');
          if (parts.length != 4) continue;
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
          final myLastOctet = int.tryParse(parts[3]) ?? 0;

          // Scan common IPs first (gateway, low IPs, then rest)
          // Prioritize common server addresses
          final priorityIPs = <int>[1, 2, 100, 101, 102, 117, 200, 254];
          final allIPs = <int>[];
          
          // Add priority IPs first
          for (final ip in priorityIPs) {
            if (ip != myLastOctet) allIPs.add(ip);
          }
          // Then add remaining IPs
          for (int i = 2; i <= 254; i++) {
            if (i != myLastOctet && !priorityIPs.contains(i)) {
              allIPs.add(i);
            }
          }

          // Scan in batches of 50 to avoid overwhelming the network
          const batchSize = 50;
          for (int batch = 0; batch < allIPs.length; batch += batchSize) {
            final end = (batch + batchSize).clamp(0, allIPs.length);
            final batchIPs = allIPs.sublist(batch, end);

            final results = await Future.wait(
              batchIPs.map((lastOctet) => _checkHost('$subnet$lastOctet')),
            );

            for (int i = 0; i < results.length; i++) {
              if (results[i]) {
                return '$subnet${batchIPs[i]}';
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[Scan] Error: $e');
    }
    return null;
  }

  /// Check if a specific host has the OJT backend running
  static Future<bool> _checkHost(String host) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 300);
      final request = await client.getUrl(
        Uri.parse('http://$host:$_apiPort/api/health'),
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 500),
      );
      client.close(force: true);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Try UDP probe discovery
  static Future<String?> _udpProbe() async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 0,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final completer = Completer<String?>();
      final timer = Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            final msg = String.fromCharCodes(datagram.data).trim();
            if (msg.startsWith('OJT_SERVER:')) {
              final host = datagram.address.address;
              if (host != '0.0.0.0' && host != '127.0.0.1') {
                timer.cancel();
                if (!completer.isCompleted) completer.complete(host);
              }
            }
          }
        }
      });

      // Send probes
      final probeData = 'OJT_DISCOVER'.codeUnits;
      for (int i = 0; i < 3; i++) {
        if (i > 0) await Future.delayed(const Duration(milliseconds: 500));
        if (completer.isCompleted) break;
        socket.send(probeData, InternetAddress('255.255.255.255'), _udpPort);
      }

      final result = await completer.future;
      socket.close();
      return result;
    } catch (e) {
      if (kDebugMode) print('[UDP] Error: $e');
      socket?.close();
      return null;
    }
  }

  /// Check if the backend is reachable at the current API URL.
  static Future<bool> checkHealth() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse('${ApiConfig.baseUrl}/health'),
      );
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Reset discovery cache (useful for Wi-Fi changes)
  static void reset() => _discovered = false;
}

