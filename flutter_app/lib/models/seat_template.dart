
class SeatTemplate {
  final int id;
  final String name;
  final int rowCount;
  final String seatLetters;
  final String? businessRows;
  final String? economyRows;
  final Map<String, dynamic>? seatMap;

  SeatTemplate({
    required this.id,
    required this.name,
    required this.rowCount,
    required this.seatLetters,
    this.businessRows,
    this.economyRows,
    this.seatMap,
  });

  factory SeatTemplate.fromJson(Map<String, dynamic> json) {
    return SeatTemplate(
      id: json['id'],
      name: json['name'],
      rowCount: json['row_count'],
      seatLetters: json['seat_letters'],
      businessRows: json['business_rows'],
      economyRows: json['economy_rows'],
      seatMap: json['seat_map'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'row_count': rowCount,
      'seat_letters': seatLetters,
      'business_rows': businessRows,
      'economy_rows': economyRows,
      'seat_map': seatMap,
    };
  }
}
