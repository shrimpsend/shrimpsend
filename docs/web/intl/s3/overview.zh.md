# S3 基本了解（国际）

S3 是 ShrimpSend 在局域网 / WebRTC 直连不可用时的兜底传输通道。国际部署同时支持 **内置 S3** 和 **自建 S3**。

- 默认情况下，符合条件的用户可以使用平台内置对象存储，详见 [内置 S3](/zh/docs/s3/built-in)。
- 若切换为自建 S3，文件内容会上传到你配置的对象存储；左侧导航有各厂商的详细步骤（含截图）。

## 什么时候需要 S3

- 设备不在同一局域网。
- 局域网或 WebRTC 直连不可用。
- 当前网络环境不允许设备直连，但仍需要保证文件能送达。
- 你希望将文件内容放在自己控制的对象存储中。

## 设置字段

| 字段 | 说明 |
| --- | --- |
| Endpoint | S3 API 根地址，必须包含协议，例如 `https://s3.amazonaws.com`。 |
| Region | 桶所在地域，需与服务商控制台一致。 |
| Bucket | 用于文件中转和暂存的桶名。 |
| Path-style 访问 | 开启时使用 `{endpoint}/{bucket}/{key}`（MinIO 等自建网关常用）；关闭时使用虚拟托管 `{bucket}.{host}/{key}`（AWS 区域 Endpoint 常用）。 |
| Access Key ID | 建议使用只授权目标 Bucket 的访问密钥。 |
| Secret Access Key | 仅在保存或测试时提交；重新编辑时可留空保留原密钥。 |

![虾传 S3 设置页字段说明](/docs/s3/common/settings-form-zh.png)

## 权限建议

建议创建单独的访问密钥，并只授予目标 Bucket 的对象读写、删除和分片上传相关权限。不要使用主账号密钥。

## CORS 配置

浏览器直传文件时会向对象存储发起跨域请求。AllowedOrigins 必须包含用户打开 ShrimpSend Web 的实际 Origin：

```text
https://shrimpsend.com
```

如需支持 `www`，请添加 `https://www.shrimpsend.com`。Origin 只包含协议、主机和端口，不包含路径，末尾不要加 `/`。

## CORS 规则参考

| 项目 | 建议值 |
| --- | --- |
| AllowedOrigins | ShrimpSend Web 的实际 Origin。 |
| AllowedMethods | `GET`、`PUT`、`POST`、`DELETE`、`HEAD`。 |
| AllowedHeaders | 建议 `*`，或至少包含 `content-type`、`content-md5`、`x-amz-*`、`x-amz-date`、`authorization`。 |
| ExposeHeaders | 至少包含 `ETag`。 |
| MaxAgeSeconds | 可使用 `86400`。 |

## 平台详细配置

- [内置 S3（国际版）](/zh/docs/s3/built-in)
- [Cloudflare R2](/zh/docs/s3/cloudflare-r2)
- [RustFS](/zh/docs/s3/rustfs)

## 测试与排查

如果上传失败，请优先检查：

1. CORS 是否包含当前 Web Origin。
2. Endpoint 是否包含协议。
3. Region、Bucket 和密钥权限是否正确。
4. 对象存储是否允许当前网络访问。
5. 浏览器开发者工具中是否有 CORS 或 403 错误。

## 数据边界

自建 S3 时，文件内容存储在你配置的桶中；内置 S3 时，文件由平台托管并按会员额度与保留策略处理。服务端主要负责签发 URL 与同步元数据。
