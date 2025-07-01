import 'package:access/models/metadata.dart';
import 'package:access/widgets/publish_comment_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/location_review_cubit/location_review_cubit.dart';
import '../blocs/map_bloc/map_bloc.dart';
import '../models/comment.dart';
import '../models/mapbox_feature.dart';
import '../utils/metadata_utils.dart';
import 'favourites_button.dart';

/// A card widget displaying detailed information about a specific location,
/// including its name, address, categories, accessibility, coordinates,
/// navigation and sharing actions, as well as user comments.
///
/// If `feature2` is provided, additional metadata (e.g., phone, website) is shown.
class LocationInfoCard extends StatefulWidget {
  /// Primary location feature.
  final MapboxFeature? feature;

  /// Secondary location feature used for additional metadata display.
  final MapboxFeature? feature2;

  const LocationInfoCard({super.key, required this.feature, this.feature2});

  @override
  State<LocationInfoCard> createState() => _LocationInfoCardState();
}

class _LocationInfoCardState extends State<LocationInfoCard> {
  @override
  void initState() {
    super.initState();
    /// Load comments related to the primary location feature on init
    if (widget.feature != null) {
      context.read<LocationCommentsCubit>().fetchComments(widget.feature!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feature == null) return const SizedBox.shrink();

    ParsedMetadata? metadata;
    if (widget.feature2 != null) {
      metadata = createMetaData(widget.feature2!.metadata);
    }

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.feature?.name ?? 'Άγνωστη Τοποθεσία',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              FavoriteStarButton(feature: widget.feature!),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.feature?.fullAddress ?? 'Δεν βρέθηκε διεύθυνση',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),

          /// Show categories if not empty or only 'address'
          if (widget.feature?.poiCategory != null &&
              widget.feature!.poiCategory.isNotEmpty &&
              !(widget.feature!.poiCategory.length == 1 &&
                  widget.feature!.poiCategory.first == 'address'))
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Κατηγορίες: ${widget.feature!.poiCategory.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.hintColor,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Προσβασιμότητα: ', style: theme.textTheme.bodyMedium),
              Icon(
                widget.feature?.accessibleFriendly ?? false
                    ? Icons.accessible_forward
                    : Icons.not_accessible,
                color: widget.feature?.accessibleFriendly ?? false
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                widget.feature?.accessibleFriendly ?? false
                    ? 'Προσβάσιμο'
                    : 'Μη Προσβάσιμο',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: widget.feature?.accessibleFriendly ?? false
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Lat: ${widget.feature?.latitude.toStringAsFixed(5) ?? 'N/A'}   Lon: ${widget.feature?.longitude.toStringAsFixed(5) ?? 'N/A'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),

          /// Buttons for navigation, directions, call, share and add comment actions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<MapBloc>().add(StartNavigationRequested(widget.feature!, false));
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Έναρξη'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => context.read<MapBloc>().add(DisplayAlternativeRoutes(widget.feature!)),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Οδηγίες'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 10),

                /// Show call button only if phone metadata is present
                if (widget.feature2 != null && metadata?.phone != null)
                  ElevatedButton.icon(
                    onPressed: () => context.read<MapBloc>().add(LaunchPhoneDialerRequested(metadata?.phone)),
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Κλήση'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: theme.textTheme.labelMedium,
                    ),
                  ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => context.read<MapBloc>().add(ShareLocationRequested(widget.feature!.id)),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Μοίρασε'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => PublishCommentModal(locationId: widget.feature!.id),
                    );
                    if (result == true) {
                      context.read<LocationCommentsCubit>().fetchComments(widget.feature!.id);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Δημοσίευση'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          /// Displays additional metadata if available
          if (widget.feature2 != null)
            buildMetadataFromList(widget.feature2?.metadata),

          const SizedBox(height: 12),

          /// Comments section - shows loading, error, or list of comments
          BlocBuilder<LocationCommentsCubit, LocationCommentsState>(
            builder: (context, state) {
              if (state is LocationCommentsLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is LocationCommentsLoaded) {
                final comments = state.comments;
                if (comments.isEmpty) {
                  return Text('Δεν υπάρχουν σχόλια');
                }
                return Column(
                  children: comments.map((c) => _buildCommentItem(c, context)).toList(),
                );
              }
              if (state is LocationCommentsError) {
                return Text('Σφάλμα: ${state.error}');
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// Builds a widget displaying a single comment including optional photo and timestamp.
  Widget _buildCommentItem(Comment comment, BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(comment.text ?? ''),
                  if (comment.photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Image.network(
                        comment.photoUrl!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTimestamp(comment.timestamp),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats the timestamp of a comment into a relative time string.
  /// Examples: "Τώρα", "5 λεπτά πριν", "2 ώρες πριν", or date string.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Τώρα';
    if (diff.inMinutes < 60) return '${diff.inMinutes} λεπτά πριν';
    if (diff.inHours < 24) return '${diff.inHours} ώρες πριν';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
