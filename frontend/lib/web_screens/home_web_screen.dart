import 'dart:async';
import 'package:access/services/search_service.dart';
import 'package:access/web_screens/report_card.dart';
import 'package:access/web_screens/web_bloc/web_home_bloc/home_web_bloc.dart';
import 'package:access/web_screens/web_bloc/web_map_bloc/map_bloc.dart';
import 'package:access/web_screens/web_bloc/web_report_card_bloc/report_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../blocs/search_bloc/search_bloc.dart';
import 'package:access/theme/app_colors.dart';
import 'map.dart';

/// Web-only home screen displaying the interactive accessible city map,
/// with clustered reports loaded from backend and user interaction handling.
/// Manages communication with the embedded map iframe via HTML window messages,
/// plus sidebar navigation, report dialogs, and authentication token checks.
class HomeWebScreen extends StatefulWidget {
  const HomeWebScreen({super.key});

  @override
  _HomeWebScreenState createState() => _HomeWebScreenState();
}

class _HomeWebScreenState extends State<HomeWebScreen> {
  /// Subscription for browser pop state (history back) events.
  StreamSubscription<html.PopStateEvent>? _popStateSubscription;

  /// Subscription for browser window message events, to communicate with map iframe.
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  /// Holds the clusters of reports fetched from backend.
  List<dynamic> clusters = [];

  /// Flag to track whether the map iframe has finished loading.
  bool _isMapLoaded = false;

  @override
  void initState() {
    super.initState();

    /// Load clusters from backend on startup.
    _loadClusters();

    /// Check for auth token in browser localStorage, redirect if missing.
    final authToken = html.window.localStorage['authToken'];
    if (authToken == null) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
    } else {
      /// Listen for browser back button events and pop navigation stack accordingly.
      _popStateSubscription = html.window.onPopState.listen((event) {
        if (ModalRoute.of(context)?.settings.name == '/webhome') {
          return;
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }

    /// Listen for messages from the map iframe and handle different event types.
    _messageSubscription = html.window.onMessage.listen((event) {
      try {
        if (event.data['type'] == 'mapLongPress') {
          final coords = List<double>.from(event.data['coordinates']);
          _handleLongPress(coords);
        }
        else if (event.data['type'] == 'mapLoaded') {
          if (mounted) {
            setState(() {
              _isMapLoaded = true;
            });
          }
          if (clusters.isNotEmpty) {
            _sendClustersToMap();
          }
        }
        else if (event.data['type'] == 'clusterMarkerClick') {
          _showClusterReports(event.data['reports']);
        }
        else if (event.data['type'] == 'reportMarkerClick') {
          _showReportDetails(event.data['report']);
        }
      } catch (e) {
        print('Error handling map event: $e');
      }
    });
  }

  /// Fetches report clusters from the backend server.
  Future<void> _loadClusters() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:9090/setreport'));
      if (response.statusCode == 200) {
        final rawClusters = json.decode(response.body);

        final processedClusters = rawClusters.map((cluster) {
          return cluster.map((report) {
            return {
              'id': report['id'],
              'timestamp': _formatTimestamp(report['timestamp']),
              'latitude': report['latitude'],
              'longitude': report['longitude'],
              'obstacleType': report['obstacleType'],
              'locationDescription': report['locationDescription'],
              'imageUrl': report['imageUrl'],
              'accessibility': report['accessibility'],
              'description': report['description'],
              'userId': report['userId'],
              'userEmail': report['userEmail'],
            };
          }).toList();
        }).toList();

        if (mounted) {
          setState(() {
            clusters = processedClusters;
          });

          if (_isMapLoaded) {
            _sendClustersToMap();
          }
        }
      }
    } catch (e) {
      print('Σφάλμα φόρτωσης clusters: $e');
    }
  }

