import 'package:flutter/material.dart';

class FlightManagementScreen extends StatelessWidget {
  const FlightManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление рейсами'),
      ),
      body: const Center(
        child: Text('Управление рейсами (в разработке)'),
      ),
    );
  }
}



