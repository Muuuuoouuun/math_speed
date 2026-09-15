class DeterministicRng {
  DeterministicRng(int seed) : _state = seed == 0 ? 0x6D2B79F5 : seed & 0xFFFFFFFF;

  int _state;

  int nextInt(int maxExclusive) {
    _state ^= (_state << 13) & 0xFFFFFFFF;
    _state ^= (_state >> 17) & 0xFFFFFFFF;
    _state ^= (_state << 5) & 0xFFFFFFFF;
    final value = _state & 0x7FFFFFFF;
    return maxExclusive == 0 ? 0 : value % maxExclusive;
  }

  int between(int minInclusive, int maxInclusive) {
    return minInclusive + nextInt((maxInclusive - minInclusive) + 1);
  }
}
