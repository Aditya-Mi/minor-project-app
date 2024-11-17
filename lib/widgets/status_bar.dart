import 'package:flutter/material.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.isConnected,
    required this.fps,
    required this.onPressed,
  });
  final bool isConnected;
  final double fps;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isConnected ? Colors.green.shade100 : Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.check_circle : Icons.error_outline,
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(isConnected ? 'Connected' : 'Disconnected'),
            ],
          ),
          if (isConnected) ...[
            Text('FPS: ${fps.toStringAsFixed(1)}'),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Disconnect'),
            ),
          ],
        ],
      ),
    );
  }
}
