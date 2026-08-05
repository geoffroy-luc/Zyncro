package com.zyncro.app

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Bundle
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.zyncro.app/share_shortcuts"
    private val shareCategory = "com.zyncro.app.category.SHARE_TARGET"

    /** ID du groupe choisi via un raccourci de partage direct, en attente de lecture par Dart. */
    private var pendingShortcutGroupId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pushGroupShortcuts" -> {
                        @Suppress("UNCHECKED_CAST")
                        val groups =
                            call.argument<List<Map<String, Any?>>>("groups") ?: emptyList()
                        pushShortcuts(groups)
                        result.success(null)
                    }
                    "consumeShareTargetGroupId" -> {
                        val id = pendingShortcutGroupId
                        pendingShortcutGroupId = null
                        result.success(id)
                    }
                    "clearAllShortcuts" -> {
                        ShortcutManagerCompat.removeAllDynamicShortcuts(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureShortcutId(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Garde l'intent courant à jour (le plugin de partage le lit aussi).
        setIntent(intent)
        captureShortcutId(intent)
    }

    /** Retient l'ID du raccourci (= id du groupe) quand l'app est ouverte via un partage direct. */
    private fun captureShortcutId(intent: Intent?) {
        val id = intent?.getStringExtra(ShortcutManagerCompat.EXTRA_SHORTCUT_ID)
        if (!id.isNullOrEmpty()) {
            pendingShortcutGroupId = id
        }
    }

    private fun pushShortcuts(groups: List<Map<String, Any?>>) {
        val max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(this)
        val shortcuts = groups.take(if (max > 0) max else 4).mapIndexedNotNull { index, g ->
            val id = g["id"] as? String ?: return@mapIndexedNotNull null
            val label = (g["label"] as? String)?.takeIf { it.isNotBlank() } ?: "Groupe"
            val iconBytes = g["iconPng"] as? ByteArray
            val icon = buildIcon(iconBytes, label)

            // Intent utilisé si le raccourci est lancé directement (appui long sur l'icône).
            // Pour le partage direct, le système remplace par un ACTION_SEND.
            val intent = Intent(this, MainActivity::class.java).setAction(Intent.ACTION_VIEW)

            ShortcutInfoCompat.Builder(this, id)
                .setShortLabel(label)
                .setLongLabel(label)
                .setIcon(icon)
                .setLongLived(true)
                .setRank(index)
                .setCategories(setOf(shareCategory))
                .setIntent(intent)
                .build()
        }

        ShortcutManagerCompat.removeAllDynamicShortcuts(this)
        if (shortcuts.isNotEmpty()) {
            try {
                ShortcutManagerCompat.addDynamicShortcuts(this, shortcuts)
            } catch (_: Exception) {
                // Quota dépassé ou API indisponible : on ignore silencieusement.
            }
        }
    }

    private fun buildIcon(bytes: ByteArray?, label: String): IconCompat {
        val size = 256
        val decoded = if (bytes != null && bytes.isNotEmpty()) {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } else {
            null
        }
        val bmp = if (decoded != null) squareCrop(decoded, size) else fallbackIcon(label, size)
        // Bitmap plein cadre : le lanceur / la feuille de partage le masque en rond.
        return IconCompat.createWithAdaptiveBitmap(bmp)
    }

    /** Recadre une image au centre en un carré `size` x `size`. */
    private fun squareCrop(src: Bitmap, size: Int): Bitmap {
        val side = minOf(src.width, src.height)
        val left = (src.width - side) / 2
        val top = (src.height - side) / 2
        val square = Bitmap.createBitmap(src, left, top, side, side)
        return if (square.width == size && square.height == size) {
            square
        } else {
            Bitmap.createScaledBitmap(square, size, size, true)
        }
    }

    /** Icône de secours : initiale centrée sur un fond coloré (dérivé du libellé). */
    private fun fallbackIcon(label: String, size: Int): Bitmap {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val palette = intArrayOf(
            0xFF9B59B6.toInt(), 0xFF4F7CFF.toInt(), 0xFF2BB8A5.toInt(),
            0xFFF5A855.toInt(), 0xFFE85D75.toInt(), 0xFF5D9CEC.toInt(),
        )
        val bg = palette[(label.hashCode().and(0x7FFFFFFF)) % palette.size]
        canvas.drawColor(bg)

        val letter = label.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "•"
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = size * 0.42f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val bounds = Rect()
        paint.getTextBounds(letter, 0, letter.length, bounds)
        val x = size / 2f
        val y = size / 2f - bounds.exactCenterY()
        canvas.drawText(letter, x, y, paint)
        return bmp
    }
}
