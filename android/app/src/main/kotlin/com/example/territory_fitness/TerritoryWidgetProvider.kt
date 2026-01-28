package com.example.territory_fitness

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Base64
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TerritoryWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val widgetPrefs = widgetData
        val fallbackPrefs = context.getSharedPreferences(
            FLUTTER_SHARED_PREFS,
            Context.MODE_PRIVATE,
        )

        val distance = widgetPrefs.getString(WIDGET_DISTANCE_KEY, null)
            ?: fallbackPrefs.getString("${FLUTTER_PREFIX}widget_distance_km", "--")
            ?: "--"
        val steps = widgetPrefs.getString(WIDGET_STEPS_KEY, null)
            ?: fallbackPrefs.getString("${FLUTTER_PREFIX}widget_steps", null)
            ?: fallbackPrefs.getInt("${FLUTTER_PREFIX}daily_steps", 0).toString()
        val progressText = widgetPrefs.getString(WIDGET_PROGRESS_KEY, null)
            ?: fallbackPrefs.getString("${FLUTTER_PREFIX}widget_progress", "0")
            ?: "0"
        val progress = progressText.toIntOrNull()?.coerceIn(0, 100) ?: 0
        val updatedAt = widgetPrefs.getString(WIDGET_UPDATED_AT_KEY, null)
            ?: fallbackPrefs.getString("${FLUTTER_PREFIX}widget_updated_at", null)

        val mapSnapshot =
            widgetPrefs.getString(WIDGET_MAP_SNAPSHOT_KEY, null)
                ?: fallbackPrefs.getString("${FLUTTER_PREFIX}widget_map_snapshot", null)
                ?: fallbackPrefs.getString("${FLUTTER_PREFIX}offline_map_snapshot", null)

        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            pendingFlags,
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.territory_widget)
            views.setTextViewText(R.id.widget_distance_value, "$distance km")
            views.setTextViewText(R.id.widget_steps_value, steps)
            views.setTextViewText(R.id.widget_progress_value, "$progress%")
            views.setProgressBar(R.id.widget_progress_bar, 100, progress, false)
            views.setTextViewText(
                R.id.widget_updated_at,
                updatedAt?.let { formatUpdatedText(it) } ?: "Updated recently",
            )

            val bitmap = decodeSnapshot(mapSnapshot, 420, 240)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_map, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_map, R.drawable.widget_map_placeholder)
            }

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun decodeSnapshot(base64: String?, reqWidth: Int, reqHeight: Int): Bitmap? {
        if (base64.isNullOrBlank()) return null
        return try {
            val clean = base64.substringAfter(",")
            val bytes = Base64.decode(clean, Base64.DEFAULT)
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
            options.inSampleSize = calculateInSampleSize(options, reqWidth, reqHeight)
            options.inJustDecodeBounds = false
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        } catch (_: Exception) {
            null
        }
    }

    private fun calculateInSampleSize(
        options: BitmapFactory.Options,
        reqWidth: Int,
        reqHeight: Int,
    ): Int {
        val height = options.outHeight
        val width = options.outWidth
        var inSampleSize = 1

        if (height > reqHeight || width > reqWidth) {
            var halfHeight = height / 2
            var halfWidth = width / 2

            while (halfHeight / inSampleSize >= reqHeight &&
                halfWidth / inSampleSize >= reqWidth
            ) {
                inSampleSize *= 2
                halfHeight /= 2
                halfWidth /= 2
            }
        }

        return inSampleSize
    }

    private fun formatUpdatedText(value: String): String {
        return if (value.length >= 16) {
            "Updated ${value.substring(11, 16)}"
        } else {
            "Updated recently"
        }
    }

    companion object {
        private const val FLUTTER_SHARED_PREFS = "FlutterSharedPreferences"
        private const val FLUTTER_PREFIX = "flutter."
        private const val WIDGET_DISTANCE_KEY = "widget_distance_km"
        private const val WIDGET_STEPS_KEY = "widget_steps"
        private const val WIDGET_PROGRESS_KEY = "widget_progress"
        private const val WIDGET_UPDATED_AT_KEY = "widget_updated_at"
        private const val WIDGET_MAP_SNAPSHOT_KEY = "widget_map_snapshot"
    }
}
