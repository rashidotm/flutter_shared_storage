# Cloud Functions — thumbnail generation

Generates thumbnails and previews for files uploaded by `cloud_storage_firebase`.

## Trigger

Storage `onObjectFinalized` for `${STORAGE_PREFIX}/.../{nodeId}/original.*`. The function:

1. Skips objects outside the configured `STORAGE_PREFIX`.
2. Skips its own `thumb.jpg` / `preview.jpg` outputs (filters on basename `original`).
3. Downloads the original.
4. Resizes images with `sharp`, or extracts a video frame with `fluent-ffmpeg`.
5. Uploads `thumb.jpg` (256 px) and `preview.jpg` (1024 px) next to the original.
6. Updates `${FIRESTORE_PREFIX}/{nodeId}` with `thumbnailUrl` + `previewUrl`.

## Configuration

The function is **prefix-configured per deploy**. Set these two parameters before each deployment:

| Param | Example | Meaning |
|---|---|---|
| `STORAGE_PREFIX` | `users/abc123/blobs` | Only objects under this bucket prefix are processed. Must match the package's `storagePath`. |
| `FIRESTORE_PREFIX` | `users/abc123/nodes` | Firestore collection path where node docs live, keyed by id. Must match the package's `firestorePath`. |

### How to set them

Easiest: copy `.env.example` → `.env` and fill in the values:

```bash
cp .env.example .env
# edit .env
```

Or use a per-project file like `.env.flutter-shared-storage` that's auto-loaded for that project.

Firebase will also prompt you for any unset values on first deploy.

## Deploy

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

Requires the **Blaze** (pay-as-you-go) plan because Storage triggers go through Eventarc.

## Trade-offs of per-deploy prefixes

This approach is simplest when:
- You have **one tenant** (the values are stable and you control them).
- Or you're willing to deploy **one function per tenant** and isolate them.

For multi-tenant apps where many users share a single function deploy, you'd want a more dynamic strategy — most likely:
- Use the `customMetadata.nodeId` already set by the package, plus extract the tenant id from the storage path with a regex.
- Or store `firestoreDocPath` in custom metadata and read it back.

Both are straightforward extensions of the current `onUpload` handler.

## Tweaking

- Output sizes: `THUMB_WIDTH` / `PREVIEW_WIDTH` in `src/index.ts`.
- Region/memory/timeout: `setGlobalOptions(...)` at the top of `src/index.ts`. **Must match your bucket's region.**
- URL strategy: this file uses signed URLs valid for 10 years. If you'd rather use Firebase's `getDownloadURL` flow with security rules, replace `signedUrl()` accordingly.
