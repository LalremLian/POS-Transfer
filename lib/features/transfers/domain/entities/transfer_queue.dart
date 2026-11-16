class TransferQueue {
  TransferQueue({this.maxConcurrent = 3});

  final int maxConcurrent;

  final Set<String> _active = {};
  final List<String> _pending = []; // FIFO

  bool get hasCapacity => _active.length < maxConcurrent;
  int get activeCount => _active.length;
  int get pendingCount => _pending.length;
  int get totalInFlight => activeCount + pendingCount;

  Set<String> get activeIds => Set.unmodifiable(_active);
  List<String> get pendingIds => List.unmodifiable(_pending);

  /// Adds an id to the back of the pending list (if not already active/pending).
  void enqueuePending(String id) {
    if (_active.contains(id) || _pending.contains(id)) return;
    _pending.add(id);
  }

  /// Moves the head of the pending list into an active slot. Returns the id
  /// that started, or null if none pending / no capacity.
  String? occupyNext() {
    if (!hasCapacity || _pending.isEmpty) return null;
    final id = _pending.removeAt(0);
    _active.add(id);
    return id;
  }

  /// Promotes a specific pending id into an active slot.
  bool promote(String id) {
    if (!hasCapacity || !_pending.contains(id)) return false;
    _pending.remove(id);
    _active.add(id);
    return true;
  }

  void release(String id) {
    _active.remove(id);
  }

  void removeFromPending(String id) {
    _pending.remove(id);
  }

  bool isActive(String id) => _active.contains(id);
  bool isPending(String id) => _pending.contains(id);
  bool isQueuedOrActive(String id) => isActive(id) || isPending(id);
}
