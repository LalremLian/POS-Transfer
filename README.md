# POS Transfer — Background File Transfer Module

A production-minded Flutter application for a POS SaaS platform demonstrating reliable background file uploads and downloads.

---

## Overview

The app allows authenticated users to upload files to a remote server and download them back — with full background execution, real HTTP Range resumable downloads, Android foreground service, system notifications, transfer queue management, and network resilience.

**What it demonstrates:**
- Clean Architecture with feature-first folder structure
- Riverpod state management with isolated per-transfer progress
- Android foreground service (transfers survive app minimisation)
- Real HTTP 206 Range-based resumable downloads
- File-backed streaming I/O (no whole-file memory loading)
- Configurable transfer queue (max 3 concurrent)
- Exponential backoff retry with jitter
- System notifications with throttled progress updates
- Network connectivity monitoring with auto-pause/resume
- SHA-256 integrity verification on completed downloads

---

## Architecture

### Clean Architecture + Feature-First

```
lib/
├── main.dart
├── app/
│   ├── app.dart                        ← root widget + notification tap wiring
│   ├── di/providers.dart               ← all Riverpod providers
│   ├── router/app_router.dart          ← GoRouter + auth guard + splash
│   └── theme/app_theme.dart            ← Material 3 POS colour scheme
├── core/
│   ├── constants/                      ← API endpoints, app constants
│   ├── errors/                         ← failures, exceptions, error_handler
│   ├── network/                        ← DioClient, AuthInterceptor, NetworkInfo
│   ├── services/
│   │   ├── background_transfer_service.dart  ← foreground service lifecycle
│   │   ├── notification_service.dart         ← flutter_local_notifications
│   │   └── transfer_service_observer.dart    ← root widget: wires service + notifs
│   ├── transfer/transfer_config.dart   ← all configurable settings in one place
│   └── utils/                          ← FileUtils, SpeedTracker, DateUtils
└── features/
    ├── authentication/                 ← login/register, secure token storage
    ├── transfers/                      ← TransferEntity, TransferManager, queue, providers
    ├── uploads/                        ← executor, repository, screen, notifier
    ├── downloads/                      ← executor, repository, screen, notifier
    └── dashboard/                      ← dashboard screen
```

### Dependency Rule

Each layer depends only inward:

```
Presentation (screens, Riverpod providers)
    ↓
Domain (entities, repository abstractions, TransferManager)
    ↓
Data (Dio repositories, SharedPreferences, secure storage)
```

No screen imports Dio. No domain entity imports Flutter widgets. The `TransferManager` owns no HTTP logic — it delegates execution to pluggable `TransferExecutor` functions registered by the upload and download features.

### Note on use cases

Use case classes were intentionally omitted. At this scale, every use case would be a one-line wrapper around a repository method with no business logic of its own. The repository is the domain boundary. Use cases would be introduced if operations needed to orchestrate multiple repositories or if the same operation were called from several independent entry points.

---

## State Management

### Why Riverpod

Riverpod provides compile-safe dependency injection, testable providers with no `BuildContext` dependency, and first-class support for async state. It was the specified requirement and the right tool for a background-transfer app where state must outlive individual screens.

### How global transfer state works

`TransferManager` is a plain Dart class (no Flutter imports). It owns the source-of-truth `Map<String, TransferEntity>` and two broadcast stream types:

1. **Per-transfer stream** — `manager.watch(id)` returns a `Stream<TransferEntity>` for one transfer. Widgets subscribe via `transferProvider(id)` (a `StreamProvider.family`). Progress updates on transfer A never cause a rebuild of the widget watching transfer B.

2. **Roster stream** — `manager.watchAll()` emits `List<TransferEntity>` only on structural/status changes (started, completed, failed, cancelled) — never on progress ticks. The dashboard watches this for counts and grouping.

### Isolated per-transfer state

```dart
// Each card subscribes to its own stream — zero cross-rebuild
final transferProvider = StreamProvider.family<TransferEntity, String>(
  (ref, id) => ref.watch(transferManagerProvider).watch(id),
);
```

A `TransferCard` widget watches `transferProvider(transferId)`. When a 100 MB download ticks its progress every 500 ms, only the card for that download rebuilds. All other cards are unaffected.

