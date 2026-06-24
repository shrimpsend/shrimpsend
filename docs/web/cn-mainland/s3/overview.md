# S3 基本了解（中国大陆）

自建 S3 用于广域网文件传输。Web 端会通过浏览器向后端签发的预签名地址直传文件，因此除了 Endpoint、密钥和桶权限外，**必须正确配置桶 CORS**。

左侧导航可进入各云厂商的详细配置步骤（含控制台截图）。

## 什么时候需要 S3

- 两台设备不在同一局域网。
- 文件较大，需要稳定的广域网中转。
- 希望文件内容存放在自己的对象存储服务中。
- 局域网直连、WebRTC 或 HTTP 直连不可用。

## 设置页字段

在 **设置 → S3** 中填写以下字段：

| 字段 | 说明 |
| --- | --- |
| Endpoint | S3 API 根地址，必须包含协议，例如 `https://cos.ap-guangzhou.myqcloud.com`。 |
| Region | 桶所在地域。不同厂商命名不同，请与控制台保持一致。 |
| Bucket | 用于中转和暂存文件的桶名。 |
| Access Key ID | 建议使用只授权该桶的子账号密钥。 |
| Secret Access Key | 仅在保存或测试时提交；重新编辑时可留空以保留原密钥。 |

![虾传 S3 设置页字段说明](/docs/s3/common/settings-form-zh.png)

## 桶权限建议

建议为虾传单独创建子账号或访问密钥，并只授予目标 Bucket 所需权限：

- 上传对象（PutObject）。
- 下载对象（GetObject）。
- 删除临时对象（DeleteObject）。
- 分片上传相关权限：CreateMultipartUpload、UploadPart、ListParts、CompleteMultipartUpload、AbortMultipartUpload。

不要使用主账号密钥，也不要授予无关桶的管理权限。

## CORS 必配

浏览器会向对象存储域名发起跨域请求。桶 CORS 必须允许用户打开虾传 Web 时的 Origin。

示例：

```text
https://xiachuan.net
```

如需支持 `www` 子域，请一并添加 `https://www.xiachuan.net`。不要填写路径，也不要在末尾加 `/`。

## CORS 规则参考

| 项目 | 建议值 |
| --- | --- |
| AllowedOrigins | 虾传 Web 的实际 Origin。 |
| AllowedMethods | 至少包含 `GET`、`PUT`、`POST`、`DELETE`、`HEAD`。 |
| AllowedHeaders | 建议 `*`，或至少包含 `content-type`、`content-md5`、`x-amz-*`、`x-amz-date`、`authorization`。 |
| ExposeHeaders | 至少包含 `ETag`。 |
| MaxAgeSeconds | 可设置为 `86400`，减少预检请求。 |

## 平台详细配置

按你使用的对象存储，在左侧选择对应指南（**推荐优先使用缤纷云**）：

- [缤纷云（推荐）](/zh/docs/s3/bitiful)
- [中国科技云数据胶囊](/zh/docs/s3/data-capsule)
- [腾讯云 COS](/zh/docs/s3/tencent-cos)
- [Cloudflare R2](/zh/docs/s3/cloudflare-r2)
- [RustFS](/zh/docs/s3/rustfs)

## 测试连接

保存配置后，建议立即点击「测试连接」。如果测试失败，请按顺序检查：

1. Endpoint 是否包含协议。
2. Region 和 Bucket 是否与对象存储控制台一致。
3. 密钥是否有目标桶权限。
4. CORS 是否包含当前 Web Origin。
5. 对象存储服务是否允许公网或当前网络访问。

## 数据边界

使用自建 S3 时，文件内容会上传到你配置的对象存储。虾传服务端主要负责签发上传/下载地址、记录必要的任务元数据和同步状态。
