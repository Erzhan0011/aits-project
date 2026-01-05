class PaymentItem {
  final String pnr;
  final int bookingId;
  final double amount;
  final String seatNumber;

  PaymentItem({
    required this.pnr,
    required this.bookingId,
    required this.amount,
    required this.seatNumber,
  });

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    return PaymentItem(
      pnr: (json['pnr'] ?? 'N/A').toString(),
      bookingId: json['booking_id'] as int? ?? 0,
      amount: (json['amount'] as num? ?? 0).toDouble(),
      seatNumber: (json['seat_number'] ?? '').toString(),
    );
  }
}

class Payment {
  final String transactionId;
  final double amount;
  final String currency;
  final String method;
  final String status;
  final DateTime createdAt;
  final String flightInfo;
  final List<PaymentItem> items;

  Payment({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.flightInfo,
    required this.items,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    var itemsList = <PaymentItem>[];
    if (json['items'] != null) {
      itemsList = (json['items'] as List)
          .map((i) => PaymentItem.fromJson(i))
          .toList();
    }

    return Payment(
      transactionId: (json['transaction_id'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'RUB').toString(),
      method: (json['method'] ?? 'CARD').toString(),
      status: (json['status'] ?? 'SUCCESS').toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
      flightInfo: (json['flight_info'] ?? 'Unknown').toString(),
      items: itemsList,
    );
  }

  String get methodText {
    switch (method.toUpperCase()) {
      case 'CARD': return 'Банковская карта';
      case 'APPLE_PAY': return 'Apple Pay';
      case 'GOOGLE_PAY': return 'Google Pay';
      default: return method;
    }
  }

  String get statusText {
    switch (status.toUpperCase()) {
      case 'SUCCESS': return 'Успешно';
      case 'FAILED': return 'Ошибка';
      case 'REFUNDED': return 'Возврат';
      case 'PENDING': return 'В обработке';
      default: return status;
    }
  }
}

class StaffPayment {
  final int id;
  final String transactionId;
  final int bookingId;
  final int passengerId;
  final String passengerName;
  final double amount;
  final String currency;
  final String method;
  final String status;
  final DateTime createdAt;
  final String pnr;
  final String flightInfo;

  StaffPayment({
    required this.id,
    required this.transactionId,
    required this.bookingId,
    required this.passengerId,
    required this.passengerName,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.pnr,
    required this.flightInfo,
  });

  factory StaffPayment.fromJson(Map<String, dynamic> json) {
    return StaffPayment(
      id: json['id'] as int? ?? 0,
      transactionId: (json['transaction_id'] ?? '').toString(),
      bookingId: json['booking_id'] as int? ?? 0,
      passengerId: json['passenger_id'] as int? ?? 0,
      passengerName: (json['passenger_name'] ?? 'Unknown').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'RUB').toString(),
      method: (json['method'] ?? 'CARD').toString(),
      status: (json['status'] ?? 'SUCCESS').toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']).toLocal() 
          : DateTime.now(),
      pnr: (json['pnr'] ?? 'N/A').toString(),
      flightInfo: (json['flight_info'] ?? 'Unknown').toString(),
    );
  }

  String get methodText {
    switch (method.toUpperCase()) {
      case 'CARD': return 'Банковская карта';
      case 'APPLE_PAY': return 'Apple Pay';
      case 'GOOGLE_PAY': return 'Google Pay';
      default: return method;
    }
  }

  String get statusText {
    switch (status.toUpperCase()) {
      case 'SUCCESS': return 'Успешно';
      case 'FAILED': return 'Ошибка';
      case 'REFUNDED': return 'Возврат';
      case 'PENDING': return 'В обработке';
      default: return status;
    }
  }
}
