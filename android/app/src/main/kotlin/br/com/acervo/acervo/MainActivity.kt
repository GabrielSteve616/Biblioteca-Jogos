package br.com.acervo.acervo

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.content.Intent
import android.content.ContentValues
import org.json.JSONArray
import org.json.JSONObject
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

/** Scoped folder grants survive app restarts; collection media is still privately owned. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var operation = ""
    private var backupPath: String? = null
    private var createFolders = false
    private val folderNames = listOf("ps1", "ps2", "ps3", "ps4", "ps5", "Steam", "android")
    private val preferences by lazy { getSharedPreferences("acervo_folders", MODE_PRIVATE) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "acervo/documents")
            .setMethodCallHandler { call, result ->
                if (call.method == "readCollectionSqlite" || call.method == "writeCollectionSqlite") {
                    val payload = call.argument<String>("data")
                    background(result) {
                        val db = openOrCreateDatabase("biblioteca.db", MODE_PRIVATE, null)
                        try {
                            db.execSQL("CREATE TABLE IF NOT EXISTS games (id TEXT PRIMARY KEY, position INTEGER NOT NULL, data TEXT NOT NULL)")
                            db.execSQL("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
                            if (call.method == "writeCollectionSqlite") {
                                val games = JSONObject(payload ?: error("Coleção vazia")).getJSONArray("games")
                                db.beginTransaction()
                                try {
                                    db.delete("games", null, null)
                                    for (i in 0 until games.length()) {
                                        val game = games.getJSONObject(i)
                                        val values = ContentValues().apply {
                                            put("id", game.getString("id"))
                                            put("position", i)
                                            put("data", game.toString())
                                        }
                                        db.insertOrThrow("games", null, values)
                                    }
                                    db.execSQL("INSERT OR REPLACE INTO metadata (key,value) VALUES ('initialized','1')")
                                    db.setTransactionSuccessful()
                                } finally { db.endTransaction() }
                                null
                            } else {
                                val initialized = db.rawQuery("SELECT value FROM metadata WHERE key='initialized'", null).use { it.moveToFirst() }
                                if (!initialized) null else {
                                    val games = JSONArray()
                                    db.rawQuery("SELECT data FROM games ORDER BY position", null).use { cursor ->
                                        while (cursor.moveToNext()) games.put(JSONObject(cursor.getString(0)))
                                    }
                                    JSONObject().put("version", 1).put("games", games).toString()
                                }
                            }
                        } finally { db.close() }
                    }
                    return@setMethodCallHandler
                }
                if (call.method in listOf("beginImportService", "updateImportService", "finishImportService")) {
                    try {
                        val service = Intent(this, ImportForegroundService::class.java).apply {
                            action = when (call.method) {
                                "beginImportService" -> "start"
                                "updateImportService" -> "update"
                                else -> "finish"
                            }
                            putExtra("done", call.argument<Int>("done") ?: 0)
                            putExtra("total", call.argument<Int>("total") ?: 0)
                            putExtra("success", call.argument<Boolean>("success") == true)
                        }
                        if (call.method == "beginImportService" && Build.VERSION.SDK_INT >= 26) startForegroundService(service)
                        else startService(service)
                        if (call.method == "beginImportService" && Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            try { requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 5502) } catch (_: Exception) { /* Import still works without a visible drawer notification. */ }
                        }
                        result.success(null)
                    } catch (error: Exception) { result.error("foreground_service", error.message, null) }
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("busy", "Já há uma seleção aberta.", null)
                    return@setMethodCallHandler
                }
                if (call.method == "scanConfiguredFolder") {
                    val tree = preferences.getString("tree", null)
                    if (tree == null) {
                        result.error("no_folder", "Escolha uma pasta de capas primeiro.", null)
                    } else {
                        val known = (call.argument<List<String>>("knownIds") ?: emptyList()).toSet()
                        background(result) { scanTree(Uri.parse(tree), known) }
                    }
                    return@setMethodCallHandler
                }
                val intent = when (call.method) {
                    "catalogFiles" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "*/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                    "catalogFolder" -> Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    "images" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "image/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, call.argument<Boolean>("multiple") == true)
                    }
                    "folder", "configureFolder" -> Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                        createFolders = call.argument<Boolean>("createFolders") == true
                        preferences.getString("tree", null)?.let {
                            putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(it))
                        }
                    }
                    "openBackup" -> Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "*/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    "saveBackup" -> Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "application/json"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_TITLE, "Biblioteca-backup.json")
                        backupPath = call.argument<String>("path")
                    }
                    else -> null
                }
                if (intent == null) {
                    result.notImplemented()
                } else {
                    pending = result
                    operation = call.method
                    try {
                        startActivityForResult(intent, 5501)
                    } catch (error: Exception) {
                        pending = null
                        backupPath = null
                        result.error("picker", error.message, null)
                    }
                }
            }
    }

    private fun background(result: MethodChannel.Result, task: () -> Any?) {
        Thread {
            try {
                val response = task()
                runOnUiThread { result.success(response) }
            } catch (error: Exception) {
                runOnUiThread { result.error("document", error.message ?: "Falha no acesso ao arquivo.", null) }
            }
        }.start()
    }

    @Deprecated("FlutterActivity document result integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 5501) return
        val callback = pending ?: return
        pending = null
        val action = operation
        if (resultCode != Activity.RESULT_OK || data?.data == null && data?.clipData == null) {
            callback.success(when(action) {
                "saveBackup" -> false
                "openBackup", "configureFolder" -> null
                else -> emptyList<String>()
            })
            backupPath = null
            return
        }
        val uri = data.data
        val payload = backupPath
        backupPath = null
        val organize = createFolders
        background(callback) {
            when (action) {
                "saveBackup" -> {
                    contentResolver.openOutputStream(uri!!, "wt")!!.use {
                        File(payload ?: error("Backup vazio")).inputStream().use { input -> input.copyTo(it) }
                    }
                    true
                }
                "openBackup" -> copyOwned(uri!!, "biblioteca-backup.json")
                "configureFolder" -> {
                    val tree = uri!!
                    val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    contentResolver.takePersistableUriPermission(tree, flags)
                    val root = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    val created = if (organize) ensurePlatformFolders(tree, root) else emptyList<String>()
                    val name = displayName(root)
                    preferences.edit().putString("tree", tree.toString()).putString("name", name).apply()
                    mapOf("name" to name, "created" to created)
                }
                "catalogFolder" -> {
                    val tree = uri!!
                    val items = children(tree, DocumentsContract.getTreeDocumentId(tree)).filter {
                        it.name.endsWith(".xlsx", true) || it.name.endsWith(".zip", true)
                    }
                    check(items.count { it.name.endsWith(".xlsx", true) } == 1 && items.count { it.name.endsWith(".zip", true) } <= 1) {
                        "Escolha uma pasta com uma planilha .xlsx e, opcionalmente, um ZIP."
                    }
                    items.map { copyOwned(DocumentsContract.buildDocumentUriUsingTree(tree, it.id), it.name, 256L * 1024 * 1024) }
                }
                "folder" -> scanTree(uri!!, emptySet()).map { it["path"]!! }
                else -> {
                    val uris = mutableListOf<Uri>()
                    data.clipData?.let { clip ->
                        for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                    }
                    if (uris.isEmpty() && uri != null) uris.add(uri)
                    if (action == "catalogFiles") {
                        check(uris.size <= 2) { "Escolha uma planilha e um ZIP por vez." }
                        uris.map { copyOwned(it, displayName(it), 256L * 1024 * 1024) }
                    } else uris.map { copyOwned(it, displayName(it)) }
                }
            }
        }
    }

    private data class Entry(val id: String, val name: String, val mime: String)
    private fun children(tree: Uri, documentId: String): List<Entry> {
        val query = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
        val result = mutableListOf<Entry>()
        val cursor = contentResolver.query(query, arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)
            ?: error("Não foi possível ler a pasta. Escolha-a novamente.")
        cursor.use {
            while (it.moveToNext()) result.add(Entry(it.getString(0), it.getString(1) ?: "", it.getString(2) ?: ""))
        }
        return result.sortedBy { it.name.lowercase(Locale.ROOT) }
    }

    private fun ensurePlatformFolders(tree: Uri, root: Uri): List<String> {
        val entries = children(tree, DocumentsContract.getTreeDocumentId(tree))
        val created = mutableListOf<String>()
        for (name in folderNames) {
            val existing = entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
            if (existing != null) {
                check(existing.mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    "Já existe um arquivo chamado $name. Escolha outra pasta para organizar suas capas."
                }
                continue
            }
            check(DocumentsContract.createDocument(contentResolver, root, DocumentsContract.Document.MIME_TYPE_DIR, name) != null) {
                "Não foi possível criar a pasta $name. Verifique se a pasta permite gravação."
            }
            created.add(name)
        }
        return created
    }

    private fun platform(name: String): String? = when (name.lowercase(Locale.ROOT)) {
        "ps1" -> "PS1"; "ps2" -> "PS2"; "ps3" -> "PS3"; "ps4" -> "PS4"; "ps5" -> "PS5"
        "steam" -> "Steam"; "android" -> "Android"; else -> null
    }

    private fun scanTree(tree: Uri, known: Set<String>): List<Map<String, String>> {
        val result = mutableListOf<Map<String, String>>()
        val rootId = DocumentsContract.getTreeDocumentId(tree)
        val root = DocumentsContract.buildDocumentUriUsingTree(tree, rootId)
        val visited = mutableSetOf<String>()
        fun walk(id: String, inherited: String?, depth: Int) {
            if (depth > 8 || !visited.add(id)) return
            for (entry in children(tree, id)) {
                val child = DocumentsContract.buildDocumentUriUsingTree(tree, entry.id)
                if (entry.mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(entry.id, platform(entry.name) ?: inherited, depth + 1)
                } else if (entry.mime.startsWith("image/") ||
                    entry.name.substringAfterLast('.', "").lowercase(Locale.ROOT) in listOf("png", "jpg", "jpeg", "webp")) {
                    if (child.toString() !in known) result.add(mapOf(
                        "path" to copyOwned(child, entry.name),
                        "name" to entry.name,
                        "platform" to (inherited ?: "PS4"),
                        "sourceId" to child.toString()))
                }
            }
        }
        walk(rootId, platform(displayName(root)), 0)
        return result
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0) ?: "Pasta de capas"
        }
        return "Pasta de capas"
    }

    private fun copyOwned(uri: Uri, name: String, maxBytes: Long = Long.MAX_VALUE): String {
        val folder = File(cacheDir, "incoming").apply { mkdirs() }
        val safe = name.replace(Regex("[^a-zA-Z0-9._ -]"), "_")
        val target = File(folder, "${System.nanoTime()}_$safe")
        try {
            contentResolver.openInputStream(uri)!!.use { input -> target.outputStream().use { output ->
                val buffer = ByteArray(65536)
                var total = 0L
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    total += count
                    check(total <= maxBytes) { "Arquivo maior que 256 MB." }
                    output.write(buffer, 0, count)
                }
            } }
        } catch (e: Exception) { target.delete(); throw e }
        return target.absolutePath
    }
}


