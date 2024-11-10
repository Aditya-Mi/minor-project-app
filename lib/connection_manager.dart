import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'logger.dart';

class ConnectionManager {
  final String host;
  final int port;
  final int maxRetries;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;

  int _retryCount = 0;
  Timer? _retryTimer;
  Duration _currentDelay;
  WebSocketChannel? _channel;
  StreamController<dynamic>? _streamController;
  Stream<dynamic>? get stream => _streamController?.stream;
  bool _isStreamStarted = false;

  // Add connection state for better tracking
  bool _isConnecting = false;
  bool _isDisposed = false;

  ConnectionManager({
    required this.host,
    required this.port,
    this.maxRetries = 5,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
  }) : _currentDelay = initialRetryDelay;

  String get wsUrl => 'ws://$host:$port';
  String get _baseApiUrl => 'http://$host:5000';
  String get healthCheckUrl => 'http://$host:${port + 1}/health';

  Future<bool> checkServerStatus() async {
    try {
      final flaskResponse = await http.get(Uri.parse('$_baseApiUrl/health'))
          .timeout(const Duration(seconds: 5));
      Logger.log('Health check response: ${flaskResponse.body}');
      return flaskResponse.statusCode == 200;
    } catch (e) {
      Logger.log('Server health check failed: $e');
      return false;
    }
  }

  Future<void> connect() async {
    if (_isDisposed) {
      Logger.log('Attempting to connect after disposal');
      return;
    }

    if (_isConnecting) {
      Logger.log('Connection already in progress');
      return;
    }

    if (_channel != null) {
      Logger.log('Channel already exists, cleaning up first');
      _cleanup();
    }

    _isConnecting = true;
    _isStreamStarted = true;

    try {
      Logger.log('Connecting to WebSocket: $wsUrl');

      // Add connection timeout
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection with timeout
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timed out');
        },
      );

      _streamController = StreamController<dynamic>.broadcast();

      // Add ping/pong mechanism to keep connection alive
      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_channel != null && !_isDisposed) {
          try {
            _channel!.sink.add('ping');
            Logger.log('Ping sent');
          } catch (e) {
            Logger.log('Error sending ping: $e');
            timer.cancel();
            _handleConnectionError();
          }
        } else {
          timer.cancel();
        }
      });

      _channel!.stream.listen(
            (data) {
          if (data == 'pong') {
            Logger.log('Received pong from server');
            return;
          }

          Logger.log('Received WebSocket data: ${data.length} bytes');
          if (_streamController?.isClosed == false) {
            _streamController?.add(data);
          }
          resetRetryCount();
        },
        onError: (error) {
          Logger.log('WebSocket error: $error');
          _handleConnectionError();
        },
        onDone: () {
          Logger.log('WebSocket connection closed normally');
          _handleConnectionError();
        },
        cancelOnError: false,
      );

      Logger.log('WebSocket connection established successfully');
    } catch (e) {
      Logger.log('Connection error: $e');
      _handleConnectionError();
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  void _handleConnectionError() {
    if (_isDisposed) return;

    _cleanup();
    if (canRetry && _isStreamStarted) {
      scheduleRetry(() => connect());
    }
  }

  void resetRetryCount() {
    _retryCount = 0;
    _currentDelay = initialRetryDelay;
    _retryTimer?.cancel();
  }

  Duration _getNextRetryDelay() {
    final delay = _currentDelay;
    _currentDelay = Duration(milliseconds:
    (delay.inMilliseconds * 1.5).toInt().clamp(
        initialRetryDelay.inMilliseconds,
        maxRetryDelay.inMilliseconds
    )
    );
    return delay;
  }

  bool get canRetry => _retryCount < maxRetries;

  void scheduleRetry(Function() onRetry) {
    if (!canRetry || _isDisposed) {
      Logger.log('Max retry attempts reached or manager disposed');
      return;
    }

    _retryCount++;
    final delay = _getNextRetryDelay();
    Logger.log('Scheduling retry #$_retryCount in ${delay.inSeconds} seconds');

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, onRetry);
  }

  void _cleanup() {
    try {
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      Logger.log('Error during cleanup: $e');
    }
  }

  void dispose() {
    _isDisposed = true;
    _isStreamStarted = false;
    _retryTimer?.cancel();
    _channel?.sink.close();
    _streamController?.close();
    _channel = null;
    _streamController = null;
  }
}