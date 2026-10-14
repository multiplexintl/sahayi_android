/// Filters for the logs dashboard (shared by both tabs).
class LogFilter {
  final Set<String> levels;
  final Set<String> actions;
  final String? screen;
  final String? userId;
  final String? docType; // I, T or R
  final int? uploadState; // 0 waiting, 1 sent, 2 rejected (this device only)
  final DateTime? from;
  final DateTime? to; // inclusive day

  const LogFilter({
    this.levels = const {},
    this.actions = const {},
    this.screen,
    this.userId,
    this.docType,
    this.uploadState,
    this.from,
    this.to,
  });

  /// Search up to the next midnight after [to] (the picked day is inclusive).
  DateTime? get toExclusive => to == null ? null : DateTime(to!.year, to!.month, to!.day + 1);

  /// Number of active filters, shown on the filter button (dates counted once).
  int get activeCount => [
        levels.isNotEmpty,
        actions.isNotEmpty,
        screen != null,
        userId != null,
        docType != null,
        uploadState != null,
        from != null,
      ].where((x) => x).length;

  LogFilter copyWith({
    Set<String>? levels,
    Set<String>? actions,
    String? Function()? screen,
    String? Function()? userId,
    String? Function()? docType,
    int? Function()? uploadState,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) =>
      LogFilter(
        levels: levels ?? this.levels,
        actions: actions ?? this.actions,
        screen: screen != null ? screen() : this.screen,
        userId: userId != null ? userId() : this.userId,
        docType: docType != null ? docType() : this.docType,
        uploadState: uploadState != null ? uploadState() : this.uploadState,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
      );

  bool sameAs(LogFilter o) =>
      _setEq(levels, o.levels) &&
      _setEq(actions, o.actions) &&
      screen == o.screen &&
      userId == o.userId &&
      docType == o.docType &&
      uploadState == o.uploadState;

  static bool _setEq(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}

/// One-tap error filters. Dates and search text are kept when switching.
enum LogPreset {
  all('All'),
  errors('Errors'),
  problems('Errors + warnings'),
  network('Network'),
  crashes('Crashes'),
  failedWork('Failed work'),
  login('Login problems'),
  waiting('Waiting upload');

  final String label;
  const LogPreset(this.label);

  static const _problemLevels = {'ERROR', 'WARN'};

  /// Filter for this preset, keeping the dates from [base].
  LogFilter apply(LogFilter base) {
    final keep = LogFilter(from: base.from, to: base.to);
    return switch (this) {
      all => keep,
      errors => keep.copyWith(levels: {'ERROR'}),
      problems => keep.copyWith(levels: _problemLevels),
      // Server unreachable, timeouts, DNS, retries, Wi-Fi changes
      network => keep.copyWith(levels: _problemLevels, actions: {
          'Http', 'HttpFailed', 'Retry', 'RetryGaveUp', 'Network', 'NetworkCheck',
        }),
      crashes => keep.copyWith(actions: {'FlutterError', 'UncaughtError'}),
      // Work that did not complete: downloads, finalizes, local saves, lookups
      failedWork => keep.copyWith(levels: _problemLevels, actions: {
          'SyncFailed', 'SyncNoItems', 'FinalizeStart', 'FinalizeFailed', 'FinalizeCleanup',
          'LocalDbError', 'SaveQty', 'OpenScan', 'ReturnStart', 'ReturnResume',
          'PartLookup', 'CustomerSearch', 'LoadCompanies', 'LoadPickers', 'LoadReasons',
          'ReportSearch', 'UpdateDownload',
        }),
      login => keep.copyWith(actions: {
          'LoginFailed', 'SessionExpired', 'Permission', 'AdminLoginFailed',
          'AdminLocked', 'AdminPinFailed',
        }),
      waiting => keep.copyWith(uploadState: () => 0),
    };
  }

  /// The preset matching [f] (ignoring dates), or null for a custom filter.
  static LogPreset? matching(LogFilter f) {
    for (final p in values) {
      if (p.apply(f).sameAs(f)) return p;
    }
    return null;
  }
}
