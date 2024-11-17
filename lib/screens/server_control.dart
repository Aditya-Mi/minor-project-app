import 'dart:async';

import 'package:flutter/material.dart';
import 'package:minor_project/services/api_service.dart';
import '../services/shared_prefs_service.dart';
import '../utils/logger.dart';

class ServerControlScreen extends StatefulWidget {
  const ServerControlScreen({super.key});

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  bool _isServerRunning = false;
  bool _isLoading = false;
  String? _fcmToken;
  String? _statusMessage;
  Timer? _statusCheckTimer;
  ApiService apiService = ApiService(); // Flask server URL

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _startStatusCheck();
    _loadToken();
  }

  Future<void> _simulateFireAlert() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await apiService.requestFireAlert(_fcmToken);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Fire alert sent successfully!'
                : 'Failed to send fire alert',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadToken() async {
    final token = await SharedPrefsService.getToken();
    setState(() {
      _fcmToken = token;
    });
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkServerStatus(),
    );
  }

  Future<void> _checkServerStatus() async {
    try {
      final data = await apiService.checkServerStatus();
      setState(() {
        _isServerRunning = data['streaming_status']['is_active'] ?? false;
        _statusMessage = _isServerRunning
            ? 'Server streaming is active\n${_formatMetrics(data)}'
            : 'Server streaming is stopped';
      });
    } catch (e) {
      setState(() {
        _isServerRunning = false;
        _statusMessage = 'Error checking server status: $e';
      });
      Logger.error('Status check error', e);
    }
  }

  String _formatMetrics(Map<String, dynamic> data) {
    if (!data.containsKey('metrics')) return '';

    final metrics = data['metrics'];
    return '''
FPS: ${metrics['fps']?.toStringAsFixed(1) ?? 'N/A'}
Processing Time: ${metrics['processing_time_ms']?.toStringAsFixed(1) ?? 'N/A'} ms
Dropped Frames: ${metrics['dropped_frames'] ?? 'N/A'}
Queue Size: ${metrics['queue_size'] ?? 'N/A'}
''';
  }

  Future<void> _startStream() async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          _isServerRunning ? 'Stopping stream...' : 'Starting stream...';
    });
    try {
      final data = await apiService.startStream();
      setState(() {
        _statusMessage = data['message'];
      });
      _checkServerStatus(); // Update status immediately
    } catch (e, stackTrace) {
      Logger.error('Server control error', e, stackTrace);
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stopStream() async {
    setState(() {
      _isLoading = true;
      _statusMessage =
          _isServerRunning ? 'Stopping stream...' : 'Starting stream...';
    });
    try {
      final data = await apiService.stopStream();
      setState(() {
        _statusMessage = data['message'];
      });
      _checkServerStatus(); // Update status immediately
    } catch (e, stackTrace) {
      Logger.error('Server control error', e, stackTrace);
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stream Control'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isServerRunning
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isServerRunning ? Colors.green : Colors.red,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isServerRunning ? Icons.videocam : Icons.videocam_off,
                    size: 48,
                    color: _isServerRunning ? Colors.green : Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage ?? 'Checking stream status...',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton.icon(
                onPressed: _isServerRunning ? _stopStream : _startStream,
                icon: Icon(
                  _isServerRunning ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                ),
                label: Text(
                  _isServerRunning ? 'Stop Stream' : 'Start Stream',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isServerRunning ? Colors.red : Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _simulateFireAlert,
              label: const Text(
                'Fire',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              icon: const Icon(
                Icons.fire_extinguisher,
                color: Colors.white,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}
