# POD / Secondary Sales — Development Rules

## Overview

The **Zydus Vistaar POD** application is integrated as an **isolated feature** inside the
**ZForce / Himalaya SFA** application. It is NOT a second application.

There is **one** repository, **one** `pubspec.yaml`, **one** `main.dart`, **one** Android
application, and **one** APK/AAB.

---

## Directory Ownership

### POD developer owns:
```
lib/features/pod/**
assets/pod/**
```

### SFA / shared approval required for:
```
pubspec.yaml
lib/main.dart
lib/presentation/dashboard/dashboard_screen.dart
android/**
ios/**
Firebase configuration (lib/firebase_options.dart, android/app/google-services.json)
Authentication (lib/providers/auth_provider.dart)
Global API configuration (lib/core/constants/api_constants.dart)
Shared database infrastructure (lib/data/services/)
```

---

## Navigation Entry Point

```
SFA Dashboard
  └── Field Operations
        └── Secondary Sales          ← _MenuAction in dashboard_screen.dart
              └── PodEntryScreen     ← lib/features/pod/pod_entry_screen.dart
                    └── MainNavigation (existing POD UX preserved as-is)
```

---

## Architecture

| Layer | SFA | POD |
|---|---|---|
| State management | Provider | BLoC (flutter_bloc) |
| Backend | himalaya.globalspace.in/api | zydus.mediola.in/pod_dev/api/ |
| Authentication | SFA AuthProvider | POD AuthService (deferred) |
| Firebase | himalaya-e7d22 project | DEFERRED |

Both Provider (SFA) and BLoC (POD) coexist. **Do NOT convert one to the other.**

---

## Rules — NEVER DO

- Do NOT create another `main.dart`
- Do NOT create another `pubspec.yaml`
- Do NOT create another Android application (`android/` at root)
- Do NOT create another iOS application (`ios/` at root)
- Do NOT copy `google-services.json` from POD over SFA
- Do NOT replace `lib/firebase_options.dart` with POD Firebase config
- Do NOT modify `lib/providers/auth_provider.dart` without SFA approval
- Do NOT modify `lib/data/services/api_service.dart` without SFA approval
- Do NOT change the application ID (`com.globalspace.himalaya`)
- Do NOT modify existing SFA screens
- Do NOT modify existing SFA menu items
- Do NOT rewrite POD BLoC to Provider
- Do NOT rewrite SFA Provider to BLoC
- Do NOT modify unrelated SFA code

---

## Deferred Integration Work (Requires Separate Phase)

| Item | Status | Notes |
|---|---|---|
| POD Authentication ↔ SFA AuthProvider | **DEFERRED** | SharedPreferences key collision risk |
| POD Firebase ↔ SFA Firebase | **DEFERRED** | firebase_analytics version conflict |
| POD FCM / Notifications ↔ SFA FCM | **DEFERRED** | Part of Firebase phase |
| POD API base URL → Himalaya backend | **DEFERRED** | Endpoint compatibility unconfirmed |
| SharedPreferences key deduplication | **DEFERRED** | authToken, userEmail, userName |

---

## POD Development Workflow

```
POD developer
  ↓  Create branch: feature/pod-xxxxx  (from himalaya_pod)
  ↓  Modify only:  lib/features/pod/**  and  assets/pod/**
  ↓  Run:  flutter analyze
  ↓  Run:  flutter build apk --debug
  ↓  Pull Request → SFA developer review
  ↓  CI / tests pass
  ↓  Merge → himalaya_pod
  ↓  ONE SFA APK/AAB
```

For any change outside `lib/features/pod/` or `assets/pod/`, explicit SFA team approval
is required before merging.

---

## External Services (Do NOT Replace)

These external services are used by POD and must NOT be replaced with the SFA backend
without explicit backend confirmation:

| Service | URL |
|---|---|
| PDF Splitter | https://anujakkulkarni-splitpdffile.hf.space |
| QR Extractor | https://anujakkulkarni-envoice-qr-extractor.hf.space |
| POD API      | https://zydus.mediola.in/pod_dev/api/ |

---

## minSdk Note

`minSdk` is set to **30** (Android 11) in `android/app/build.gradle.kts` because
`google_mlkit_document_scanner` and `flutter_doc_scanner` require Android 10+ (API 29).
This applies to the entire SFA+POD app.

---

*Generated during Phase 2 POD → SFA integration on himalaya_pod branch.*
