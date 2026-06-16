package dev.ultrasend.app

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.os.Build
import android.provider.BaseColumns
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.attribute.FileTime
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SHARE_TAG = "ShareMainAct"
        private const val SAVE_AS_REQUEST_CODE = 44001
    }

    private lateinit var safStorageHandler: SafStorageHandler
    private lateinit var shareIntentBridge: ShareIntentBridge
    private var pendingSaveAsResult: MethodChannel.Result? = null
    private var pendingSaveAsSourcePath: String? = null
    private var pendingInstallApkPath: String? = null

    override fun onResume() {
        super.onResume()
        tryResumePendingApkInstall()
    }

    override fun onNewIntent(intent: Intent) {
        logShareIntent("onNewIntent", intent)
        super.onNewIntent(intent)
        setIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == SAVE_AS_REQUEST_CODE) {
            val channelResult = pendingSaveAsResult
            val sourcePath = pendingSaveAsSourcePath
            pendingSaveAsResult = null
            pendingSaveAsSourcePath = null
            if (channelResult != null) {
                if (resultCode == RESULT_OK && data?.data != null && sourcePath != null) {
                    try {
                        val destUri = data.data!!
                        copyToContentUri(sourcePath, destUri.toString())
                        channelResult.success(destUri.toString())
                    } catch (e: Exception) {
                        channelResult.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    channelResult.success(null)
                }
                return
            }
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        intent?.let { logShareIntent("configureFlutterEngine", it) }
        super.configureFlutterEngine(flutterEngine)

        safStorageHandler = SafStorageHandler(this)
        safStorageHandler.registerChannel(flutterEngine.dartExecutor.binaryMessenger)
        shareIntentBridge = ShareIntentBridge(this)
        shareIntentBridge.register(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.ultrasend/file_times")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "applyReceived" -> {
                        val path = call.argument<String>("path")
                        val modifiedMs = call.argument<Number>("modifiedMs")?.toLong()
                        val createdMs = call.argument<Number>("createdMs")?.toLong()
                        if (path == null || modifiedMs == null || createdMs == null) {
                            result.error("INVALID_ARG", "path/modifiedMs/createdMs required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val file = Paths.get(path)
                            Files.setAttribute(
                                file,
                                "basic:lastModifiedTime",
                                FileTime.fromMillis(modifiedMs)
                            )
                            Files.setAttribute(
                                file,
                                "basic:creationTime",
                                FileTime.fromMillis(createdMs)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SET_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.ultrasend/apk")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getApkPath" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName == null) {
                            result.error("INVALID_ARG", "packageName is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val appInfo = packageManager.getApplicationInfo(packageName, 0)
                            result.success(appInfo.sourceDir)
                        } catch (e: Exception) {
                            result.error("NOT_FOUND", "App not found: ${e.message}", null)
                        }
                    }
                    "installApk" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath == null) {
                            result.error("INVALID_ARG", "filePath is required", null)
                            return@setMethodCallHandler
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            !packageManager.canRequestPackageInstalls()
                        ) {
                            pendingInstallApkPath = filePath
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${applicationContext.packageName}")
                            )
                            startActivity(intent)
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        try {
                            launchInstallIntent(filePath)
                            pendingInstallApkPath = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", "安装失败: ${e.message}", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.ultrasend/file_export")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName")
                        if (path == null || fileName == null) {
                            result.error("INVALID_ARG", "path/fileName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(saveToDownloads(path, fileName))
                        } catch (e: Exception) {
                            result.error("SAVE_FAILED", e.message, null)
                        }
                    }
                    "listDownloads" -> {
                        try {
                            result.success(listDownloads())
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            result.error("LIST_FAILED", e.message, null)
                        }
                    }
                    "copyToContentUri" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val destUri = call.argument<String>("destUri")
                        if (sourcePath == null || destUri == null) {
                            result.error("INVALID_ARG", "sourcePath/destUri required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            copyToContentUri(sourcePath, destUri)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("COPY_FAILED", e.message, null)
                        }
                    }
                    "saveFileAsStream" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val fileName = call.argument<String>("fileName")
                        if (sourcePath == null || fileName == null) {
                            result.error("INVALID_ARG", "sourcePath/fileName required", null)
                            return@setMethodCallHandler
                        }
                        if (pendingSaveAsResult != null) {
                            result.error("ALREADY_ACTIVE", "Save dialog already active", null)
                            return@setMethodCallHandler
                        }
                        val source = File(sourcePath)
                        if (!source.isFile) {
                            result.error("INVALID_ARG", "File not found: $sourcePath", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            putExtra(Intent.EXTRA_TITLE, sanitizeFileName(fileName))
                            type = mimeTypeForName(fileName)
                        }
                        if (intent.resolveActivity(packageManager) == null) {
                            result.error("NO_HANDLER", "No app to handle save dialog", null)
                            return@setMethodCallHandler
                        }
                        pendingSaveAsResult = result
                        pendingSaveAsSourcePath = sourcePath
                        startActivityForResult(intent, SAVE_AS_REQUEST_CODE)
                    }
                    "deleteDownload" -> {
                        val uri = call.argument<String>("uri")
                        val path = call.argument<String>("path")
                        if (uri.isNullOrEmpty() && path.isNullOrEmpty()) {
                            result.error("INVALID_ARG", "uri or path required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(deleteDownload(uri, path))
                        } catch (e: SecurityException) {
                            result.error("PERMISSION_DENIED", e.message, null)
                        } catch (e: Exception) {
                            result.error("DELETE_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Deletes a public Downloads entry. MediaStore content URIs are removed via
    /// ContentResolver (DocumentFile.delete fails for MediaStore items), while
    /// legacy file paths use a plain File.delete().
    private fun deleteDownload(uri: String?, path: String?): Boolean {
        if (!uri.isNullOrEmpty() && uri.startsWith("content://")) {
            val resolver = applicationContext.contentResolver
            val deleted = resolver.delete(Uri.parse(uri), null, null)
            return deleted > 0
        }
        val target = when {
            !path.isNullOrEmpty() -> File(path)
            !uri.isNullOrEmpty() && uri.startsWith("file://") ->
                File(Uri.parse(uri).path ?: return false)
            else -> return false
        }
        return if (target.exists()) target.delete() else true
    }

    private fun tryResumePendingApkInstall() {
        val filePath = pendingInstallApkPath ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            return
        }
        pendingInstallApkPath = null
        try {
            launchInstallIntent(filePath)
        } catch (e: Exception) {
            Log.w(SHARE_TAG, "tryResumePendingApkInstall failed: ${e.message}", e)
        }
    }

    private fun launchInstallIntent(filePath: String) {
        val file = File(filePath)
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun listDownloads(): List<Map<String, Any?>> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            listDownloadsMediaStore()
        } else {
            listDownloadsLegacy()
        }
    }

    private fun listDownloadsMediaStore(): List<Map<String, Any?>> {
        val resolver = applicationContext.contentResolver
        val downloadDir = Environment.DIRECTORY_DOWNLOADS
        val topLevelPaths = setOf(downloadDir, "$downloadDir/")
        val projection = arrayOf(
            BaseColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.RELATIVE_PATH,
            MediaStore.MediaColumns.IS_PENDING,
        )
        val sort = "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"
        val out = mutableListOf<Map<String, Any?>>()
        val cursor = resolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            null,
            null,
            sort,
        ) ?: throw IllegalStateException("Could not query Downloads")
        cursor.use {
            val idCol = it.getColumnIndexOrThrow(BaseColumns._ID)
            val nameCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val sizeCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
            val modCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)
            val pathCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.RELATIVE_PATH)
            val pendingCol = it.getColumnIndexOrThrow(MediaStore.MediaColumns.IS_PENDING)
            while (it.moveToNext()) {
                if (it.getInt(pendingCol) == 1) continue
                val relativePath = it.getString(pathCol)?.trim() ?: continue
                if (relativePath !in topLevelPaths) continue
                val name = it.getString(nameCol)?.trim().orEmpty()
                if (name.isEmpty() || name.startsWith(".")) continue
                val id = it.getLong(idCol)
                val uri = ContentUris.withAppendedId(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    id,
                )
                out.add(
                    mapOf(
                        "name" to name,
                        "uri" to uri.toString(),
                        "size" to it.getLong(sizeCol),
                        "lastModified" to it.getLong(modCol) * 1000L,
                    ),
                )
            }
        }
        return out
    }

    private fun listDownloadsLegacy(): List<Map<String, Any?>> {
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        if (!downloads.exists()) {
            throw IllegalStateException("Downloads directory does not exist")
        }
        if (!downloads.isDirectory) {
            throw IllegalStateException("Downloads path is not a directory")
        }
        val files = downloads.listFiles()?.filter { it.isFile } ?: emptyList()
        return files.mapNotNull { file ->
            val name = file.name?.trim().orEmpty()
            if (name.isEmpty() || name.startsWith(".")) return@mapNotNull null
            mapOf(
                "name" to name,
                "uri" to Uri.fromFile(file).toString(),
                "path" to file.absolutePath,
                "size" to file.length(),
                "lastModified" to file.lastModified(),
            )
        }
    }

    private fun saveToDownloads(path: String, fileName: String): Map<String, String?> {
        val source = File(path)
        if (!source.isFile) {
            throw IllegalArgumentException("File not found: $path")
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveToDownloadsMediaStore(source, fileName)
        } else {
            saveToDownloadsLegacy(source, fileName)
        }
    }

    private fun saveToDownloadsMediaStore(
        source: File,
        fileName: String
    ): Map<String, String?> {
        val resolver = applicationContext.contentResolver
        val displayName = uniqueFileName(sanitizeFileName(fileName)) { candidate ->
            resolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                arrayOf(BaseColumns._ID),
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                arrayOf(candidate, "${Environment.DIRECTORY_DOWNLOADS}/"),
                null
            )?.use { cursor -> cursor.moveToFirst() } ?: false
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeTypeForName(displayName))
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Could not create Downloads item")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not open output stream")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return mapOf(
                "displayName" to displayName,
                "uri" to uri.toString(),
                "path" to null,
            )
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }

    private fun saveToDownloadsLegacy(
        source: File,
        fileName: String
    ): Map<String, String?> {
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )
        if (!downloads.exists() && !downloads.mkdirs()) {
            throw IllegalStateException("Could not open Downloads directory")
        }
        val displayName = uniqueFileName(sanitizeFileName(fileName)) { candidate ->
            File(downloads, candidate).exists()
        }
        val target = File(downloads, displayName)
        FileInputStream(source).use { input ->
            FileOutputStream(target).use { output -> input.copyTo(output) }
        }
        return mapOf(
            "displayName" to displayName,
            "uri" to Uri.fromFile(target).toString(),
            "path" to target.absolutePath,
        )
    }

    private fun copyToContentUri(sourcePath: String, destUri: String) {
        val source = File(sourcePath)
        if (!source.isFile) {
            throw IllegalArgumentException("File not found: $sourcePath")
        }
        val uri = Uri.parse(destUri)
        applicationContext.contentResolver.openOutputStream(uri)?.use { output ->
            FileInputStream(source).use { input -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not open output stream for $destUri")
    }

    private fun sanitizeFileName(fileName: String): String {
        val cleaned = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_").trim()
        return cleaned.ifEmpty { "received" }
    }

    private fun uniqueFileName(baseName: String, exists: (String) -> Boolean): String {
        if (!exists(baseName)) return baseName
        val dotIndex = baseName.lastIndexOf('.')
        val hasExtension = dotIndex > 0 && dotIndex < baseName.length - 1
        val stem = if (hasExtension) baseName.substring(0, dotIndex) else baseName
        val extension = if (hasExtension) baseName.substring(dotIndex) else ""
        for (i in 1..9999) {
            val candidate = "$stem ($i)$extension"
            if (!exists(candidate)) return candidate
        }
        return "$stem ${System.currentTimeMillis()}$extension"
    }

    private fun mimeTypeForName(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "")
            .lowercase(Locale.ROOT)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun logShareIntent(source: String, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) {
            return
        }
        val clipUris = mutableListOf<Uri>()
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { clipUris.add(it) }
            }
        }
        Log.i(
            SHARE_TAG,
            "$source action=$action type=${intent.type} data=${intent.data} " +
                "scheme=${intent.data?.scheme} authority=${intent.data?.authority} " +
                "flags=0x${Integer.toHexString(intent.flags)} clipItems=${clipUris.size} " +
                "extras=${intent.extras?.keySet()?.toList()}",
        )
        if (clipUris.isNotEmpty()) {
            Log.i(SHARE_TAG, "$source clipData uris=$clipUris")
        }
    }
}
