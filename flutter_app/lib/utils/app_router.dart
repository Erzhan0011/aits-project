import 'package:flutter/material.dart';
import '../models/flight.dart';
import '../models/trip.dart';
import '../models/passenger_form_data.dart';
import '../screens/passenger/ticket_detail_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/passenger/home_screen.dart';
import '../screens/passenger/flight_details_screen.dart';
import '../screens/passenger/passenger_count_screen.dart';
import '../screens/passenger/seat_selection_screen.dart';
import '../screens/passenger/passenger_details_screen.dart';
import '../screens/passenger/payment_screen.dart';
import '../screens/passenger/checkin_screen.dart';
import '../screens/passenger/profile_screen.dart';
import '../screens/passenger/edit_profile_screen.dart';
import '../screens/splash_screen.dart';

import '../screens/staff/staff_dashboard_screen.dart';
import '../screens/staff/manage_flights_screen.dart';
import '../screens/staff/manage_airports_screen.dart';
import '../screens/staff/manage_users_screen.dart';
import '../screens/staff/manage_bookings_screen.dart';
import '../screens/staff/manage_aircrafts_screen.dart';
import '../screens/staff/manage_seats_screen.dart';
import '../screens/staff/manage_announcements_screen.dart';
import '../screens/staff/aircraft_detail_screen.dart';
import '../screens/staff/airport_detail_screen.dart';
import '../screens/staff/manage_payments_screen.dart';
import '../screens/passenger/my_trips_screen.dart';
import '../screens/passenger/payment_history_screen.dart';
import '../screens/staff/manage_seat_templates_screen.dart';
import '../screens/staff/create_seat_template_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String flightDetails = '/flight-details';
  static const String passengerCount = '/passenger-count';
  static const String seatSelection = '/seat-selection';
  static const String passengerDetails = '/passenger-details';
  static const String payment = '/payment';
  static const String myBookings = '/my-bookings';
  static const String checkin = '/check-in';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String ticketDetail = '/ticket-detail';
  static const String paymentHistory = '/payment-history';
  
  // Staff routes
  static const String staffDashboard = '/staff/dashboard';
  static const String manageFlights = '/staff/flights/manage';
  static const String manageAirports = '/staff/airports/manage';
  static const String manageUsers = '/staff/users/manage';
  static const String manageBookings = '/staff/bookings/manage';
  static const String manageSeats = '/staff/flights/seats';
  static const String manageAircrafts = '/staff/aircrafts/manage';
  static const String manageAnnouncements = '/staff/announcements/manage';
  static const String managePayments = '/staff/payments/manage';
  static const String staffAircraftDetail = '/staff/aircraft/detail';
  static const String staffAirportDetail = '/staff/airport/detail';
  static const String manageSeatTemplates = '/staff/seat-templates/manage';
  static const String staffCreateSeatTemplate = '/staff/seat-templates/create';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case flightDetails:
        final flightId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => FlightDetailsScreen(flightId: flightId), // Keep for history/viewing
        );
      case passengerCount:
        final flight = settings.arguments as Flight;
        return MaterialPageRoute(
          builder: (_) => PassengerCountScreen(flight: flight),
        );
      case seatSelection:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => SeatSelectionScreen(
            flight: args['flight'] as Flight,
            passengersCount: args['passengersCount'] as int,
          ),
        );
      case passengerDetails:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PassengerDetailsScreen(
            flight: args['flight'] as Flight,
            selectedSeats: (args['selectedSeats'] as List).cast<String>(),
            expiresAt: args['expiresAt'] != null ? args['expiresAt'] as DateTime : DateTime.now().add(const Duration(minutes: 15)),
          ),
        );
      case payment:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PaymentScreen(
            flight: args['flight'] as Flight,
            seats: args['seats'] as List<String>,
            passengers: args['passengers'] as List<PassengerFormData>,
            expiresAt: args['expiresAt'] as DateTime,
          ),
        );
      case staffDashboard:
        return MaterialPageRoute(builder: (_) => const StaffDashboardScreen());
      case manageFlights:
        return MaterialPageRoute(builder: (_) => const ManageFlightsScreen());
      case manageAirports:
        return MaterialPageRoute(builder: (_) => const ManageAirportsScreen());
      case manageUsers:
        return MaterialPageRoute(builder: (_) => const ManageUsersScreen());
      case manageBookings:
        return MaterialPageRoute(builder: (_) => const ManageBookingsScreen());
      case manageSeats:
        final flight = settings.arguments as Flight;
        return MaterialPageRoute(
          builder: (_) => ManageSeatsScreen(flight: flight),
        );
      case manageAircrafts:
        return MaterialPageRoute(builder: (_) => const ManageAircraftsScreen());
      case manageAnnouncements:
        return MaterialPageRoute(builder: (_) => const ManageAnnouncementsScreen());
      case managePayments:
        return MaterialPageRoute(builder: (_) => const ManagePaymentsScreen());
      case staffAircraftDetail:
        final aircraftId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => AircraftDetailScreen(aircraftId: aircraftId),
        );
      case staffAirportDetail:
        final airportId = settings.arguments as int;
        return MaterialPageRoute(
          builder: (_) => AirportDetailScreen(airportId: airportId),
        );
      case manageSeatTemplates:
        return MaterialPageRoute(builder: (_) => const ManageSeatTemplatesScreen());
      case staffCreateSeatTemplate:
        return MaterialPageRoute(builder: (_) => const CreateSeatTemplateScreen());
      case myBookings:
        return MaterialPageRoute(builder: (_) => const MyTripsScreen());
      case checkin:
        return MaterialPageRoute(
          builder: (_) => const CheckInScreen(),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());
      case paymentHistory:
        return MaterialPageRoute(builder: (_) => const PaymentHistoryScreen());
      case ticketDetail:
        final trips = settings.arguments as List<Trip>;
        return MaterialPageRoute(
          builder: (_) => TicketDetailScreen(trips: trips),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }

  static Map<String, WidgetBuilder> get routes {
    return {
      splash: (context) => const SplashScreen(),
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      home: (context) => const HomeScreen(),
    };
  }
}
