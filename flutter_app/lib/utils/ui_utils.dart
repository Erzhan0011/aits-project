import 'package:flutter/material.dart';

class UiUtils {
  static void showNotification({
    required BuildContext context,
    required String message,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final String translatedMessage = _translate(message);
    
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _SlideDownNotification(
            message: translatedMessage,
            isError: isError,
            onDismiss: () {
              if (overlayEntry.mounted) {
                overlayEntry.remove();
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  static String _translate(String message) {
    // 1. Strip technical clutter
    String msg = message
        .replaceAll('Exception: ', '')
        .replaceAll('Exception', '')
        .replaceAll('DioError: ', '')
        .replaceAll('DioException', '')
        .trim();

    // 2. Exact mappings
    final Map<String, String> mappings = {
      'Invalid credentials': 'Неверный логин или пароль',
      'Email already registered': 'Этот email уже зарегистрирован',
      'Aircraft is already busy': 'Самолёт уже занят в это время',
      'Airport not found': 'Аэропорт не найден',
      'Flight conflict': 'Конфликт расписания рейсов',
      'Validation error': 'Ошибка проверки данных',
      'Unauthorized': 'Требуется авторизация',
      'Forbidden': 'Доступ запрещен',
      'Not Found': 'Ресурс не найден',
      'Bad Request': 'Некорректный запрос',
      'Connection timeout': 'Превышено время ожидания соединения',
      'Network unreachable': 'Сеть недоступна',
    };

    for (var entry in mappings.entries) {
      if (msg.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // 3. Smart fallbacks for backend templates
    if (msg.contains('is already busy on flight')) {
      return msg.replaceAll('Aircraft #', 'Самолёт №')
                 .replaceAll('is already busy on flight', 'уже занят на рейсе')
                 .replaceAll('during this time', 'в это время');
    }

    if (msg.isEmpty) return 'Произошла неизвестная ошибка';
    
    return msg;
  }
}

class _SlideDownNotification extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _SlideDownNotification({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_SlideDownNotification> createState() => _SlideDownNotificationState();
}

class _SlideDownNotificationState extends State<_SlideDownNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    // Start animation
    _controller.forward();

    // Auto dismiss after CD
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: widget.isError ? Colors.red[600] : Colors.green[600],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