  /// Formats an ISO timestamp string to a readable date/time.
  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    } catch (e) {
      return timestamp;
    }
  }

  /// Sends the current clusters data to the embedded map iframe.
  void _sendClustersToMap() {
    final iframe = html.document.getElementById('map-iframe') as html.IFrameElement?;
    if (iframe?.contentWindow != null) {
      iframe!.contentWindow!.postMessage({
        'type': 'addClusterMarkers',
        'clusters': clusters,
      }, '*');
    }
  }

  /// Displays a dialog listing the reports inside a cluster.
  void _showClusterReports(List<dynamic> reports) {
    html.document.getElementById('map-iframe')?.style.pointerEvents = 'none';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Αναφορές (${reports.length})'),
        content: SizedBox(
          width: 500,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                title: Text(report['locationDescription']),
                subtitle: Text('${report['timestamp']}\nΣυντεταγμένες: ${report['latitude']}, ${report['longitude']}'),
                onTap: () => _showReportDetails(report),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Κλείσιμο',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
              ),
            ),
          )
        ],
      ),
    ).then((_) {
      if (mounted) {
        html.document.getElementById('map-iframe')?.style.pointerEvents = 'auto';
        context.read<HomeWebBloc>().add(CloseReportDialog());
        _loadClusters();
      }
    });
  }

  /// Displays a detailed dialog for a single report.
  void _showReportDetails(dynamic report) {
    html.document.getElementById('map-iframe')?.style.pointerEvents = 'none';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: AlertDialog(
            title: Text(report['obstacleType'] ?? 'Άγνωστος τύπος'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (report['imageUrl'] != null && report['imageUrl'].isNotEmpty)
                    AspectRatio(
                      aspectRatio: 16/9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          report['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    report['description'] ?? 'Δεν υπάρχει περιγραφή',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.location_on, report['locationDescription']),
                  _buildInfoRow(Icons.access_time, report['timestamp']),
                  _buildInfoRow(Icons.accessible, report['accessibility']),
                  if (report['userEmail'] != null)
                    _buildInfoRow(Icons.person, report['userEmail']),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Κλείσιμο',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) {
        html.document.getElementById('map-iframe')?.style.pointerEvents = 'auto';
      }
    });
  }

  /// Helper widget for displaying an icon next to a text info line.
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _popStateSubscription?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  /// Handles long press events from the map by opening the report submission dialog.
  void _handleLongPress(List<double> coordinates) {
    html.document.getElementById('map-iframe')?.style.pointerEvents = 'none';
    if (!context.read<HomeWebBloc>().state.isReportDialogOpen) {
      context.read<HomeWebBloc>().add(OpenReportDialog());
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: BlocProvider.of<SearchBloc>(context)),
                BlocProvider(create: (_) => ReportBloc()),
              ],
              child: SizedBox(
                height: 500,
                width: 500,
                child: ReportCard(coordinates: coordinates),
              ),
            ),
          );
        },
      ).then((_) {
        if (mounted) {
          html.document.getElementById('map-iframe')?.style.pointerEvents = 'auto';
          context.read<HomeWebBloc>().add(CloseReportDialog());
          _loadClusters();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('This screen is for Web only.')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => HomeWebBloc()),
        BlocProvider(create: (_) => SearchBloc(searchService: SearchService())),
      ],
      child: BlocListener<SearchBloc, SearchState>(
        listener: (context, state) {
          if (state is SearchLoaded) {
            print('Αποτελέσματα αναζήτησης: ${state.results}');
          } else if (state is SearchError) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Αποτυχία αναζήτησης')),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text("Accessible City"),
            automaticallyImplyLeading: false,
          ),
          body: BlocBuilder<HomeWebBloc, HomeWebState>(
            builder: (context, state) {
              return Row(
                children: [
                  // Sidebar
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: IntrinsicWidth(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.creamAccent[100],
                          border: Border.all(color: AppColors.cream, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.person),
                              title: const Text('Προφίλ'),
                              onTap: () {
                                Navigator.pushNamed(context, '/profile');
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.add_box_rounded),
                              title: const Text("Προσθήκη έργου"),
                              onTap: () {
                                if (!state.isReportDialogOpen) {
                                  context.read<HomeWebBloc>().add(
                                    OpenReportDialog(),
                                  );
                                  html.document.getElementById('map-iframe')?.style.pointerEvents = 'none';
                                  showDialog(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (context) {
                                      return Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: BlocProvider(
                                          create: (_) => ReportBloc(),
                                          child: const SizedBox(
                                            height: 500,
                                            width: 500,
                                            child: ReportCard(),
                                          ),
                                        ),
                                      );
                                    },
                                  ).then((_) {
                                    // Έλεγχος αν το widget είναι ακόμα mounted
                                    if (mounted) {
                                      html.document.getElementById('map-iframe')?.style.pointerEvents = 'auto';
                                      context.read<HomeWebBloc>().add(CloseReportDialog());
                                      _loadClusters();
                                    }
                                  });
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.exit_to_app),
                              title: const Text('Αποσύνδεση'),
                              onTap: () {
                                html.window.localStorage.remove('authToken');
                                html.window.history.replaceState(null, '', '/login');
                                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Map content
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 800,
                        height: 600,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.secondary),
                        ),
                        child: BlocProvider(
                          create: (_) => MapBloc()..add(const LoadMap()),
                          child: const MapBoxIframeView(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}