import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:access/web_screens/web_bloc/web_map_bloc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Web-only widget that embeds a Mapbox GL map in an iframe using `HtmlElementView`.
/// Handles cluster marker rendering and interaction via postMessage,
/// including long-press detection, cluster and report marker clicks,
/// and live message communication between Flutter and the map.
class MapBoxIframeView extends StatefulWidget {
  const MapBoxIframeView({super.key});

  @override
  State<MapBoxIframeView> createState() => _MapBoxIframeViewState();
}

class _MapBoxIframeViewState extends State<MapBoxIframeView> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      context.read<MapBloc>().add(LoadMap());
    }
  }

  /// Registers a dynamic HTML iframe with embedded Mapbox map
  /// and configures event handlers for long press, cluster click, etc.
  void _registerMap() {
    const accessToken = String.fromEnvironment('token_web');

    final String htmlContent = '''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>Map</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <script src="https://api.mapbox.com/mapbox-gl-js/v3.11.0/mapbox-gl.js"></script>
        <link href="https://api.mapbox.com/mapbox-gl-js/v3.11.0/mapbox-gl.css" rel="stylesheet" />
        <style>
          html, body { margin: 0; padding: 0; height: 100%; }
          #map { width: 100%; height: 100%; }
        </style>
      </head>
      <body>
        <div id="map"></div>
        <script>
          let pressTimer;
          const LONG_PRESS_DELAY = 1500;
          let clusterMarkers = [];
    
          function addClusterMarkers(clusters) {
            clusterMarkers.forEach(marker => marker.remove());
            clusterMarkers = [];
            
            clusters.forEach((cluster, clusterIndex) => {
              const reports = cluster;
              if (reports.length > 0) {
                const firstReport = reports[0];
                const marker = new mapboxgl.Marker({
                  color: '#FF0000',
                  scale: 0.8
                })
                  .setLngLat([firstReport.longitude, firstReport.latitude])
                  .addTo(map);
          
                marker.getElement().dataset.clusterIndex = clusterIndex;
                marker.getElement().dataset.reports = JSON.stringify(reports);
          
                marker.getElement().addEventListener('click', () => {
                  const reports = JSON.parse(marker.getElement().dataset.reports);
                  window.parent.postMessage({
                    type: 'clusterMarkerClick',
                    clusterIndex: clusterIndex,
                    reports: reports
                  }, '*');
                });
          
                clusterMarkers.push(marker);
              }
            });
          }
          
          window.addEventListener('message', (e) => {
            if (e.data.type === 'executeCode') {
              try {
                new Function(e.data.code)();
              } catch (error) {
                console.error('Error executing code:', error);
              }
            } else if (e.data.type === 'addClusterMarkers') {
              addClusterMarkers(e.data.clusters);
            }
          });
    
          mapboxgl.accessToken = "$accessToken";
          const map = new mapboxgl.Map({
            container: 'map',
            style: 'mapbox://styles/el03/cmaoalqvx01jl01qy9swq5ip4',
            center: [23.7275, 37.9838],
            zoom: 12
          });
    
          // Long-press detection για mouse
          map.on('mousedown', (e) => {
            pressTimer = setTimeout(() => {
              window.parent.postMessage({
                type: 'mapLongPress',
                coordinates: [e.lngLat.lng, e.lngLat.lat]
              }, '*');
            }, LONG_PRESS_DELAY);
          });
    
          map.on('mouseup', () => clearTimeout(pressTimer));
          map.on('mouseout', () => clearTimeout(pressTimer));
    
          map.on('load', () => {
            map.resize();
            map.setMinZoom(10);
            window.parent.postMessage({ type: 'mapLoaded' }, '*');
          });
        </script>
      </body>
    </html>
    ''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    ui.platformViewRegistry.registerViewFactory('mapbox-view', (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..id = 'map-iframe'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'auto';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(child: Text('Χάρτης διαθέσιμος μόνο στο Web.'));
    }

    return BlocBuilder<MapBloc, MapState>(
      builder: (context, state) {
        if (state is MapLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is MapLoaded) {
          _registerMap();
          return const HtmlElementView(viewType: 'mapbox-view');
        } else if (state is MapError) {
          return Center(child: Text('Σφάλμα φόρτωσης χάρτη: ${state.message}'));
        }
        return const SizedBox.shrink();
      },
    );
  }
}