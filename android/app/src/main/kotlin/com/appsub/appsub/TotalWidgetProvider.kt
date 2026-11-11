package com.appsub.appsub

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Виджет «Итог»: расходы на подписки за месяц и за год. */
class TotalWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        val total = widgetData.getString("total", "") ?: ""
        val year = widgetData.getString("year", "") ?: ""
        val count = widgetData.getInt("count", 0)
        val trials = widgetData.getInt("trials", 0)

        val sub = buildString {
            if (year.isNotEmpty()) append(context.getString(R.string.widget_year, year))
            if (isNotEmpty()) append("\n")
            append(context.getString(R.string.widget_count_line, count))
            if (trials > 0) append(context.getString(R.string.widget_trials_part, trials))
        }

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_total).apply {
                setOnClickPendingIntent(R.id.widget_root, open)
                setTextViewText(R.id.total, if (total.isEmpty()) "0" else total)
                setTextViewText(R.id.sub, sub)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
