# flutter_shared_storage

[![CI](https://github.com/rashidotm/flutter_shared_storage/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/rashidotm/flutter_shared_storage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A federated Flutter package suite for storing files and folders in the cloud, with a Firebase backend.

## Packages

| Package | Purpose |
|---|---|
| [`cloud_storage_platform_interface`](packages/cloud_storage_platform_interface) | Backend-agnostic contract: `CloudStorage`, `CloudNode`, `UploadTask`, etc. Depend on this if you're writing a new backend. |
| [`cloud_storage_firebase`](packages/cloud_storage_firebase) | Firebase Storage + Firestore implementation of the interface. |
| [`cloud_storage`](packages/cloud_storage) | Umbrella package. Re-exports the interface and the default Firebase implementation. Depend on this from app code. |
| [`cloud_storage_gallery`](packages/cloud_storage_gallery) | Optional photo/video viewer + folder grid widgets. |

Plus:

- [`example/`](example) — demo Flutter app exercising upload, browse, and the gallery viewer.

## Architecture at a glance

```
+----------------+     +---------------------------+
|   your app     | --> | cloud_storage (umbrella)  |
+----------------+     +-------------+-------------+
                                     |
                +--------------------+--------------------+
                |                                         |
   cloud_storage_platform_interface   <-- implements --   cloud_storage_firebase
                                                          (Firestore + Storage)
```

## Design choices

- **Federated plugin pattern.** New backends (S3, Supabase, ...) implement `CloudStorage` and ship as a separate package.
- **Firestore for metadata, Storage for bytes.** Listings and folder hierarchy live in Firestore for fast, real-time reads.
- **Caller-supplied paths.** The package makes no assumption about where data lives — you pass `firestorePath` and `storagePath` to `FirebaseCloudStorage(...)`. Auth, tenancy, and access control are entirely your concern.
- **No sharing logic.** Access control is the consumer's responsibility (security rules + custom claims).
- **Headless core, optional UI.** Gallery widgets are a separate package; the core API is repository-style with streams.
- **Client-side thumbnails.** The caller generates thumbnail + preview JPEGs and passes them to `upload()` alongside the original — the package writes them to the well-known variant paths. No Cloud Functions, no Blaze plan required.
- **Auto-rename on conflict.** Same-name uploads/folders get a `(1)`, `(2)`, ... suffix.
- **Theme- and locale-aware widgets.** The gallery package has no inline colors and respects `Directionality.of(context)` for RTL/LTR.

## Getting started

```bash
dart pub global activate melos
melos bootstrap
melos run analyze
```

## Platforms

First release targets **Android** and **iOS**. Web/desktop can be added by the Firebase implementation since `firebase_storage` and `cloud_firestore` already support them — the gallery package's video viewer is the main blocker.
