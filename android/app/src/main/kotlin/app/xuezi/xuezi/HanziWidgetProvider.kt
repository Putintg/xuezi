package app.xuezi.xuezi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Виджет «Иероглиф». Приложение сохраняет список слов (rotation) и длину слота;
 * виджет сам выбирает слово по текущему времени, поэтому оно меняется
 * даже когда приложение закрыто.
 */
class HanziWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val words = try {
            JSONArray(widgetData.getString("rotation", "[]"))
        } catch (e: Exception) {
            JSONArray()
        }
        val slotMinutes = widgetData.getInt("slotMinutes", 120).coerceAtLeast(1)
        val slot = System.currentTimeMillis() / 60000L / slotMinutes

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            context, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hanzi_widget)
            if (words.length() > 0) {
                val w = words.getJSONObject((slot % words.length()).toInt())
                views.setTextViewText(R.id.widget_hanzi, w.optString("h"))
                views.setTextViewText(R.id.widget_pinyin, w.optString("p"))
                views.setTextViewText(R.id.widget_meaning, w.optString("m"))
            }
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
