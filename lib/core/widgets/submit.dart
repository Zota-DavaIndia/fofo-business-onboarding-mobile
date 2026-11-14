import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/session.dart';
import '../network/api_client.dart';
import 'form.dart';

/// Submit flow for form screens: run the save, confirm and pop with `true`,
/// or keep the server's field errors for the fields to show.
mixin FormSubmit<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool submitting = false;
  ApiException? error;

  /// Fields this form has asked for errors under, i.e. the ones it can show.
  final _shownFields = <String>{};

  String? fieldError(String name) {
    _shownFields.add(name);
    return error?.fieldError(name);
  }

  /// The client saves go through. Customer forms use the customer's token.
  ApiClient get submitApi => ref.read(apiClientProvider);

  /// Pops with `true`, or with [result] of what [save] returned.
  Future<void> submit(
    Future<Object?> Function(ApiClient api) save, {
    required String done,
    Object? Function(Object? saved)? result,
  }) async {
    FocusScope.of(context).unfocus();
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final saved = await save(submitApi);
      if (!mounted) return;
      showSaved(context, done);
      Navigator.of(context).pop(result == null ? true : result(saved));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e);
      // A rule the server checks on a field this form has no place for (say "status") would
      // otherwise fail silently, so say it in a toast once the form has rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (e.fieldErrors.isEmpty || e.fieldErrors.keys.any((k) => !_shownFields.contains(k))) {
          showSaveError(context, e);
        }
      });
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
