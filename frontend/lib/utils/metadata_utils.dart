import 'dart:convert';
import 'package:access/models/metadata.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'opening_hours_utils.dart';

/// Build a widget showing metadata info (phone, website, opening hours) from a list of strings
Widget buildMetadataFromList(List<String>? metadataList) {
  // If no data, return fallback text
  if (metadataList == null || metadataList.isEmpty) {
    return const Text('Δεν υπάρχουν διαθέσιμες πληροφορίες.');
  }

  // Parse the raw metadata strings into a structured map
  final Map<String, dynamic> metadataMap = _parseMetadata(metadataList);
  final List<Widget> children = [];

  // Extract relevant fields from the parsed metadata
  final String? phone = metadataMap['phone'] as String?;
  final String? website = metadataMap['website'] as String?;
  final dynamic openHours = metadataMap['open_hours'];
  print(openHours);

  // If phone exists, add a row with phone icon and number
  if (phone != null) {
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.phone),
            const SizedBox(width: 8.0),
            Text('Τηλέφωνο: $phone'),
          ],
        ),
      ),
    );
  }

  // If website exists, add clickable link with icon
  if (website != null) {
    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.web),
            const SizedBox(width: 8.0),
            InkWell(
              onTap: () async {
                print("WEB: " + website);
                final String? trimmedWebsite = website.trim();
                final Uri uri = Uri.parse(trimmedWebsite!);
                // Check if the URL can be launched, then launch it
                if (trimmedWebsite != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  print('Cannot launch URL: $website');
                  // fallback can be added here if needed
                }
              },
              child: const Text(
                'Ιστοσελίδα',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(width: 8.0),
            const Icon(Icons.open_in_new, size: 12),
          ],
        ),
      ),
    );
  }

  // If open hours exist, delegate building those widgets to a helper function
  if (openHours != null) {
    children.addAll(buildOpeningHoursWidgets(openHours));
  }

  /// Return all metadata widgets stacked vertically aligned left
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children,
  );
}

/// Parses raw metadata strings into a map with keys and values, handling 'open_hours' specially
Map<String, dynamic> _parseMetadata(List<String> metadataList) {
  final Map<String, dynamic> metadataMap = {};

  for (final item in metadataList) {
    // Split each string by first colon to separate key and value
    final idx = item.indexOf(':');
    if (idx == -1) continue; // skip malformed lines

    final key = item.substring(0, idx).trim();
    final value = item.substring(idx + 1).trim();

    // Special handling for 'open_hours' key to parse JSON-like string properly
    if (key == 'open_hours') {
      String openHoursString = value;

      if (value.contains('weekday_text')) {
        // Parse simplified weekday_text format into list
        String cleanedValue = value.replaceAll(RegExp(r'(\w+):\s*'), '');
        cleanedValue = cleanedValue.replaceAll(RegExp(r'[\[\]\{\}]'), '');
        List<String> weekdayTextList = cleanedValue.split(', ');
        metadataMap[key] = {'weekday_text': [weekdayTextList]};
      } else {
        // Try to fix the formatting for JSON parsing
        openHoursString = openHoursString.replaceAllMapped(
            RegExp(r'(\w+):'), (match) => '"${match.group(1)}":');
        openHoursString = openHoursString.replaceAllMapped(
            RegExp(r'([{,]\s*)(\w+):'), (match) => '${match.group(1)}"${match.group(2)}":');
        openHoursString = openHoursString.replaceAllMapped(
            RegExp(r'("time"\s*:\s*)(\d{4})'), (match) => '${match.group(1)}"${match.group(2)}"');

        print(openHoursString);

        try {
          metadataMap[key] = jsonDecode(openHoursString);
        } catch (_) {
          metadataMap[key] = null;
          print('Σφάλμα κατά την ανάλυση JSON: $value');
        }
      }
    } else {
      // For other keys just assign as is
      metadataMap[key] = value;
    }
  }

  return metadataMap;
}

/// Utility function to create ParsedMetadata model object from raw metadata list
ParsedMetadata createMetaData(List<String> metadataList) {
  final Map<String, dynamic> metadataMap = _parseMetadata(metadataList);
  ParsedMetadata? metaData = ParsedMetadata();
  metaData.phone = metadataMap['phone'] as String?;
  metaData.website = metadataMap['website'] as String?;
  return metaData;
}
