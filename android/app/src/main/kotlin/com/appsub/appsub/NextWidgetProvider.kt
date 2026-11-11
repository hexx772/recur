package com.appsub.appsub

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Виджет «Ближайшее»: одно ближайшее списание крупно. */
class NextWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        val name = widgetData.getString("next_name", "") ?: ""
        val has = name.isNotEmpty()
        val urgent = widgetData.getBoolean("next_urgent", false)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_next).apply {
                setOnClickPendingIntent(R.id.widget_root, open)
                val vis = if (has) View.VISIBLE else View.GONE
                setViewVisibility(R.id.next_name, vis)
                setViewVisibility(R.id.next_date, vis)
                setViewVisibility(R.id.next_price, vis)
                setViewVisibility(R.id.next_when, vis)
                setViewVisibility(R.id.next_empty, if (has) View.GONE else View.VISIBLE)
                if (has) {
                    setTextViewText(R.id.next_name, name)
                    setTextViewText(R.id.next_date, widgetData.getString("next_date", "") ?: "")
                    setTextViewText(R.id.next_price, widgetData.getString("next_price", "") ?: "")
                    setTextViewText(R.id.next_when, widgetData.getString("next_when", "") ?: "")
                    // Срочное списание подсвечиваем цветом ошибки.
                    if (urgent) {
                        setInt(R.id.next_when, "setBackgroundResource", R.drawable.widget_item_urgent_bg)
                        setTextColor(R.id.next_when, context.getColor(R.color.widget_on_error_c))
                    } else {
                        setInt(R.id.next_when, "setBackgroundResource", R.drawable.widget_pill_primary_bg)
                        setTextColor(R.id.next_when, context.getColor(R.color.widget_on_primary_c))
                    }
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
