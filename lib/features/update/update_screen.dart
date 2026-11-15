import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/icons/app_icon.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/update/update.dart';
import '../../core/widgets/form.dart';
import '../../core/widgets/page.dart';
import '../../core/widgets/widgets.dart';

/// Download, check and install a release.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key, this.release, this.apk});

  final Release? release;

  /// The APK when it was already downloaded in the background.
  final String? apk;

  /// How many update screens are open, so the watcher doesn't stack a second one.
  static int open = 0;

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen> with WidgetsBindingObserver {
  String? _error;
  late String? _apk = widget.apk ?? _downloaded(widget.release);

  static String? _downloaded(Release? r) {
    final done = Updater.ready.value;
    return r != null && done != null && done.release.version == r.version && done.release.build == r.build
        ? done.path
        : null;
  }

  bool _needsPermission = false;
  bool _starting = false;

  Release? get _release => widget.release ?? ref.watch(availableUpdateProvider).value;

  @override
  void initState() {
    super.initState();
    UpdateScreen.open++;
    WidgetsBinding.instance.addObserver(this);
    // A background download is already running: show its progress and pick up the file when it's done.
    if (_apk == null && Updater.progress.value != null) _start(install: false);
  }

  @override
  void dispose() {
    UpdateScreen.open--;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the "install unknown apps" setting: carry on if it was allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsPermission && _apk != null) _install();
  }

  Future<void> _start({bool install = true}) async {
    final r = _release;
    if (r == null) return;
    setState(() {
      _error = null;
      _starting = true;
    });
    try {
      final apk = await Updater.fetch(r);
      if (!mounted) return;
      setState(() => _apk = apk);
      if (install) await _install();
    } on UpdateException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (Updater.cancelled(e)) return; // stopped from the Profile row: back to Download, no error
      if (mounted) setState(() => _error = "Couldn't download the update. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;
    if (!await Updater.canInstall()) {
      if (mounted) setState(() => _needsPermission = true);
      return;
    }
    if (mounted) setState(() => _needsPermission = false);
    try {
      await Updater.install(apk);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't open the installer. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _release;
    return ValueListenableBuilder<double?>(
      valueListenable: Updater.progress,
      builder: (context, progress, _) => _body(context, r, progress),
    );
  }

  Widget _body(BuildContext context, Release? r, double? progress) {
    final c = context.colors;
    final ready = _apk != null;
    final downloading = !ready && (_starting || progress != null);
    return PageBody(
      header: PageHeader('Update the app', onBack: () => Navigator.of(context).maybePop()),
      bottom: r == null
          ? null
          : ActionBar(
              children: [
                if (_needsPermission)
                  AppButton(label: 'Allow installs', icon: AppIcons.shield, onPressed: Updater.openInstallSettings)
                else
                  AppButton(
                    label: ready ? 'Install' : (downloading ? 'Downloading…' : 'Download and install'),
                    icon: ready ? AppIcons.check : AppIcons.download,
                    loading: downloading,
                    onPressed: downloading ? null : (ready ? _install : _start),
                  ),
              ],
            ),
      children: [
        Text('A new version of Davaindia Field Force is ready.', style: context.text.secondary),
        if (r != null)
          GroupedList(
            children: [
              ListRow(title: r.version, subtitle: 'New version'),
              ListRow(title: Env.appVersion, subtitle: 'This phone'),
              if (r.sizeLabel != null) ListRow(title: r.sizeLabel!, subtitle: 'Download'),
            ],
          )
        else
          MessageBlock(
            icon: AppIcons.download,
            title: 'Get the latest version',
            body: 'Open the download page and install the latest APK.',
            action: AppButton(
              label: 'Open download page',
              kind: ButtonKind.secondary,
              onPressed: () => launchUrl(
                Uri.parse('https://github.com/Zota-DavaIndia/fofo-business-onboarding-mobile/releases/latest'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        if (downloading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.badge),
            child: LinearProgressIndicator(
              value: progress == null || progress == 0 ? null : progress,
              minHeight: 8,
              color: c.accent,
              backgroundColor: c.accentTint,
            ),
          ),
          Text(
            progress == null || progress == 0 ? 'Starting…' : '${(progress * 100).round()}%',
            style: context.text.label,
          ),
        ],
        if (_needsPermission)
          AppCard(
            child: Text(
              'Android asks once before an app can install updates. Tap Allow installs, turn on "Allow from this source", then come back.',
              style: context.text.secondary,
            ),
          ),
        if (ready && !_needsPermission)
          Text('Downloaded and checked. Android will ask you to confirm the install.', style: context.text.label),
        if (_error != null) Text(_error!, style: context.text.label.copyWith(color: c.danger)),
      ],
    );
  }
}

/// The app version on Profile, with the update's state on the right: Update when a new version is out,
/// the percentage and a ring with a stop button while it downloads, Install once it's downloaded and checked.
class AppVersionRow extends ConsumerWidget {
  const AppVersionRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(availableUpdateProvider).value;
    if (r == null) return const ListRow(title: Env.appVersion, subtitle: 'App version');
    return ListenableBuilder(
      listenable: Listenable.merge([Updater.progress, Updater.ready]),
      builder: (context, _) {
        final progress = Updater.progress.value;
        final done = Updater.ready.value;
        final apk = done != null && done.release.version == r.version && done.release.build == r.build
            ? done.path
            : null;
        void open() => pushForm<void>(context, UpdateScreen(release: r, apk: apk));
        return ListRow(
          title: Env.appVersion,
          subtitle: apk != null
              ? 'App version · ${r.version} downloaded'
              : progress != null
              ? 'App version · downloading ${r.version}'
              : 'App version · ${r.version} is available',
          onTap: open,
          trailing: apk != null
              ? TextLink(label: 'Install', onTap: open)
              : progress != null
              ? DownloadProgress(progress)
              : TextLink(label: 'Update', onTap: open),
        );
      },
    );
  }
}

/// The percentage, then a ring that fills as the download runs with a stop square inside: tapping the
/// ring stops the download.
class DownloadProgress extends StatelessWidget {
  const DownloadProgress(this.progress, {super.key, this.onStop = Updater.cancel});

  final double progress;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (progress * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Text(
            '$pct%',
            style: context.text.label.copyWith(color: c.accent, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: Space.xs),
        Semantics(
          button: true,
          label: 'Stop download, $pct percent done',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onStop,
            behavior: HitTestBehavior.opaque,
            // A 40 pt target around the 28 pt ring.
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox.square(
                dimension: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress == 0 ? null : progress,
                        strokeWidth: 2.5,
                        strokeCap: StrokeCap.round,
                        color: c.accent,
                        backgroundColor: c.accentTint,
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Version X is ready" on Home, until the user updates or dismisses it for that version.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(availableUpdateProvider).value;
    final dismissed = ref.watch(_dismissedProvider);
    if (r == null || dismissed == r.version) return const SizedBox.shrink();
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushForm<void>(context, UpdateScreen(release: r, apk: _UpdateScreenState._downloaded(r))),
      child: AppCard(
        child: Row(
          children: [
            IconTile(AppIcons.download, color: c.accent, background: c.accentTint, size: 36, iconSize: 18),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version ${r.version} is ready', style: context.text.bodyStrong),
                  ListenableBuilder(
                    listenable: Listenable.merge([Updater.progress, Updater.ready]),
                    builder: (context, _) {
                      final p = Updater.progress.value;
                      final text = Updater.ready.value?.release.version == r.version
                          ? 'Downloaded · tap to install'
                          : p != null
                          ? 'Downloading · ${(p * 100).round()}%'
                          : 'Tap to update${r.sizeLabel == null ? '' : ' · ${r.sizeLabel}'}';
                      return Text(text, style: context.text.label);
                    },
                  ),
                ],
              ),
            ),
            IconTile(
              AppIcons.close,
              semanticLabel: 'Not now',
              size: 36,
              iconSize: 16,
              onTap: () => ref.read(_dismissedProvider.notifier).set(r.version),
            ),
          ],
        ),
      ),
    );
  }
}

final _dismissedProvider = NotifierProvider<_Dismissed, String?>(_Dismissed.new);

class _Dismissed extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? v) => state = v;
}

