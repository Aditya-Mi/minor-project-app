// server_control.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/logger.dart';

class ServerControlScreen extends StatefulWidget {
  const ServerControlScreen({super.key});

  @override
  State<ServerControlScreen> createState() => _ServerControlScreenState();
}

class _ServerControlScreenState extends State<ServerControlScreen> {
  bool _isServerRunning = false;
  bool _isLoading = false;
  String? _statusMessage;
  Timer? _statusCheckTimer;
  final String _baseUrl = 'http://192.168.2.159:5000'; // Flask server URL

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
    _startStatusCheck();
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _checkServerStatus(),
    );
  }

  Future<void> _checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isServerRunning = data['streaming_status']['is_active'] ?? false;
          _statusMessage = _isServerRunning
              ? 'Server streaming is active\n${_formatMetrics(data)}'
              : 'Server streaming is stopped';
        });
      } else {
        throw Exception('Failed to get server status');
      }
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
      _statusMessage = _isServerRunning ? 'Stopping stream...' : 'Starting stream...';
    });
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stream/start'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _statusMessage = data['message'];
        });
        _checkServerStatus(); // Update status immediately
      } else {
        throw Exception('Failed to start server');
      }
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
      _statusMessage = _isServerRunning ? 'Stopping stream...' : 'Starting stream...';
    });
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/stream/stop'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _statusMessage = data['message'];
        });
        _checkServerStatus(); // Update status immediately
      } else {
        throw Exception('Failed to stop server');
      }
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
                color: _isServerRunning ? Colors.green.shade100 : Colors.red.shade100,
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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