### Progress throttling

The manager's `updateProgress()` throttles UI stream emissions to 500 ms (`TransferConfig.uiProgressIntervalMs`) and database writes to 5 s (`metadataPersistIntervalMs`). Status changes (complete, fail, cancel, pause) always emit and persist immediately — they bypass the throttle.

---

## Background Execution

### Android Foreground Service

Long-running user-initiated transfers run under an Android foreground service using `flutter_foreground_task`. The service starts when the first transfer becomes active and stops when no active transfers remain.

```
User taps Download
    → TransferManager.enqueueDownload()
    → TransferServiceObserver sees active count > 0
    → BackgroundTransferService.startIfNeeded()
    → Android foreground service starts with persistent notification
    → DownloadExecutor streams to disk
    → User minimises app — transfer continues
    → Notification updates with filename + percentage
    → Transfer completes → markCompleted() → service stops
```

The `TransferServiceObserver` is an invisible `ConsumerStatefulWidget` placed above the router in the widget tree. It watches the roster stream and starts/stops the service and fires notifications regardless of which screen is visible.

### Permissions (AndroidManifest.xml)

```xml
INTERNET, ACCESS_NETWORK_STATE
FOREGROUND_SERVICE
FOREGROUND_SERVICE_DATA_SYNC      <!-- Android 14+ required -->
POST_NOTIFICATIONS                <!-- Android 13+ runtime permission -->
READ_MEDIA_IMAGES / VIDEO / AUDIO <!-- Android 13+ scoped storage -->
READ_EXTERNAL_STORAGE (maxSdk 32) <!-- Android 12 and below -->
WAKE_LOCK, RECEIVE_BOOT_COMPLETED
```

### Platform restrictions

| Scenario | Behaviour |
|---|---|
| App minimised | Transfer continues — foreground service keeps process alive |
| Screen rotation / nav | Transfer unaffected — `TransferManager` has no widget lifecycle dependency |
| Android 15+ | `dataSync` foreground service limited to 6 hours per session |
| Force-stop | Service terminated immediately — no workaround |
| Battery optimisation | Manufacturer restrictions may kill the service on some devices |
| Device shutdown | All services terminated |

---

## Upload

### How it works

Uploads use `MultipartFile.fromFile(filePath, filename: fileName)` — Dio streams the file from disk as the multipart request body. The entire file is never loaded into RAM. Verified with a 60 MB file.

```
FilePicker selects file
    → UploadNotifier.startUpload()
    → TransferManager.enqueueUpload()
    → TransferQueue slot opens
    → UploadExecutor.call(transfer)
    → UploadRepositoryImpl.upload()
    → Dio POST /upload multipart (file-backed)
    → onSendProgress → manager.updateProgress() [throttled 500ms]
    → 201 response → manager.markCompleted()
```

### Pause / resume limitation

The backend (`POST /upload`) does not support resumable uploads. There is no chunk endpoint or upload session API.

- **Pause** cancels the active Dio request via `CancelToken` and preserves the local file reference.
- **Resume** restarts the upload from byte 0.

This is communicated in the UI (limitation note below the progress bar) and is not faked.

### Retry strategy

Up to 3 retries with exponential backoff:

```
delay = initialDelay × 2^attempt + jitter
      = 1000 × 2^0 + random(0..300) = ~1–1.3 s (attempt 0)
      = 1000 × 2^1 + random(0..600) = ~2–2.6 s (attempt 1)
      = 1000 × 2^2 + random(0..900) = ~4–4.9 s (attempt 2)
      capped at maxRetryDelay = 30 s
```

Permanent errors (400, 401, 403, 404, 415) fail immediately with no retry. HTTP 429 respects `Retry-After` when present.

---

## Download

### Streaming to disk

Downloads use `ResponseType.stream` — Dio's response body is never buffered in RAM. Each chunk is written directly to a `.part` temporary file as it arrives.

