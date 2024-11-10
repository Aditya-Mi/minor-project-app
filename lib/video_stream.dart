import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'connection_manager.dart';
import 'logger.dart';

class VideoStream extends StatefulWidget {
  const VideoStream({super.key});

  @override
  State<VideoStream> createState() => _VideoStreamState();
}

class _VideoStreamState extends State<VideoStream> {
  late ConnectionManager _connectionManager;
  StreamSubscription? _streamSubscription;
  Uint8List? _imageBytes;
  String? _lastTimestamp;
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false; // New flag for manual disconnection
  String? _errorMessage;
  Timer? _healthCheckTimer;

  // Connection statistics
  int _framesReceived = 0;
  int _errorCount = 0;
  DateTime? _lastFrameTime;
  double _fps = 0.0;

  double _processingTime = 0;
  int _droppedFrames = 0;
  int _queueSize = 0;

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

  // void _updateStats() {
  //   if (_lastFrameTime != null) {
  //     final now = DateTime.now();
  //     final duration = now.difference(_lastFrameTime!);
  //     if (duration.inMilliseconds > 0) {
  //       setState(() {
  //         _fps = 1000 / duration.inMilliseconds;
  //       });
  //     }
  //     _lastFrameTime = now;
  //   } else {
  //     _lastFrameTime = DateTime.now();
  //   }
  // }

  // In _VideoStreamState:
  Future<void> _initConnection() async {
    if (_isConnected || _isManuallyDisconnected) return;

    try {
      setState(() {
        _errorMessage = null;
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
        _errorMessage = null;
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
      _errorMessage = 'Manually disconnected';
    });
  }

  void _handleMessage(dynamic message) {
    if (!mounted || _isManuallyDisconnected) return;

    try {
      Logger.log('Processing message: ${message.toString().substring(0, 100)}...'); // Debug log

      final data = jsonDecode(message);
      final bytes = base64Decode(data['frame']);
      final metrics = data['metrics'];

      setState(() {
        _imageBytes = bytes;
        _lastTimestamp = data['timestamp'];
        _errorMessage = null;
        _framesReceived++;

        // Update metrics from server
        _fps = metrics['fps']?.toDouble() ?? 0.0;
        _processingTime = metrics['processing_time']?.toDouble() ?? 0.0;
        _droppedFrames = metrics['dropped_frames'] ?? 0;
        _queueSize = metrics['queue_size'] ?? 0;
      });
    } catch (e, stackTrace) {
      Logger.error('Frame processing error', e, stackTrace);
      setState(() {
        _errorCount++;
        _errorMessage = 'Frame processing error: $e';
      });
    }
  }

  void _handleError(dynamic error) {
    if (!mounted || _isManuallyDisconnected) return;

    Logger.error('WebSocket error occurred', error);
    setState(() {
      _isConnected = false;
      _errorMessage = 'Connection error: $error';
      _errorCount++;
    });

    if (_connectionManager.canRetry && !_isManuallyDisconnected) {
      _connectionManager.scheduleRetry(_initConnection);
    } else {
      _errorMessage = 'Connection failed. Please try reconnecting.';
    }
  }

  Widget _buildMetricsBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Processing Metrics:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('FPS: ${_fps.toStringAsFixed(1)}'),
              Text('Process Time: ${_processingTime.toStringAsFixed(1)}ms'),
              Text('Dropped: $_droppedFrames'),
              Text('Queue: $_queueSize'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: _isConnected
          ? Colors.green.shade100
          : _isManuallyDisconnected
              ? Colors.grey.shade100
              : Colors.yellow.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  _isConnected
                      ? Icons.check_circle
                      : _isManuallyDisconnected
                          ? Icons.offline_bolt
                          : Icons.warning,
                  color: _isConnected
                      ? Colors.green
                      : _isManuallyDisconnected
                          ? Colors.grey
                          : Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorMessage ??
                      (_isConnected
                          ? 'Connected to ${_connectionManager.wsUrl}'
                          : _isManuallyDisconnected
                              ? 'Manually disconnected'
                              : _isLoading
                                  ? 'Connecting...'
                                  : 'Disconnected'),
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
              // Connection control button
              _isConnected
                  ? ElevatedButton(
                      onPressed: _disconnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isConnected ? Colors.red : Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Disconnect'),
                    )
                  : const SizedBox()
            ],
          ),
          if (_isConnected) ...[
            const SizedBox(height: 4),
            Text(
              'Stats: ${_fps.toStringAsFixed(1)} FPS | '
              'Frames: $_framesReceived | '
              'Errors: $_errorCount',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
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
            _buildStatusBar(),
            if (_isConnected) _buildMetricsBar(),
            Expanded(
              child: Center(
                child: _isConnected
                    ? (_imageBytes != null
                    ? Image.memory(
                  _imageBytes!,
                  gaplessPlayback: true,
                  fit: BoxFit.contain,
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
            if (_lastTimestamp != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Last frame: $_lastTimestamp'),
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
