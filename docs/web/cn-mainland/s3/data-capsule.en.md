# CSTCloud Data Capsule

[CSTCloud Data Capsule](https://data.cstcloud.cn) offers 20 GB of free object storage with an S3-compatible API.

## Get S3 credentials

1. Sign in at [data.cstcloud.cn](https://data.cstcloud.cn).
2. Create a **data space** (your S3 bucket).
3. Open **Client access** for that space.
4. Create an **AccessKey** and save the **Access Key ID** and **Secret Access Key** (the secret is shown only once).

## ShrimpSend settings

| Field | Value |
| --- | --- |
| Endpoint | `https://s3.data.cstcloud.cn` (include `https://`) |
| Region | `us-east-1` |
| Bucket | Space name from Client access |
| Path-style access | **On (required)** |
| Access Key ID / Secret | From Client access |

## Test connection

After saving, use **Test connection**. ShrimpSend runs a server-side HeadBucket probe and a client-side HEAD on a presigned URL.

If it fails, verify endpoint, path-style, region, bucket name, and keys. Check logs for `serverProbe` and S3 XML error codes.

Some providers (including Data Capsule) validate **User-Agent**. ShrimpSend sets `ShrimpSend/1.0 S3Compat` on direct S3 requests.

## WebDAV (remote storage)

Data Capsule also offers WebDAV at `https://data.cstcloud.cn/dav`. Create WebDAV credentials in the console, then add a connection under **Settings → WebDAV** in ShrimpSend.

WebDAV uses the same `*.cstcloud.cn` hosts and CFCA certificate chain as S3. Backend connection tests need the same supplemental trust; upgraded servers handle this automatically.

The console only supports **Zotero (8+)** for WebDAV credentials. ShrimpSend sends the matching Zotero User-Agent automatically; use the WebDAV username and password from the console (not your login password).

## CORS (Web)

For browser uploads, configure bucket CORS to allow your ShrimpSend Web origin with at least `GET`, `PUT`, and `HEAD`.

## Links

- [Data Capsule](https://data.cstcloud.cn)
- [CSTCloud passport](https://passport.escience.cn)
