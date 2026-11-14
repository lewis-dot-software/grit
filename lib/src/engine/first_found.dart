/// Where a search first found the failure it reports.
enum FirstFound {
  /// A run of generation's random fills.
  generated,

  /// The replay of the failure the store held for the call site, from an
  /// earlier search.
  stored,
}
