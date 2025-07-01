import 'package:flutter/material.dart';

/// Builds a list of Widgets representing opening hours from a given data map
List<Widget> buildOpeningHoursWidgets(Map<String, dynamic> openHours) {
  final List<Widget> children = [];

  print("Debug openHours data: " + openHours.toString());

  // Check if 'weekday_text' key exists in openHours
  if (openHours.containsKey('weekday_text')) {
    final List<dynamic> weekdayTextOuterList = openHours['weekday_text'];

    // The 'weekday_text' is expected to be a list containing another list
    if (weekdayTextOuterList.isNotEmpty && weekdayTextOuterList[0] is List) {
      final List<dynamic> weekdayText = weekdayTextOuterList[0];

      // Greek day names ordered Monday to Sunday
      const List<String> greekDays = [
        'Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη',
        'Παρασκευή', 'Σάββατο', 'Κυριακή',
      ];

      // Add a bold header label
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Ώρες Λειτουργίας:', style: TextStyle(fontWeight: FontWeight.bold)),
      ));

      // If the days count does not match the expected list length, proceed to add entries
      if (greekDays.length != weekdayText.length) {
        // Start from index 2 to skip unknown/irrelevant entries? (May want to check this logic)
        for (int i = 2; i < weekdayText.length; i++) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text('${greekDays[i - 2]}: ${weekdayText[i]}'),
          ));
        }
      } else {
        // Error case: unexpected number of day descriptions
        children.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 2.0),
          child: Text('Σφάλμα: Μη αναμενόμενος αριθμός ωρών λειτουργίας'),
        ));
        print('Error: Unexpected number of weekday descriptions: ${weekdayText.length}');
      }

      return children;
    } else {
      // Error case: 'weekday_text' structure is not as expected
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Σφάλμα: Μη αναμενόμενη δομή weekday_text'),
      ));
      print('Error: Unexpected weekday_text structure: $weekdayTextOuterList');
      return children;
    }
  }

  /// Alternative structure: check for 'periods' key with open/close times
  final List<dynamic>? periods = openHours['periods'];
  if (periods != null && periods.isNotEmpty) {
    // Add header label
    children.add(const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Text('Ώρες Λειτουργίας:', style: TextStyle(fontWeight: FontWeight.bold)),
    ));

    // Iterate over each period of opening hours
    for (final period in periods) {
      final open = period['open'] as Map<String, dynamic>?;
      final close = period['close'] as Map<String, dynamic>?;

      final int? openDay = open?['day'];
      final String? openTime = open?['time'];
      final int? closeDay = close?['day'];
      final String? closeTime = close?['time'];

      final String? formattedOpenTime = _formatTime(openTime);
      final String? formattedCloseTime = _formatTime(closeTime);
      final String? openDayStr = _dayToGreek(openDay);
      final String? closeDayStr = _dayToGreek(closeDay);

      String periodText;
      if (openDayStr == closeDayStr) {
        // If same day, format like "Monday: 9:00 πμ - 5:00 μμ"
        periodText = '$openDayStr: $formattedOpenTime - $formattedCloseTime';
      } else {
        // If spans days, format like "Monday 9:00 πμ - Tuesday 5:00 μμ"
        periodText = '$openDayStr $formattedOpenTime - $closeDayStr $formattedCloseTime';
      }

      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Text(periodText),
      ));
    }
  }

  return children;
}

/// Helper: formats time string "HHmm" into readable "h:mm πμ/μμ" Greek format
String? _formatTime(String? time) {
  if (time == null || time.length != 4) return null;
  final int hour = int.parse(time.substring(0, 2));
  final String minute = time.substring(2);
  final String periodAmPm = hour < 12 ? 'πμ' : 'μμ';
  final int formattedHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$formattedHour:$minute $periodAmPm';
}

/// Helper: converts day number (0-6) to Greek weekday string (Sunday=0)
String? _dayToGreek(int? day) {
  if (day == null) return null;
  const days = [
    'Κυριακή', 'Δευτέρα', 'Τρίτη', 'Τετάρτη',
    'Πέμπτη', 'Παρασκευή', 'Σάββατο',
  ];
  return (day >= 0 && day < days.length) ? days[day] : null;
}
