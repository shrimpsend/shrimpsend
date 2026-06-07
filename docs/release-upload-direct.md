# 发行包浏览器直传 部署说明

后台「版本管理」(`/admin/versions`) 把安装包改为**浏览器直传**到对象存储：

```
浏览器 → POST /api/admin/release/presign → 拿到 PUT URL
浏览器 → PUT (file) → COS / R2 桶
浏览器 → POST/PATCH /api/admin/app-versions → 写入 publicUrl
```

为此**桶必须配置 CORS**，否则浏览器 PUT 会被预检失败。

---

## 1. 桶 CORS 规则（必须）

最低字段：

- AllowedOrigin: 后台域名（按环境列出）
- AllowedMethod: `PUT, GET, HEAD`
- AllowedHeader: `*`（或至少 `Content-Type`）
- ExposeHeader: `ETag`
- MaxAgeSeconds: `3000`

### 1.1 国内：腾讯云 COS `xiachuanpub-1314690352`

控制台路径：对象存储 → 选择桶 → 安全管理 → 跨域访问 CORS 设置 → 添加规则。

```xml
<CORSRule>
  <AllowedOrigin>http://localhost:3000</AllowedOrigin>
  <AllowedOrigin>http://127.0.0.1:3000</AllowedOrigin>
  <AllowedOrigin>https://xiachuan.net</AllowedOrigin>
  <AllowedOrigin>https://www.xiachuan.net</AllowedOrigin>
  <AllowedMethod>PUT</AllowedMethod>
  <AllowedMethod>GET</AllowedMethod>
  <AllowedMethod>HEAD</AllowedMethod>
  <AllowedHeader>*</AllowedHeader>
  <ExposeHeader>ETag</ExposeHeader>
  <MaxAgeSeconds>3000</MaxAgeSeconds>
</CORSRule>
```

### 1.2 海外：Cloudflare R2 `shrimpsendpub`

控制台路径：R2 → 选择桶 `shrimpsendpub` → Settings → CORS Policy → Add CORS policy。

```json
[
  {
    "AllowedOrigins": [
      "http://localhost:3000",
      "http://127.0.0.1:3000",
      "https://shrimpsend.com",
      "https://www.shrimpsend.com"
    ],
    "AllowedMethods": ["PUT", "GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

---

## 2. R2 桶 `shrimpsendpub` 的公开访问

桶里的发行包必须能被任意客户端 GET（桌面端 `flutter_desktop_updater` 与 Android 用户都直接拉 ZIP/APK）。

### 2.1 临时方案：开启 r2.dev 公开 URL

R2 → 选择桶 → Settings → Public access → R2.dev subdomain → **Allow Access**。

得到形如 `https://pub-<hash>.r2.dev` 的根域；填到环境变量 `STORAGE_S3_PUBLIC_HOST`，覆盖 YAML 默认占位 `https://pub-shrimpsendpub.r2.dev`。

### 2.2 生产方案：自定义域名

R2 → 选择桶 → Settings → Public access → Custom Domain → 绑定 `pub.shrimpsend.com`（或其它子域）。Cloudflare 会自动签证书。

绑定完成后把 `STORAGE_S3_PUBLIC_HOST=https://pub.shrimpsend.com` 写入海外 prod 的环境变量即可，无需改代码。

---

## 3. 后端环境变量速查（海外 prod）

```bash
# 海外发行包桶（Cloudflare R2 / shrimpsendpub）
export STORAGE_S3_ENDPOINT=https://dbdc386786b268d013ed1d27545f4e4d.r2.cloudflarestorage.com
export STORAGE_S3_REGION=auto
export STORAGE_S3_ACCESS_KEY_ID=<R2 Access Key ID>
export STORAGE_S3_SECRET_ACCESS_KEY=<R2 Secret>
export STORAGE_S3_BUCKET=shrimpsendpub
export STORAGE_S3_PUBLIC_HOST=https://pub-<hash>.r2.dev   # 或自定义域名
export STORAGE_S3_PRESIGN_EXPIRE_SECONDS=1800
```

国内 prod 在 `cn/application-prod.yml` 配置 `storage.s3.*`（腾讯云 COS）；海外 prod 在 `overseas/application-prod-overseas.yml` 配置（Cloudflare R2）。详见 `docs/release-upload-direct.md`。

---

## 4. 兜底通道

如果某次部署忘了配 CORS，导致浏览器 PUT 失败：

- 后端 `/api/admin/release/upload`（multipart 中转）依然存在；前端 API 中保留了 `uploadReleaseViaServer` 函数（未导入到版本页）。
- 临时回退做法：在 `web/src/app/admin/versions/page.tsx` 的 `uploadPlatformFile` 中，把 `uploadReleaseDirect` 改回 `uploadReleaseViaServer`。
