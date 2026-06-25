# 中国科技云数据胶囊

[中国科技云数据胶囊](https://data.cstcloud.cn) 提供 20GB 免费对象存储，兼容 S3 API，适合个人笔记同步、文件中转等场景。

## 适用场景

- 希望使用免费、稳定的国内 S3 兼容存储。
- 已有科技云通行证并完成实名认证（升级至 20GB 空间）。

## 获取 S3 凭证

1. 登录 [数据胶囊](https://data.cstcloud.cn)。
2. 创建**数据空间**（即 S3 Bucket）。
3. 进入该空间的 **客户端访问** 页面。
4. 点击 **创建 AccessKey**，保存 **Access Key ID** 与 **Secret Access Key**（Secret 只显示一次）。

## 创建 AccessKey（关键）

在「客户端访问」页创建 AccessKey 时，**必须**从下拉列表中选择一个客户端应用：

- S3Drive
- S3Browser
- Rclone
- Obsidian
- Cherry Studio

数据胶囊会把 AccessKey **绑定到所选应用**，后续 S3 请求的 User-Agent 必须与该应用一致，否则返回 401。

**在虾传中的操作：**

1. 在控制台创建 Key 时记下你选择的应用（例如 S3Browser）。
2. 在虾传 S3 设置的 **客户端应用** 下拉框中选择**同一项**。
3. 若 Key 是之前创建的，需确认绑定的是哪个应用，或在控制台重新创建 Key。

## 填写虾传设置

控制台可能显示以下地址之一，请**原样填写**（含 `https://`）：

- `https://s3.cstcloud.cn`（较常见）
- `https://s3.data.cstcloud.cn`（部分教程使用；若 DNS 无法解析可改用上一地址）

## 填写虾传设置

在 **设置 → S3** 中填写：

| 字段 | 说明 |
| --- | --- |
| Endpoint | 与「客户端访问」页一致，例如 `https://s3.cstcloud.cn` 或 `https://s3.data.cstcloud.cn` |
| Region | 固定填 `us-east-1` |
| Bucket | 客户端访问页显示的空间名（桶名） |
| Path-style 访问 | **必须开启** |
| 客户端应用 | **必填**，与创建 AccessKey 时选择的应用一致 |
| Access Key ID | 在客户端访问页创建的 Key |
| Secret Access Key | 对应 Secret |

## 测试连接与排错

保存后点击「测试连接」。虾传会：

1. 由服务端对你的桶执行 HeadBucket（`serverProbe`）。
2. 签发预签名 URL，由本机 HEAD 探测（验证客户端网络可达性）。

若服务端 SSL 探测失败但客户端 HEAD 成功，测试仍可通过（日志中 `serverProbe=ssl_failed` 表示服务端 TLS 校验问题，不影响客户端直连）。

若失败，请按顺序检查：

1. Endpoint 优先使用 `https://s3.cstcloud.cn`（`s3.data.cstcloud.cn` 部分环境 DNS 无法解析；不要加路径后缀）。
2. Path-style 是否**已开启**。
3. Region 是否为 `us-east-1`。
4. Bucket 名是否与「客户端访问」页一致。
5. AccessKey 是否复制完整；必要时重新创建一组 Key。
6. 查看日志中的 `serverProbe` 与 S3 响应 XML（`SignatureDoesNotMatch`、`InvalidAccessKeyId` 等）。

**常见错误：**

| 日志 / 错误 | 含义 | 处理 |
| --- | --- | --- |
| `PKIX path building failed` / `SunCertPathBuilderException` | Java 后端无法验证 CFCA 证书链（与 AccessKey 无关） | 升级至已修复版本；旧版可依赖客户端 HEAD 探测继续测试 |
| `SignatureDoesNotMatch` / HTTP 401 | 凭证或签名参数不匹配 | 核对 Endpoint、Path-style、Region、客户端应用绑定 |
| `InvalidAccessKeyId` | Access Key 错误或已删除 | 在「客户端访问」重新创建 Key |

部分 S3 兼容服务（含数据胶囊）会校验 HTTP **User-Agent**。创建 AccessKey 时选择的**客户端应用**须与虾传设置一致；客户端直连 S3 时使用对应 UA。

## CORS（Web 端）

若使用 Web 端直传，还需在数据胶囊桶配置 CORS，允许虾传 Web 的 Origin，Methods 至少包含 `GET`、`PUT`、`HEAD`。

## 相关链接

- [数据胶囊官网](https://data.cstcloud.cn)
- [科技云通行证](https://passport.escience.cn)
