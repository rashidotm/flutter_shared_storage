import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineString } from "firebase-functions/params";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import sharp from "sharp";
import ffmpeg from "fluent-ffmpeg";
import * as ffmpegInstaller from "@ffmpeg-installer/ffmpeg";

admin.initializeApp();
ffmpeg.setFfmpegPath(ffmpegInstaller.path);

// Storage-triggered functions must run in the same region as the bucket.
// Change this to match your default bucket's region (visible in the
// Firebase console under Storage → Files; common values:
// us-east1, us-central1, us-west1, nam5, eur3).
setGlobalOptions({ region: "us-east1", memory: "1GiB", timeoutSeconds: 300 });

// Configured per deploy. The function only processes objects whose path
// starts with STORAGE_PREFIX, and writes thumb/preview URLs to the matching
// Firestore document at `${FIRESTORE_PREFIX}/{nodeId}`.
//
// Set these at deploy time, e.g.:
//   firebase deploy --only functions
// and supply values via `.env` in this directory or via the CLI prompt.
// Example .env:
//   STORAGE_PREFIX=users
//   FIRESTORE_PREFIX=users
//
// Storage object layout the function expects:
//   {STORAGE_PREFIX}/.../{nodeId}/original.{ext}
// Firestore doc layout the function writes to:
//   {FIRESTORE_PREFIX}/{nodeId}    (or a parent path; nodeId is the doc id)
const STORAGE_PREFIX = defineString("STORAGE_PREFIX", {
  description: "Bucket-relative prefix the function should process (e.g. 'users').",
});
const FIRESTORE_PREFIX = defineString("FIRESTORE_PREFIX", {
  description: "Firestore collection path that contains node docs by id (e.g. 'users/{uid}/nodes' is invalid here — supply a concrete collection at deploy time or fan out per tenant).",
});

const THUMB_WIDTH = 256;
const PREVIEW_WIDTH = 1024;

/**
 * Triggered on every storage finalize; filters by STORAGE_PREFIX and only
 * processes files named `original.*` (skips its own thumb.jpg / preview.jpg
 * outputs to avoid infinite loops).
 *
 * Storage object layout:
 *   `${STORAGE_PREFIX}/{...arbitrary...}/{nodeId}/original.{ext}`
 *
 * On success, writes `thumbnailUrl` and `previewUrl` to
 *   `${FIRESTORE_PREFIX}/{nodeId}`
 */
export const onUpload = onObjectFinalized(async (event) => {
  const obj = event.data;
  const filePath = obj.name;
  if (!filePath) return;

  const storagePrefix = STORAGE_PREFIX.value();
  const firestorePrefix = FIRESTORE_PREFIX.value();
  if (!storagePrefix || !firestorePrefix) {
    console.warn("STORAGE_PREFIX / FIRESTORE_PREFIX not configured; skipping.");
    return;
  }

  // Only process files under the configured prefix.
  const normalizedPrefix = storagePrefix.replace(/\/+$/, "") + "/";
  if (!filePath.startsWith(normalizedPrefix)) return;

  const parsed = path.parse(filePath);
  if (parsed.name !== "original") return; // ignore our own thumb/preview

  // Storage layout assumed: `<prefix>/.../<nodeId>/original.<ext>`
  // The parent directory's basename is the nodeId.
  const parentDir = path.posix.basename(path.posix.dirname(filePath));
  if (!parentDir) return;
  const nodeId = parentDir;

  const contentType = obj.contentType ?? "";
  const isImage = contentType.startsWith("image/");
  const isVideo = contentType.startsWith("video/");
  if (!isImage && !isVideo) return;

  const bucket = admin.storage().bucket(obj.bucket);
  const tmpOriginal = path.join(os.tmpdir(), `${nodeId}-${parsed.base}`);
  await bucket.file(filePath).download({ destination: tmpOriginal });

  try {
    let thumbBuf: Buffer;
    let previewBuf: Buffer;

    if (isImage) {
      thumbBuf = await sharp(tmpOriginal).rotate().resize({ width: THUMB_WIDTH }).jpeg({ quality: 75 }).toBuffer();
      previewBuf = await sharp(tmpOriginal).rotate().resize({ width: PREVIEW_WIDTH }).jpeg({ quality: 80 }).toBuffer();
    } else {
      const tmpFrame = path.join(os.tmpdir(), `${nodeId}-frame.jpg`);
      await extractVideoFrame(tmpOriginal, tmpFrame);
      thumbBuf = await sharp(tmpFrame).resize({ width: THUMB_WIDTH }).jpeg({ quality: 75 }).toBuffer();
      previewBuf = await sharp(tmpFrame).resize({ width: PREVIEW_WIDTH }).jpeg({ quality: 80 }).toBuffer();
      fs.unlinkSync(tmpFrame);
    }

    // Write thumb/preview alongside the original.
    const dir = path.posix.dirname(filePath);
    const thumbPath = `${dir}/thumb.jpg`;
    const previewPath = `${dir}/preview.jpg`;

    await Promise.all([
      bucket.file(thumbPath).save(thumbBuf, { contentType: "image/jpeg", resumable: false }),
      bucket.file(previewPath).save(previewBuf, { contentType: "image/jpeg", resumable: false }),
    ]);

    const [thumbUrl, previewUrl] = await Promise.all([
      signedUrl(bucket, thumbPath),
      signedUrl(bucket, previewPath),
    ]);

    // Resolve to the Firestore doc at `${firestorePrefix}/{nodeId}`. The
    // prefix may itself contain "/" — Firestore's `.doc(path)` handles
    // multi-segment paths.
    const docPath = `${firestorePrefix.replace(/\/+$/, "")}/${nodeId}`;
    await admin.firestore().doc(docPath).update({
      thumbnailUrl: thumbUrl,
      previewUrl: previewUrl,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } finally {
    if (fs.existsSync(tmpOriginal)) fs.unlinkSync(tmpOriginal);
  }
});

function extractVideoFrame(input: string, output: string): Promise<void> {
  return new Promise((resolve, reject) => {
    ffmpeg(input)
      .on("end", () => resolve())
      .on("error", reject)
      .screenshots({ timestamps: ["1"], filename: path.basename(output), folder: path.dirname(output) });
  });
}

async function signedUrl(bucket: ReturnType<typeof admin.storage>["bucket"] extends () => infer R ? R : never, p: string): Promise<string> {
  // Long-lived signed URL — adjust for your needs (or use getDownloadURL via client).
  const [url] = await bucket.file(p).getSignedUrl({
    action: "read",
    expires: Date.now() + 1000 * 60 * 60 * 24 * 365 * 10, // 10y
  });
  return url;
}
