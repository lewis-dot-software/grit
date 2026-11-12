/// How one run of a property's body ended.
enum Status {
  /// More choices asked for than the source holds, past a fixed sequence's
  /// end or a random fill's limit.
  overrun,

  /// The run ended as invalid: an assumption that was false, a filter that
  /// gave up, or a fixed choice above the bound its generator asks for.
  rejected,

  /// The body returned.
  returned,

  /// The body threw.
  failed,
}
