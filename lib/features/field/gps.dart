import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/toast.dart';

/// A real GPS fix for a check-in, asking for location access first.
/// Null after telling the user what's wrong.
Future<Position?> readFix(BuildContext context) async {
  String problem;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      problem = 'Turn on location to check in.';
    } else {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        problem = 'Allow location for this app in Settings to check in.';
      } else {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 20)),
        );
      }
    }
  } catch (_) {
    problem = "Couldn't get your location. Move to open sky and try again.";
  }
  if (context.mounted) showToast(context, problem, kind: ToastKind.error);
  return null;
}
