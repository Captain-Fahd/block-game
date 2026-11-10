/// Seed for the daily challenge, derived from the local date as `yyyymmdd`.
/// [SeededRng] scrambles the seed, so adjacent dates give unrelated games.
int dailySeed(DateTime localDate) =>
    localDate.year * 10000 + localDate.month * 100 + localDate.day;

/// `yyyymmdd` key for storing per-day results.
String dailyKey(DateTime localDate) => dailySeed(localDate).toString();
