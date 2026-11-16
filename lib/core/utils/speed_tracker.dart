class SpeedTracker {
  SpeedTracker({this.sampleIntervalMs = 1000});

  final int sampleIntervalMs;

  DateTime? _lastTime;
  int _lastBytes = 0;
  double _currentSpeed = 0; // bytes/sec, smoothed

  /// Reset state. Call when an upload restarts from zero or a download resumes
  /// so stale samples don't corrupt the new measurement.
  void reset() {
    _lastTime = null;
    _lastBytes = 0;
    _currentSpeed = 0;
  }

  /// Feed the latest cumulative transferred-bytes value. Returns the current
  /// smoothed speed in bytes/sec. Callers should pass this to the UI only when
  /// a new sample is taken (this method returns the same value between samples).
  double update(int transferredBytes) {
    final now = DateTime.now();
    if (_lastTime == null) {
      _lastTime = now;
      _lastBytes = transferredBytes;
      return _currentSpeed; // first sample → unknown, keep 0
    }

    final elapsedMs = now.difference(_lastTime!).inMilliseconds;
    if (elapsedMs < sampleIntervalMs) {
      return _currentSpeed; // not enough time for a new sample
    }

    final delta = transferredBytes - _lastBytes;
    _lastTime = now;
    _lastBytes = transferredBytes;

    if (delta <= 0) {
      // No progress in this interval — hold the last known speed rather than
      // dropping to zero instantly (handles slow stretches fairly).
      return _currentSpeed;
    }

    final instant = delta / (elapsedMs / 1000.0);
    // Simple exponential smoothing so the displayed speed doesn't jump.
    _currentSpeed = _currentSpeed == 0 ? instant : _currentSpeed * 0.5 + instant * 0.5;
    return _currentSpeed;
  }

  double get currentSpeed => _currentSpeed;
}
