# cloud_storage_platform_interface

Backend-agnostic contract for [`cloud_storage`](../cloud_storage). Implement [`CloudStorage`](lib/src/cloud_storage.dart) to add support for a new backend (S3, Supabase, ...).

App code depends on `cloud_storage`, not this package directly.
