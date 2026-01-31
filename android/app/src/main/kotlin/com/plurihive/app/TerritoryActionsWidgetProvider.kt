package com.plurihive.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TerritoryActionsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val mapIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("plurihive://map"),
        )
        val activityIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("plurihive://activity"),
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.territory_actions_widget)
            views.setOnClickPendingIntent(R.id.widget_action_map, mapIntent)
            views.setOnClickPendingIntent(R.id.widget_action_activity, activityIntent)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