/// Checks GitHub Releases quietly each time the app opens or comes back (at most every [resumeGap]) and every
/// [every] while it stays open. A new release is downloaded and checked in the background, then [UpdateScreen]
/// opens ready to install, once per release per launch. Offline or a failed download shows nothing; the next
/// open tries again and reuses whatever was already downloaded.
class UpdateWatcher extends ConsumerStatefulWidget {
  const UpdateWatcher({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.every = checkEvery,
    this.fetch = Updater.fetch,
  });

  static const checkEvery = Duration(hours: 6);
  static const resumeGap = Duration(minutes: 15);

  final GlobalKey<NavigatorState> navigatorKey;
  final Duration every;
  final Widget child;

  /// Downloads a release and returns the APK path (swapped out in tests).
  final Future<String> Function(Release) fetch;

  @override
  ConsumerState<UpdateWatcher> createState() => _UpdateWatcherState();
}

class _UpdateWatcherState extends ConsumerState<UpdateWatcher> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastCheck;
  String? _offered;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (!selfUpdates) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.every, (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final last = _lastCheck;
    if (state == AppLifecycleState.resumed &&
        (last == null || DateTime.now().difference(last) >= UpdateWatcher.resumeGap)) {
      _check();
    }
  }

  Future<void> _check() async {
    _lastCheck = DateTime.now();
    ref.invalidate(availableUpdateProvider);
    final r = await ref.read(availableUpdateProvider.future);
    if (!mounted || r == null || _open) return;
    final key = '${r.version}+${r.build}';
    if (_offered == key) return;
    final String apk;
    try {
      apk = await widget.fetch(r);
    } catch (_) {
      return; // offline or a bad download: try again next time
    }
    final nav = widget.navigatorKey.currentState;
    if (!mounted || nav == null || _open || _offered == key || UpdateScreen.open > 0) return;
    _offered = key;
    _open = true;
    await nav.push<void>(
      MaterialPageRoute(
        builder: (_) => UpdateScreen(release: r, apk: apk),
      ),
    );
    _open = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
