package app.xuezi.xuezi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
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

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hanzi_widget)
            var hanzi = ""
            if (words.length() > 0) {
                val w = words.getJSONObject((slot % words.length()).toInt())
                hanzi = w.optString("h")
                views.setTextViewText(R.id.widget_hanzi, w.optString("h"))
                views.setTextViewText(R.id.widget_pinyin, w.optString("p"))
                views.setTextViewText(R.id.widget_meaning, w.optString("m"))
            }
            // Нажатие открывает приложение сразу на этом слове.
            val uri = Uri.parse("xuezi://word?homeWidget&h=" + Uri.encode(hanzi))
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
