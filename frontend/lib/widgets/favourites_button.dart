import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/favourites_bloc/favourites_cubit.dart';
import '../models/mapbox_feature.dart';

/// A star icon button that indicates whether a given [MapboxFeature] is a favorite,
/// and allows toggling its favorite status.
///
/// The icon shows a filled star if the feature is favorited, otherwise an outlined star.
class FavoriteStarButton extends StatelessWidget {
  /// The map feature associated with this favorite button.
  final MapboxFeature feature;

  const FavoriteStarButton({
    super.key,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      builder: (context, state) {
        /// Check if the feature is currently favorited.
        final isFavorite = context.read<FavoritesCubit>().isFavorite(feature.id);

        return IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.yellow[700] : Colors.grey,
          ),
          /// Toggles the favorite status when pressed.
          onPressed: () {
            context.read<FavoritesCubit>().toggleFavorite(feature: feature);
          },
        );
      },
    );
  }
}
