import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:minor_project/widgets/detection_painter.dart';
import 'package:minor_project/widgets/status_bar.dart';

import '../services/connection_manager.dart';
import '../utils/logger.dart';

class VideoStream extends StatefulWidget {
  const VideoStream({super.key});

  @override
  State<VideoStream> createState() => _VideoStreamState();
}

class _VideoStreamState extends State<VideoStream> {
  late ConnectionManager _connectionManager;
  StreamSubscription? _streamSubscription;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;
  Timer? _healthCheckTimer;

  // Added new metrics to match server
  double _fps = 0.0;
  int _personCount = 0; // New: track detected persons
  List<Map<String, dynamic>> _detections = []; // New: store person detections

  @override
  void initState() {
    super.initState();
    _connectionManager = ConnectionManager(
      host: '192.168.2.159', // Change to 'localhost' for iOS
      port: 8765,
      maxRetries: 5,
      initialRetryDelay: const Duration(seconds: 2),
      maxRetryDelay: const Duration(seconds: 30),
    );
  }

  void _startHealthCheck() {
    _healthCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isConnected && !_isManuallyDisconnected) {
        // Don't check if manually disconnected
        final isServerUp = await _connectionManager.checkServerStatus();
        Logger.log('Server health check: ${isServerUp ? 'UP' : 'DOWN'}');
        if (isServerUp && !_isConnected) {
          _initConnection();
        }
      }
    });
  }

  // In _VideoStreamState:
  Future<void> _initConnection() async {
    if (_isConnected || _isManuallyDisconnected) return;

    // await _streamSubscription?.cancel();
    // _streamSubscription = null;
    // _imageBytes = null;

    try {
      setState(() {
        _isLoading = true;
      });

      // First connect the WebSocket
      await _connectionManager.connect();

      // Then listen to the stream
      _streamSubscription = _connectionManager.stream?.listen(
        (data) {
          Logger.log('Received frame data'); // Debug log
          _handleMessage(data);
        },
        onError: (error) {
          Logger.log('Stream error: $error'); // Debug log
          _handleError(error);
        },
        onDone: () {
          Logger.log('Stream closed'); // Debug log
          if (!_isManuallyDisconnected) {
            _handleError('Connection closed unexpectedly');
          }
        },
      );

      if (_streamSubscription == null) {
        throw Exception('Failed to establish stream connection');
      }

      setState(() {
        _isConnected = true;
        _isLoading = false;
      });
    } catch (e) {
      Logger.log('Connection error: $e'); // Debug log
      _handleError(e);
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isManuallyDisconnected = true;
      _isConnected = false;
    });

    // Cancel the stream subscription
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    // Dispose the connection manager
    _connectionManager.dispose();

    setState(() {
      _imageBytes = null;
    });
  }

  void _handleMessage(dynamic message) {
    if (!mounted || _isManuallyDisconnected) return;

    try {
      Logger.log(
          'Processing message: ${message.toString().substring(0, 100)}...');

      final data = jsonDecode(message);
      final bytes = base64Decode(data['frame']);
      final metrics = data['metrics'];
      final detections = List<Map<String, dynamic>>.from(
          data['detections'] ?? []); // New: handle detections

      setState(() {
        _imageBytes = bytes;
        _fps = metrics['current_fps']?.toDouble() ?? 0.0;
        _personCount = metrics['person_count'] ?? 0; // New
        _detections = detections; // New
      });
    } catch (e, stackTrace) {
      Logger.error('Frame processing error', e, stackTrace);
    }
  }

  void _handleError(dynamic error) {
    if (!mounted || _isManuallyDisconnected) return;

    Logger.error('WebSocket error occurred', error);
    setState(() {
      _isConnected = false;
    });

    if (_connectionManager.canRetry && !_isManuallyDisconnected) {
      _connectionManager.scheduleRetry(_initConnection);
    } else {
      Logger.log('Connection failed. Please try reconnecting.');
    }
  }

  Widget _buildDetectionOverlay() {
    if (_imageBytes == null) return const SizedBox();

    return CustomPaint(
      size: Size.infinite,
      painter: DetectionPainter(
        detections: _detections,
        imageBytes: _imageBytes!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Video'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            StatusBar(isConnected: _isConnected, fps: _fps, onPressed: _disconnect),
            Expanded(
              child: Center(
                child: _isConnected
                    ? (_imageBytes != null
                        ? Stack(
                            children: [
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: _personCount > 0
                                              ? Colors.red
                                              : Colors.transparent,
                                          width: 2)),
                                  child: Image.memory(
                                    _imageBytes!,
                                    gaplessPlayback: true,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Center(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SizedBox(
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      child: _buildDetectionOverlay(),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : const CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isManuallyDisconnected = false;
                          });
                          _startHealthCheck();
                        },
                        child: const Text('Connect'),
                      ),
              ),
            ),
            if (_personCount > 0)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⚠️ Person Detected!',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _connectionManager.dispose();
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}
