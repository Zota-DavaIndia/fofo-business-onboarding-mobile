import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';
import '../icons/app_icon.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'form.dart';
import 'widgets.dart';

/// A labelled point on a map.
class MapPin {
  const MapPin(this.lat, this.lng, {required this.label, this.note, this.tone = PinTone.accent});

  final double lat;
  final double lng;
  final String label;
  final String? note;
  final PinTone tone;

  LatLng get latLng => LatLng(lat, lng);
}

enum PinTone {
  accent(18),
  info(210),
  success(120);

  const PinTone(this.hue);

  /// Marker hue for Google Maps.
  final double hue;
}

/// Opens Google Maps (the app if installed) at a point, or with directions to it.
Future<void> openInMaps(double lat, double lng, {bool directions = false}) {
  final url = directions
      ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
      : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

String formatLatLng(double lat, double lng) => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

/// A small map with the pins, then one row per pin with a directions button.
/// Without a Maps key in the build, only the rows show and they open Google Maps.
class MapCard extends StatelessWidget {
  const MapCard({super.key, required this.pins, this.height = 168});

  final List<MapPin> pins;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Env.mapsEnabled)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.card)),
              child: SizedBox(
                height: height,
                child: _PinsMap(pins: pins, onTap: () => _openFull(context)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: Column(
              children: [
                for (var i = 0; i < pins.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, color: context.colors.separator),
                  _PinRow(pin: pins[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFull(BuildContext context) =>
      pushForm<void>(context, _FullMap(pins: pins, title: pins.length == 1 ? pins.first.label : 'Map'));
}

class _PinRow extends StatelessWidget {
  const _PinRow({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = switch (pin.tone) {
      PinTone.accent => c.accent,
      PinTone.info => c.info,
      PinTone.success => c.success,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openInMaps(pin.lat, pin.lng),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            IconTile(AppIcons.visit, color: tone, background: c.tintOf(tone), size: 36, iconSize: 18),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pin.label, style: context.text.bodyStrong),
                  Text(pin.note ?? formatLatLng(pin.lat, pin.lng), style: context.text.label),
                ],
              ),
            ),
            IconTile(
              AppIcons.navigate,
              semanticLabel: 'Directions to ${pin.label}',
              alignment: Alignment.centerRight,
              onTap: () => openInMaps(pin.lat, pin.lng, directions: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// A still map framing every pin; a tap opens the full map.
class _PinsMap extends StatelessWidget {
  const _PinsMap({required this.pins, this.onTap, this.interactive = false});

  final List<MapPin> pins;
  final VoidCallback? onTap;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final markers = {
      for (var i = 0; i < pins.length; i++)
        Marker(
          markerId: MarkerId('pin$i'),
          position: pins[i].latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(pins[i].tone.hue),
          infoWindow: InfoWindow(title: pins[i].label, snippet: pins[i].note),
        ),
    };
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pins.first.latLng, zoom: 16),
      markers: markers,
      liteModeEnabled: !interactive,
      zoomControlsEnabled: interactive,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      onTap: onTap == null ? null : (_) => onTap!(),
      onMapCreated: (map) {
        if (pins.length < 2) return;
        final b = _bounds(pins.map((p) => p.latLng));
        // Pins on top of each other would zoom to building level; keep street level then.
        final spread =
            (b.northeast.latitude - b.southwest.latitude).abs() + (b.northeast.longitude - b.southwest.longitude).abs();
        if (spread < 0.001) return;
        // Frame every pin once the map has a size.
        Future<void>.delayed(const Duration(milliseconds: 300), () {
          map.moveCamera(CameraUpdate.newLatLngBounds(b, 48)).ignore();
        });
      },
    );
  }
}

LatLngBounds _bounds(Iterable<LatLng> points) {
  var s = 90.0, w = 180.0, n = -90.0, e = -180.0;
  for (final p in points) {
    if (p.latitude < s) s = p.latitude;
    if (p.latitude > n) n = p.latitude;
    if (p.longitude < w) w = p.longitude;
    if (p.longitude > e) e = p.longitude;
  }
  return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
}

class _FullMap extends StatelessWidget {
  const _FullMap({required this.pins, required this.title});

  final List<MapPin> pins;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _PinsMap(pins: pins, interactive: true)),
          Positioned(
            left: Space.screen,
            top: MediaQuery.paddingOf(context).top + Space.sm,
            child: IconTile(
              AppIcons.close,
              semanticLabel: 'Close map',
              background: context.colors.card,
              color: context.colors.textPrimary,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
