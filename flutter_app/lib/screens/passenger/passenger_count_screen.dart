import 'package:flutter/material.dart';
import '../../models/flight.dart';
import '../../utils/app_router.dart';
import '../../utils/ui_utils.dart';

class PassengerCountScreen extends StatefulWidget {
  final Flight flight;

  const PassengerCountScreen({super.key, required this.flight});

  @override
  State<PassengerCountScreen> createState() => _PassengerCountScreenState();
}

class _PassengerCountScreenState extends State<PassengerCountScreen> {
  int _passengerCount = 1;

  void _increment() {
    if (_passengerCount < widget.flight.availableSeats) {
      setState(() {
        _passengerCount++;
      });
    } else {
      UiUtils.showNotification(
        context: context,
        message: 'Достигнуто максимальное количество доступных мест',
        isError: true,
      );
    }
  }

  void _decrement() {
    if (_passengerCount > 1) {
      setState(() {
        _passengerCount--;
      });
    }
  }

  void _continue() {
    if (_passengerCount > widget.flight.availableSeats) {
       UiUtils.showNotification(
        context: context,
        message: 'Недостаточно свободных мест',
        isError: true,
      );
      return;
    }

    Navigator.pushNamed(
      context, 
      AppRouter.seatSelection,
      arguments: {
        'flight': widget.flight,
        'passengersCount': _passengerCount,
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Количество пассажиров')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Выберите количество пассажиров',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: _passengerCount > 1 ? _decrement : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 24),
                Text(
                  '$_passengerCount',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(width: 24),
                IconButton.filledTonal(
                  onPressed: _passengerCount < widget.flight.availableSeats ? _increment : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
             const SizedBox(height: 16),
            Text(
              'Доступно мест: ${widget.flight.availableSeats}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _passengerCount > 0 ? _continue : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Продолжить'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
