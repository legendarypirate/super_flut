/// Compares semantic version strings (e.g. 1.0.16 vs 1.0.17).
/// Returns negative if [a] < [b], zero if equal, positive if [a] > [b].
int compareSemver(String a, String b) {
  final pa = a.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final pb = b.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va < vb) return -1;
    if (va > vb) return 1;
  }
  return 0;
}

/// True if installed [currentVersion] is strictly below [minimumVersion].
bool isBelowMinimum(String currentVersion, String minimumVersion) {
  return compareSemver(currentVersion, minimumVersion) < 0;
}
