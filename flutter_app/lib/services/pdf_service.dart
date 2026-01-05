import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/trip.dart';
import 'package:intl/intl.dart';

class PdfService {
  static const PdfColor primaryOrange = PdfColor.fromInt(0xFFFF6B35);
  static const PdfColor darkBlue = PdfColor.fromInt(0xFF001F3F);
  static const PdfColor backgroundGray = PdfColor.fromInt(0xFFF5F7FA);

  static Future<void> generateAndSaveTicket(Trip trip, String passengerName) async {
    final pdf = pw.Document();
    final flight = trip.flight;
    final formatter = DateFormat('HH:mm, dd MMM yyyy');

    String getDummyCode(String city) {
      if (city.length >= 3) return city.substring(0, 3).toUpperCase();
      return city.toUpperCase();
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
            ),
            child: pw.Row(
              children: [
                // MAIN PART
                pw.Expanded(
                  flex: 3,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(25),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Header
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('BOARDING PASS', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                                pw.Text('ANTIGRAVITY AIRLINES', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryOrange)),
                              ],
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: const pw.BoxDecoration(color: darkBlue, borderRadius: pw.BorderRadius.all(pw.Radius.circular(5))),
                              child: pw.Text('E-TICKET', style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 30),
                        
                        // Origin - Destination
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCityNode(flight.departureCity, getDummyCode(flight.departureCity), formatter.format(flight.departureTime)),
                            pw.Column(
                              children: [
                                pw.Text('NON-STOP', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                                pw.Container(width: 100, height: 1.5, color: primaryOrange),
                                pw.Text('FLIGHT ${flight.flightNumber}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                            _buildCityNode(flight.arrivalCity, getDummyCode(flight.arrivalCity), formatter.format(flight.arrivalTime)),
                          ],
                        ),
                        pw.SizedBox(height: 30),

                        // Details Grid
                        pw.Row(
                          children: [
                            _buildMainDetail('PASSENGER NAME', passengerName.toUpperCase()),
                            pw.SizedBox(width: 40),
                            _buildMainDetail('SEAT', trip.seatNumber),
                            pw.SizedBox(width: 40),
                            _buildMainDetail('CLASS', 'ECONOMY'),
                          ],
                        ),
                        pw.SizedBox(height: 20),
                        pw.Row(
                          children: [
                            _buildMainDetail('GATE', trip.gate ?? 'A1'),
                            pw.SizedBox(width: 40),
                            _buildMainDetail('TERMINAL', trip.terminal),
                            pw.SizedBox(width: 40),
                            _buildMainDetail('PNR CODE', trip.pnr),
                          ],
                        ),
                        
                        pw.Spacer(),
                        pw.Text('Notice: Gates close 20 minutes before departure.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ),
                ),

                // PERFORATION LINE
                pw.Container(
                  width: 1,
                  height: double.infinity,
                  child: pw.Column(
                    children: List.generate(20, (index) => pw.Container(height: 10, width: 1, color: index.isEven ? PdfColors.grey300 : PdfColors.white)),
                  ),
                ),

                // STUB PART
                pw.Expanded(
                  flex: 1,
                  child: pw.Container(
                    color: backgroundGray,
                    padding: const pw.EdgeInsets.all(20),
                    child: pw.Column(
                      children: [
                        pw.Text('FLIGHT STUB', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 15),
                        pw.Text(getDummyCode(flight.departureCity), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('TO', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                        pw.Text(getDummyCode(flight.arrivalCity), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 20),
                        _buildStubDetail('PASSENGER', passengerName.split(' ')[0]),
                        _buildStubDetail('SEAT', trip.seatNumber),
                        _buildStubDetail('FLIGHT', flight.flightNumber),
                        
                        pw.Spacer(),
                        // THE CUSTOM QR CODE (Redirect to photo)
                        pw.Container(
                          width: 80,
                          height: 80,
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(color: PdfColors.white, border: pw.Border.all(color: PdfColors.grey300)),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'https://elqr.kz/b39f7d69-6d7f-479a-a3d0-e36d7a3c91a3',
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('SCAN ME', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryOrange)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final fileName = 'Premium_Ticket_${trip.pnr}.pdf';
    await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
  }

  static pw.Widget _buildCityNode(String city, String code, String time) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(code, style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: darkBlue)),
        pw.Text(city, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(time, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ],
    );
  }

  static pw.Widget _buildMainDetail(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildStubDetail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
