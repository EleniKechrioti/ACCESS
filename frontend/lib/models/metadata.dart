// Holds parsed metadata info like phone, website, and opening hours
class ParsedMetadata {
  late String? phone;                   // Contact phone number (optional)
  late String? website;                 // Website URL (optional)
  late List<Map<String, dynamic>>? openHours;  // Opening hours as list of maps (optional)

  ParsedMetadata({
    this.phone,
    this.website,
    this.openHours,
  });
}

// Represents an opening period with day and time info
class OpenPeriod {
  final int openDay;    // Day of week opening starts (0 = Sunday, etc.)
  final String openTime;  // Opening time (e.g. "09:00")
  final int closeDay;   // Day of week closing happens
  final String closeTime; // Closing time (e.g. "17:00")

  OpenPeriod({
    required this.openDay,
    required this.openTime,
    required this.closeDay,
    required this.closeTime,
  });
}
