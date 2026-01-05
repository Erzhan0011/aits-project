import 'package:flutter/material.dart';
import 'dart:async';

class BookingTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;

  const BookingTimer({
    super.key,
    required this.expiresAt,
    required this.onExpired,
  });

  @override
  State<BookingTimer> createState() => _BookingTimerState();
}

class _BookingTimerState extends State<BookingTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final difference = widget.expiresAt.difference(now);
    
    // Add a small buffer (e.g. 500ms) to prevent flickering at 0
    if (difference.isNegative) {
      _remaining = Duration.zero;
    } else {
      _remaining = difference;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _calculateRemaining();
        if (_remaining.inSeconds < 0) {
          _timer.cancel();
          // Defer callback to avoid calling setState while building
          Future.microtask(() {
            if (mounted) widget.onExpired();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.inSeconds <= 0) {
      return Container();
    }

    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final isWarning = _remaining.inMinutes < 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFCDD2) : const Color(0xFFFFE0B2), // red[100], orange[100]
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWarning ? Colors.red : Colors.orange,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            color: isWarning ? Colors.red : const Color(0xFFE65100), // orange[900]
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Осталось времени на оплату: $timeStr',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning ? const Color(0xFFB71C1C) : const Color(0xFFE65100), // red[900], orange[900]
            ),
          ),
          if (isWarning) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}
