# iOS「文件」App 可见性

## 实现说明

用户可在 **文件 → 浏览 → 我的 iPhone** 下看到以应用显示名命名的文件夹，并浏览应用保存的接收文件。这是 iOS 沙盒 **Documents** 目录经系统暴露，不是 Android 式外部存储。

### 原生配置（方案 1）

[`app/ios/Runner/Info.plist`](../app/ios/Runner/Info.plist)：

```xml
<key>UISupportsDocumentBrowser</key>
<true/>
```

显示名由 `CFBundleDisplayName` / flavor 决定（国内 **虾传**，国际 **ShrimpSend**）。

### 应用保存路径

- 默认根目录：`getApplicationDocumentsDirectory()` + `Downloads`
- SQLite 数据库：`getApplicationSupportDirectory()` + `ultrasend.db`（不在「文件」App 中显示；桌面端同样不在用户「文档」目录中显示，避免误删）
- 解析逻辑：[`app/lib/services/receive_dir_resolver.dart`](../app/lib/services/receive_dir_resolver.dart)、[`app/lib/services/database.dart`](../app/lib/services/database.dart)
- 主入口：[`FileStore.getReceiveDir()`](../app/lib/services/file_store.dart)

在「文件」中的路径示例：

```text
我的 iPhone → {显示名} → Downloads → 文件名
```

### 回退行为

- iOS：准备目录失败或 WebRTC 尚未设置 `saveDirPath` 时，回退仍写入 **Documents/Downloads/shrimpsend**（不在 tmp）。
- 其他平台：回退仍使用应用缓存（tmp）。

### 相册与「保存后删除缓存」

若开启 **保存到相册** 且 **保存后删除缓存**，Documents 中的副本会被删除，「文件」App 中对应项也会消失。此为预期行为。

## 真机验收步骤

1. 使用 cn 或 intl flavor 安装到真机（`flutter run` 或 TestFlight）。
2. 接收一个非仅相册文件（如 PDF、ZIP），确认应用内「文件」页可见。
3. 打开系统 **文件 → 浏览 → 我的 iPhone**。
4. 确认出现以 **显示名**（虾传 / ShrimpSend）命名的文件夹。
5. 进入 **Downloads**，确认刚接收的文件可预览、分享、删除。
6. 确认 **Documents** 根目录下不再出现 `ultrasend.db`（数据库已迁至 Application Support）。
7. （可选）开启「保存到相册」+「保存后删除缓存」，接收图片后确认相册有图且 Documents 副本是否按设置消失。
8. （回归）Android 公共 Download 行为不变。

## 不要做的事

- 不要把用户可见文件写到 `tmp`、`Caches`、`Library`（除日志/更新包等内部用途）。
- 不要声称实现了 iOS「外部存储」。
- 仅改 Dart 保存路径而不配置 Info.plist，无法在「文件」中显示。