```
DownloadNotifier.startDownload(file)
    → creates PosTransfer/ directory
    → TransferManager.enqueueDownload()
    → DownloadExecutor.call(transfer)
    → reads .part file size (resume offset)
    → GET /get?file=NAME  [Range: bytes=N-]
    → streams chunks → writes to .part
    → onProgress → manager.updateProgress() [throttled 500ms]
    → stream ends → _finalize()
    → verify size, compute SHA-256
    → rename .part → final filename (atomic)
    → manager.markCompleted(localChecksum: sha256)
```

### HTTP Range resumable downloads

The backend returns HTTP 206 Partial Content when a `Range` header is sent, confirmed in Phase 10 verification (`Content-Range: bytes 10-49/50`).

On resume:
1. Read the existing `.part` file size → `startBytes`
2. Send `Range: bytes=startBytes-`
3. Validate HTTP 206 response
4. If server returns 200 (Range ignored) → restart from byte 0, overwrite `.part`
5. Append bytes from `startBytes` onwards

### Atomic finalization

Completed files are never at risk of corruption:

```
download completes
    → verify actual file size ≈ Content-Length (1 MB tolerance)
    → compute SHA-256 incrementally (no RAM spike)
    → resolve collision-safe destination filename
    → File.rename(.part → final)   ← atomic on same filesystem
    → manager.markCompleted()
```

An incomplete `.part` file is never shown as a completed download.

### SHA-256

Computed using `sha256.startChunkedConversion()` — the file is read in stream chunks and fed to the hash function incrementally. A 100 MB file produces a 64-char hex digest without loading more than one chunk at a time into RAM.

This is a **locally calculated digest**. The backend does not supply checksums. The digest is stored in `TransferEntity.localChecksum` and displayed in the Transfer Details screen (long-press to copy).

---

## Performance Optimisations

### Transfer concurrency

`TransferQueue(maxConcurrent: 3)` — at most 3 uploads/downloads run simultaneously. Additional transfers wait in a FIFO pending list and start as slots free. Configurable via `TransferConfig.maxConcurrentTransfers`.

### Throttling summary

| Update type | Interval | Override |
|---|---|---|
| UI progress stream | 500 ms | Status changes bypass |
| Notification progress | 2 000 ms | Completion/failure bypass |
| Metadata persistence | 5 000 ms | Status changes bypass |

### Memory efficiency

- Uploads: `MultipartFile.fromFile` — disk → socket, no whole-file buffer
- Downloads: `ResponseType.stream` → direct disk write, no whole-file buffer
- SHA-256: chunked conversion, one chunk in RAM at a time

### Speed calculation

`SpeedTracker` samples transferred bytes at a configurable interval (1 s default), applies exponential smoothing (`speed = 0.5 × prev + 0.5 × instant`) to prevent display jitter, and holds the last known speed across zero-byte intervals rather than dropping to zero.

---

## Network Resilience

### Connectivity monitoring

`NetworkInfo` wraps `connectivity_plus`. When the connectivity state changes:

- **Offline:** all running/preparing transfers are auto-paused and their IDs recorded in `_autoPausedIds`. New enqueues remain in the queue.
- **Back online:** only the auto-paused transfers are resumed — not any transfer the user deliberately paused.

A red banner is shown on the dashboard while offline.

> **Note:** `connectivity_plus` reports interface availability, not actual internet reachability. A successful API call is the only guarantee of real connectivity. The app treats a 429/5xx response as transient and retries accordingly.

### Retry policy

| Error type | Behaviour |
|---|---|
| Connection timeout / reset | Retry with backoff |
| HTTP 429 | Retry; respects `Retry-After` header |
| HTTP 5xx | Retry with backoff |
| HTTP 400 | Fail immediately |
| HTTP 401 | Fail immediately (session expired message) |
| HTTP 403 | Fail immediately |
| HTTP 404 | Fail immediately |
| HTTP 415 | Fail immediately (file type not allowed) |
| `CancelToken` cancel | No retry (user action) |

---

## API Integration

Base URL: `http://108.136.142.112:90`

> **Security note:** The backend is HTTP only. All credentials and tokens are transmitted unencrypted. This is a backend limitation, not a client choice. See Future Improvements.

### Endpoints

