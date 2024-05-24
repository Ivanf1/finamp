import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:octo_image/octo_image.dart';

import '../services/theme_provider.dart';

/// Same as [_PlayerScreenAlbumImage], but with a BlurHash instead. We also
/// filter the BlurHash so that it works as a background image.
class BlurredPlayerScreenBackground extends ConsumerWidget {
  /// should never be less than 1.0
  final double opacityFactor;

  const BlurredPlayerScreenBackground({
    super.key,
    this.opacityFactor = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var (imageProvider, localBlurhash) = ref.watch(imageThemeProvider);

    var overlayColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
            .withOpacity(ui.clampDouble(0.675 * opacityFactor, 0.0, 1.0))
        : Colors.white
            .withOpacity(ui.clampDouble(0.75 * opacityFactor, 0.0, 1.0));

    Widget placeholderBuilder(_) => localBlurhash != null
        ? SizedBox.expand(
            child: Image(
                fit: BoxFit.cover,
                color: overlayColor,
                colorBlendMode: BlendMode.srcOver,
                image: BlurHashImage(
                  localBlurhash,
                )),
          )
        : const SizedBox.shrink();

    return Positioned.fill(
        child: AnimatedSwitcher(
            duration: getThemeTransitionDuration(context),
            switchOutCurve: const Threshold(0.0),
            child: imageProvider == null
                ? placeholderBuilder(null)
                : OctoImage(
                    // Don't transition between images with identical files/urls unless
                    // system theme has changed
                    key: ValueKey(imageProvider.hashCode +
                        Theme.of(context).brightness.index),
                    image: imageProvider,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(seconds: 0),
                    fadeOutDuration: const Duration(seconds: 0),
                    color: overlayColor,
                    colorBlendMode: BlendMode.srcOver,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (x, _, __) => placeholderBuilder(x),
                    placeholderBuilder: placeholderBuilder,
                    imageBuilder: (context, child) {
                      var image = ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 85,
                          sigmaY: 85,
                          tileMode: TileMode.mirror,
                        ),
                        child: SizedBox.expand(child: child),
                      );
                      // There seems to be some sort of issue with how Linux handles ui.Image that breaks
                      // cachePaint.  This shouldn't be too important outside mobile, though.
                      if (Platform.isLinux) {
                        return image;
                      }
                      return CachePaint(
                          imageKey: imageProvider.toString(), child: image);
                    })));
  }
}

class CachePaint extends SingleChildRenderObjectWidget {
  const CachePaint({super.key, super.child, required this.imageKey});

  final String imageKey;

  @override
  RenderCachePaint createRenderObject(BuildContext context) {
    return RenderCachePaint(imageKey, Theme.of(context).brightness);
  }
}

class RenderCachePaint extends RenderProxyBox {
  RenderCachePaint(this._imageKey, this._brightness);

  final String _imageKey;

  String get _cacheKey => _imageKey + size.toString() + _brightness.toString();

  final Brightness _brightness;

  static final Map<String, (List<RenderCachePaint>, ui.Image?)> _cache = {};

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, ui.Offset offset) {
    if (_cache[_cacheKey] != null) {
      if (!_cache[_cacheKey]!.$1.contains(this)) {
        // Add use to list of widgets using image
        _cache[_cacheKey]!.$1.add(this);
      }
      if (_cache[_cacheKey]!.$2 != null) {
        // Use cached child
        context.canvas.drawImage(_cache[_cacheKey]!.$2!, offset, Paint());
      } else {
        // Image is currently building, so paint child and move on.
        super.paint(context, offset);
      }
    } else {
      // Create cache entry
      _cache[_cacheKey] = ([this], null);
      // Paint our child
      super.paint(context, offset);
      // Save image of child to cache
      final OffsetLayer offsetLayer = layer! as OffsetLayer;
      Future.sync(() async {
        _cache[_cacheKey] =
            (_cache[_cacheKey]!.$1, await offsetLayer.toImage(offset & size));
        // Schedule repaint next frame because the image is lighter than the full
        // child during compositing, which is more frequent than paints.
        for (var element in _cache[_cacheKey]!.$1) {
          element.markNeedsPaint();
        }
      });
    }
  }

  @override

  /// Dispose of outdated render cache whenever widget size changes
  set size(Size newSize) {
    String? oldKey;
    if (hasSize) {
      oldKey = _cacheKey;
    }
    super.size = newSize;
    if (_cacheKey != oldKey && oldKey != null) {
      _disposeCache(oldKey);
    }
  }

  void _disposeCache(String key) {
    _cache[key]?.$1.remove(this);
    if (_cache[key]?.$1.isEmpty ?? false) {
      // If we are last user of image, dispose
      _cache[key]?.$2?.dispose();
      _cache.remove(key);
    }
  }

  @override
  void dispose() {
    _disposeCache(_cacheKey);
    super.dispose();
  }
}
