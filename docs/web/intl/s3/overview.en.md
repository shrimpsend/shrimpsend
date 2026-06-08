# S3 Overview (International)

S3 is ShrimpSend’s fallback when LAN / WebRTC direct transfer is unavailable. The international deployment supports **built-in S3** and **custom S3**.

- By default, eligible users can use platform-managed storage—see [Built-in S3](/en/docs/s3/built-in).
- With custom S3, payloads go to your bucket; use the sidebar for provider-specific steps with screenshots.

## When you need S3

- Devices are not on the same LAN.
- LAN or WebRTC direct paths fail.
- The network blocks peer direct transfer but delivery must still work.
- You want payloads in storage you control.

## Settings fields

| Field | Description |
| --- | --- |
| Endpoint | S3 API root URL with scheme, e.g. `https://s3.amazonaws.com`. |
| Region | Bucket region—match the vendor console. |
| Bucket | Bucket for relay and temporary files. |
| Path-style access | On: `{endpoint}/{bucket}/{key}` (typical for MinIO). Off: virtual-hosted `{bucket}.{host}/{key}` (typical for AWS regional endpoints). |
| Access Key ID | Scoped key for the target bucket only. |
| Secret Access Key | Submit when saving/testing; leave blank on edit to keep existing secret. |

![ShrimpSend S3 settings form](/docs/s3/common/settings-form-en.png)

## Permissions

Use a dedicated key with object read/write/delete and multipart upload actions on the target bucket only. Avoid root account keys.

## CORS

AllowedOrigins must include where users open the web app:

```text
https://shrimpsend.com
```

Add `https://www.shrimpsend.com` if needed. Origin is scheme + host + port only—no path, no trailing `/`.

## CORS reference

| Item | Recommended |
| --- | --- |
| AllowedOrigins | Actual ShrimpSend web Origin(s). |
| AllowedMethods | `GET`, `PUT`, `POST`, `DELETE`, `HEAD`. |
| AllowedHeaders | `*` or at least `content-type`, `content-md5`, `x-amz-*`, `x-amz-date`, `authorization`. |
| ExposeHeaders | At least `ETag`. |
| MaxAgeSeconds | e.g. `86400`. |

## Provider guides

- [Built-in S3](/en/docs/s3/built-in)
- [Cloudflare R2](/en/docs/s3/cloudflare-r2)
- [RustFS](/en/docs/s3/rustfs)

## Test and troubleshoot

1. CORS includes current web Origin.
2. Endpoint includes scheme.
3. Region, Bucket, and key permissions are correct.
4. Storage is reachable from your network.
5. Browser DevTools shows no CORS / 403 errors.

## Data boundary

Custom S3: bytes in your bucket. Built-in S3: platform-managed with membership quota and retention. Servers mainly presign URLs and sync metadata.
