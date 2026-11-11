package com.appsub.appsub

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Виджет «Список»: итог за месяц и подписки без прокрутки.
 * Сколько строк поместится, считается по высоте, которую пользователь задал
 * виджету, и пересчитывается при каждом изменении размера. Что не поместилось,
 * сворачивается в строку «и ещё N».
 */
class SubsWidgetProvider : HomeWidgetProvider() {

    private class Row(
        val initial: String,
        val name: String,
        val date: String,
        val whenText: String,
        val price: String,
        val urgent: Boolean,
        val trial: Boolean,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it, widgetData) }
    }

    // Пользователь растянул или сжал виджет: пересобираем строки под новый размер.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        awm: AppWidgetManager,
        id: Int,
        data: SharedPreferences,
    ) {
        val all = parse(data.getString("subs_json", "[]") ?: "[]")
        val total = data.getString("total", "") ?: ""
        val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

        // Лаунчер сообщает размер «наоборот»: в портрете высота виджета лежит в
        // MAX_HEIGHT, в ландшафте в MIN_HEIGHT.
        val landscape =
            context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val heightDp = awm.getAppWidgetOptions(id).getInt(
            if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
            else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT,
            DEFAULT_HEIGHT,
        )

        val capacity = ((heightDp - HEADER) / ROW).coerceAtLeast(0)
        var shown = minOf(capacity, all.size)
        var hidden = all.size - shown
        if (hidden > 0) {
            // Не всё помещается: оставляем место под строку «и ещё N».
            val withMore = ((heightDp - HEADER - MORE) / ROW).coerceAtLeast(0)
            shown = minOf(if (capacity >= 1) maxOf(withMore, 1) else 0, all.size)
            hidden = all.size - shown
        }

        val views = RemoteViews(context.packageName, R.layout.widget_subs).apply {
            setOnClickPendingIntent(R.id.widget_root, open)
            setOnClickPendingIntent(R.id.header, open)
            setTextViewText(R.id.total, if (total.isEmpty()) "0" else total)
            setTextViewText(
                R.id.count_pill,
                context.resources.getQuantityString(R.plurals.widget_subscriptions, all.size, all.size),
            )

            removeAllViews(R.id.rows)
            for (i in 0 until shown) {
                addView(R.id.rows, buildRow(context, all[i], i, open))
            }
            setViewVisibility(R.id.empty, if (all.isEmpty()) View.VISIBLE else View.GONE)
            setViewVisibility(R.id.more, if (hidden > 0) View.VISIBLE else View.GONE)
            if (hidden > 0) {
                setTextViewText(R.id.more, context.getString(R.string.widget_more, hidden))
            }
        }
        awm.updateAppWidget(id, views)
    }

    private fun buildRow(context: Context, r: Row, index: Int, open: PendingIntent): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_item)
        v.setTextViewText(R.id.avatar, r.initial)
        v.setTextViewText(R.id.name, r.name)
        v.setTextViewText(R.id.date_text, r.date)
        v.setTextViewText(R.id.price, r.price)
        v.setTextViewText(R.id.when_text, r.whenText)

        // Аватарки чередуют форму и цвет: так список выглядит живее.
        val (bg, fg) = when (index % 4) {
            0 -> R.drawable.widget_avatar_bg to R.color.widget_on_tertiary_c
            1 -> R.drawable.widget_avatar_trial_bg to R.color.widget_on_secondary_c
            2 -> R.drawable.widget_avatar_primary_bg to R.color.widget_on_primary_c
            else -> R.drawable.widget_avatar_tertiary_sq_bg to R.color.widget_on_tertiary_c
        }
        v.setInt(R.id.avatar, "setBackgroundResource", bg)
        v.setTextColor(R.id.avatar, context.getColor(fg))

        // Чип срока: обычный, срочный (красный) или пробный период (розовый).
        val (pillBg, pillFg) = when {
            r.urgent -> R.drawable.widget_item_urgent_bg to R.color.widget_on_error_c
            r.trial -> R.drawable.widget_pill_tertiary_bg to R.color.widget_on_tertiary_c
            else -> R.drawable.widget_pill_secondary_bg to R.color.widget_on_secondary_c
        }
        v.setInt(R.id.when_text, "setBackgroundResource", pillBg)
        v.setTextColor(R.id.when_text, context.getColor(pillFg))

        v.setOnClickPendingIntent(R.id.item_root, open)
        return v
    }

    private fun parse(json: String): List<Row> = try {
        val arr = JSONArray(json)
        List(arr.length()) { i ->
            val o = arr.getJSONObject(i)
            Row(
                initial = o.optString("i", "?"),
                name = o.optString("n"),
                date = o.optString("d"),
                whenText = o.optString("w"),
                price = o.optString("p"),
                urgent = o.optBoolean("u"),
                trial = o.optBoolean("t"),
            )
        }
    } catch (e: Exception) {
        emptyList()
    }

    private companion object {
        // Размеры в dp: шапка с отступами, строка с зазором, строка «и ещё N».
        const val HEADER = 92
        const val ROW = 62
        const val MORE = 18
        const val DEFAULT_HEIGHT = 180
    }
}
