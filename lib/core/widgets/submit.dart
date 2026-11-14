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

  String? fieldError(String name) => error?.fieldError(name);

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
      final saved = await save(ref.read(apiClientProvider));
      if (!mounted) return;
      showSaved(context, done);
      Navigator.of(context).pop(result == null ? true : result(saved));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => error = e);
      if (e.fieldErrors.isEmpty) showSaveError(context, e);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}
