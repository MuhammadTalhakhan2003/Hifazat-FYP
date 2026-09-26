class PaginatedResult<T> {
  final List<T> results;
  final bool hasNext;

  PaginatedResult({required this.results, required this.hasNext});
}