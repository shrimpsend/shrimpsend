# S3 Overview (Mainland China)

Bring-your-own S3-compatible storage powers wide-area file transfer. The web app uploads directly to presigned URLs in the browser, so in addition to Endpoint, credentials, and bucket permissions you **must configure bucket CORS correctly**.

Use the left sidebar to open step-by-step guides for each cloud provider (with console screenshots).

## When you need S3

- Devices are not on the same LAN.
- Files are large and need a stable wide-area relay.
- You want file payloads stored in your own object storage.
- LAN direct, WebRTC, or HTTP direct paths are unavailable.

## Settings fields

Under **Settings → S3**, fill in:

| Field | Description |
| --- | --- |
| Endpoint | S3 API root URL including scheme, e.g. `https://cos.ap-guangzhou.myqcloud.com`. |
| Region | Bucket region; naming varies by vendor—match the console. |
| Bucket | Bucket used for relay and temporary storage. |
| Access Key ID | Prefer a sub-account key scoped to this bucket only. |
| Secret Access Key | Sent only when saving or testing; leave blank on edit to keep the existing secret. |

![ShrimpSend S3 settings form](/docs/s3/common/settings-form-en.png)

## Bucket permissions

Create a dedicated sub-account or access key for ShrimpSend with least privilege on the target bucket:

- PutObject, GetObject, DeleteObject.
- Multipart APIs: CreateMultipartUpload, UploadPart, ListParts, CompleteMultipartUpload, AbortMultipartUpload.

Do not use root account keys or grant access to unrelated buckets.

## CORS is required

The browser sends cross-origin requests to your storage domain. AllowedOrigins must include the Origin where users open the ShrimpSend web app:

```text
https://xiachuan.net
```

Add `https://www.xiachuan.net` if needed. No path suffix; no trailing `/`.

## CORS reference

| Item | Recommended |
| --- | --- |
| AllowedOrigins | Actual ShrimpSend web Origin(s). |
| AllowedMethods | At least `GET`, `PUT`, `POST`, `DELETE`, `HEAD`. |
| AllowedHeaders | `*` or at least `content-type`, `content-md5`, `x-amz-*`, `x-amz-date`, `authorization`. |
| ExposeHeaders | At least `ETag`. |
| MaxAgeSeconds | e.g. `86400` to reduce preflight traffic. |

## Provider guides

Pick your storage vendor in the sidebar (**Bitiful is recommended first**):

- [Bitiful (Recommended)](/en/docs/s3/bitiful)
- [CSTCloud Data Capsule](/en/docs/s3/data-capsule)
- [Tencent COS](/en/docs/s3/tencent-cos)
- [Cloudflare R2](/en/docs/s3/cloudflare-r2)
- [RustFS](/en/docs/s3/rustfs)

## Test connection

After saving, click **Test connection**. If it fails, check in order:

1. Endpoint includes `https://`.
2. Region and Bucket match the console.
3. Keys have bucket-scoped permissions.
4. CORS includes the current web Origin.
5. Storage is reachable from your network.

## Data boundary

With custom S3, file bytes live in your bucket. ShrimpSend servers mainly issue presigned URLs and store transfer metadata.