| Method | Path | Auth | Description |
|---|---|---|---|
| `POST` | `/register` | — | Create account. Body: `username`, `password` (form) |
| `POST` | `/token` | — | Log in. Body: `username`, `password` (form) |
| `GET` | `/get` | Bearer | List files owned by the user |
| `GET` | `/get?file=NAME` | Bearer | Download file. Supports `Range` header → HTTP 206 |
| `POST` | `/upload` | Bearer | Upload file. Multipart field: `file` |
| `DELETE` | `/delete?file=NAME` | Bearer | Delete a file |

### Auth token

- Format: JWT, returned as `token` field in login/register response
- Lifetime: 86 400 s (24 hours)
- Stored in `flutter_secure_storage` (Android Keystore encrypted)
- Never logged, never included in error messages

### File naming

The backend appends a hex suffix to avoid collisions:  
`original.csv` → `original_fc87809b.csv`

The original name is preserved in `original_name` field.

### Error format

```json
{ "success": false, "error": "Invalid username or password" }
```

---

## Setup & Run

### Requirements

- Flutter ≥ 3.18.0 (Dart ≥ 3.8.1)
- Android SDK with `minSdk 21`
- Gradle 8.12

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Build debug APK

```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

### Build release APK

```bash
flutter build apk --release
# Requires a signing config in android/app/build.gradle.kts
```

### Static analysis

```bash
flutter analyze
# Expected: No issues found
```

### Android permissions (auto-requested at runtime)

- `POST_NOTIFICATIONS` — requested on first transfer start (Android 13+)
- Storage permissions — handled by `file_picker` on file selection

---

## Configuration

All transfer behaviour is controlled from one place:

```dart
// lib/core/transfer/transfer_config.dart
const transferConfig = TransferConfig(
  maxConcurrentTransfers: 3,
  maxRetryAttempts: 3,
  initialRetryDelayMs: 1000,
  maxRetryDelayMs: 30000,
  connectionTimeoutMs: 30000,
  uiProgressIntervalMs: 500,
  notificationIntervalMs: 2000,
  metadataPersistIntervalMs: 5000,
);
```

---

## Known Limitations

### Resumable uploads not supported
The backend exposes a single `POST /upload` multipart endpoint with no chunk or session API. Pausing an upload cancels the HTTP request; resuming restarts from byte 0. The UI communicates this explicitly.

### HTTP only
The backend does not support HTTPS. All traffic including credentials is unencrypted. In production, the server would be placed behind a TLS-terminating reverse proxy.

### Server checksums unavailable
The backend does not return a file checksum in any response header or body field. The SHA-256 shown in Transfer Details is a locally computed digest — it proves the file was written to disk correctly but cannot prove the server stored the identical bytes.

### No token refresh
The backend issues 24-hour tokens with no refresh endpoint. After expiry, the user must log in again. A forced re-login flow on 401 is handled in the error layer.

### Android 15 foreground service limit
`dataSync` foreground services are limited to 6 hours per session on Android 15+. Very long transfers on Android 15 devices may be interrupted by the OS.

### Device-level restrictions
Force-stop, battery optimisation, and manufacturer-specific process killing (common on Xiaomi, Huawei, OnePlus) can terminate the foreground service. These are OS-level behaviours with no Flutter workaround.

---

## Future Improvements

### Chunked resumable uploads (tus protocol)
If the backend is extended to support [tus](https://tus.io), the `UploadExecutor` and `UploadRepository` can be replaced with a `tus_client`-backed implementation without touching the UI, `TransferManager`, or any other layer. `TransferConfig.uploadChunkSize` is already reserved for this purpose.

### HTTPS
Add TLS to the backend (nginx `ssl` block + Let's Encrypt certificate) and update `ApiConstants.baseUrl` to `https://`. The app requires no other changes.

### Server-side checksums
Add an `X-Checksum-SHA256` response header to the upload endpoint. The app already stores `expectedChecksum` in `TransferEntity` and the download executor already has the verification path — it just needs a trusted value to compare against.

### SQLite persistence (drift)
The current SharedPreferences JSON store is sufficient for dozens of transfers. For hundreds or more, migrate `TransferRepositoryImpl` to a drift SQLite backend. The abstract `TransferRepository` interface means this is a data-layer swap only.

### Offline-first file list
Cache the remote file list in a local table. When offline, the download screen shows the last-known list instead of an empty state.
