package com.example.monivo

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.util.Log
import android.util.SizeF
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

/**
 * Home-screen widget: Today's Safe Spending for the active budget.
 *
 * The Dart side ([HomeWidgetService]) works out and formats everything and
 * stores it as one payload ([WidgetPayload]); this provider only decides
 * what to show and paints it:
 *
 * - **Size.** It offers the launcher one layout per size class, each keyed
 *   by the room its content needs at the current font and display size
 *   ([WidgetRenderer.sizedLayouts]). Android 12+ switches between them as
 *   the widget is resized; older versions get the best fit for the reported
 *   portrait and landscape sizes, redrawn on every resize.
 * - **Freshness.** The figures are for one day. Once the day turns, the
 *   widget asks to be opened instead of showing yesterday's amount as
 *   today's; one inexact, non-waking alarm a day redraws it after midnight.
 * - **Taps.** The widget opens Home; its button opens Add expense.
 */
class HomeScreenWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "MonivoWidget"
        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"
        private const val ACTION_DAY_CHANGED = "com.example.monivo.widget.DAY_CHANGED"
        private const val ACTION_FORCE_UPDATE = "com.sufiyan.monivo.FORCE_WIDGET_UPDATE"

        /** RemoteViews accepts at most 16 sized layouts. */
        private const val MAX_LAYOUTS = 16

        /**
         * Measuring the layouts takes a few hundred milliseconds, so widgets
         * are drawn on their own thread rather than the app's main thread,
         * which also handles touches while Monivo is open. One thread, so
         * redraws happen in order.
         */
        private val worker: Handler by lazy {
            Handler(HandlerThread("MonivoWidget").apply { start() }.looper)
        }

        /** Draws [ids] (default: every placed Monivo widget) off the main thread. */
        private fun drawAsync(
            receiver: BroadcastReceiver,
            context: Context,
            ids: IntArray? = null,
        ) {
            val pending = receiver.goAsync()
            val app = context.applicationContext
            worker.post {
                try {
                    val manager = AppWidgetManager.getInstance(app)
                    val targets = ids ?: manager.getAppWidgetIds(
                        ComponentName(app, HomeScreenWidgetProvider::class.java),
                    )
                    if (targets.isNotEmpty()) render(app, manager, targets)
                } finally {
                    pending.finish()
                }
            }
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val started = SystemClock.elapsedRealtime()
            val prefs = prefs(context)
            val payload = WidgetPayload.read(prefs)
            val content = payload?.contentFor(WidgetPayload.today()) ?: WidgetMessage(
                title = context.getString(R.string.widget_setup_title),
                body = context.getString(R.string.widget_setup_body),
            )
            val light = payload?.light ?: WidgetColors.defaults(context, night = false)
            val dark = payload?.dark ?: WidgetColors.defaults(context, night = true)

            for (id in ids) {
                try {
                    val renderer = WidgetRenderer(
                        context,
                        light,
                        dark,
                        openApp = launchIntent(context, "monivo:///app/home", id * 10),
                        addExpense = launchIntent(context, "monivo:///app/expenses/add", id * 10 + 1),
                    )
                    val layouts = renderer.sizedLayouts(content)
                    manager.updateAppWidget(id, views(manager, id, renderer, content, layouts))
                } catch (e: Exception) {
                    Log.e(TAG, "Couldn't draw widget $id", e)
                }
            }
            scheduleDayChange(context)
            Log.d(TAG, "Drew ${ids.size} widget(s) in ${SystemClock.elapsedRealtime() - started} ms")
        }

        private fun views(
            manager: AppWidgetManager,
            id: Int,
            renderer: WidgetRenderer,
            content: WidgetContent,
            layouts: List<SizedLayout>,
        ): RemoteViews {
            val options = manager.getAppWidgetOptions(id)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Each layout keyed by the room it needs: Android picks among
                // these as the widget is resized...
                val bySize = LinkedHashMap<SizeF, RemoteViews>()
                for (layout in layouts) bySize[layout.size] = layout.views
                // ...and each size the launcher says the widget has gets the
                // richest layout that fits it exactly (Android's own pick
                // favours the closest size, not the richest content).
                for (size in options.sizes()) {
                    if (bySize.size >= MAX_LAYOUTS && size !in bySize) break
                    val layout = WidgetRenderer.choose(layouts, size).layout
                    Log.d(TAG, "Widget $id at $size: $layout")
                    bySize[size] = renderer.build(layout, content)
                }
                return RemoteViews(bySize)
            }
            // Before Android 12 the launcher reports the widget's size range:
            // narrowest and tallest in portrait, widest and shortest in landscape.
            // Until the launcher reports them, assume the default 4 x 2 size.
            val minWidth = options.dp(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250f)
            val maxWidth = options.dp(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth)
            val minHeight = options.dp(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110f)
            val maxHeight = options.dp(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight)
            val portrait = WidgetRenderer.choose(layouts, SizeF(minWidth, maxHeight)).views
            val landscape = WidgetRenderer.choose(layouts, SizeF(maxWidth, minHeight)).views
            return if (portrait === landscape) portrait else RemoteViews(landscape, portrait)
        }

        /** The sizes (dp) the launcher reports for the widget (Android 12+). */
        @RequiresApi(Build.VERSION_CODES.S)
        private fun Bundle.sizes(): List<SizeF> {
            val sizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES, SizeF::class.java)
            } else {
                @Suppress("DEPRECATION")
                getParcelableArrayList(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            }
            return sizes.orEmpty().filter { it.width > 0 && it.height > 0 }
        }

        private fun Bundle.dp(key: String, fallback: Float): Float =
            getInt(key, 0).takeIf { it > 0 }?.toFloat() ?: fallback

        private fun launchIntent(context: Context, uri: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data = Uri.parse(uri)
                putExtra("es.antonborri.home_widget.initiallyLaunchedFromHomeWidget", uri)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            return if (Build.VERSION.SDK_INT >= 35) {
                val options = android.app.ActivityOptions.makeBasic()
                    .setPendingIntentCreatorBackgroundActivityStartMode(1)
                PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
            } else if (Build.VERSION.SDK_INT >= 34) {
                val options = android.app.ActivityOptions.makeBasic()
                    .setPendingIntentBackgroundActivityStartMode(1)
                PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
            } else {
                PendingIntent.getActivity(context, requestCode, intent, flags)
            }
        }

        /**
         * Redraws the widgets just after the next midnight, so yesterday's
         * amount is never shown as today's. Inexact and non-waking: it fires
         * when the device is next awake, which is when the widget is seen.
         */
        private fun scheduleDayChange(context: Context) {
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val nextDay = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }
            alarms.set(AlarmManager.RTC, nextDay.timeInMillis, dayChangeIntent(context))
        }

        private fun dayChangeIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, HomeScreenWidgetProvider::class.java).setAction(ACTION_DAY_CHANGED),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun prefs(context: Context): SharedPreferences = try {
            HomeWidgetPlugin.getData(context)
        } catch (e: Exception) {
            context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        drawAsync(this, context, appWidgetIds)
    }

    /** Resized: redraw, so the layouts are measured for the current font size too. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        drawAsync(this, context, intArrayOf(appWidgetId))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_DAY_CHANGED,
            ACTION_FORCE_UPDATE,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> drawAsync(this, context)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        context.getSystemService(AlarmManager::class.java)?.cancel(dayChangeIntent(context))
    }
}
