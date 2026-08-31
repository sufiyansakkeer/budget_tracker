package com.example.monivo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Locale

/**
 * Home-screen widget that displays Today's Safe Spending and related
 * budget data computed by the Dart side.
 *
 * Data is written to SharedPreferences by the Dart [HomeWidgetService]
 * using the `home_widget` package. This provider reads those values
 * and updates the RemoteViews accordingly.
 *
 * The widget also provides quick-action buttons to launch the app
 * directly into the Dashboard or the Add Expense screen.
 */
class HomeScreenWidgetProvider : AppWidgetProvider() {

    init {
        Log.d(TAG, "HomeScreenWidgetProvider instantiated")
    }

    companion object {
        private const val TAG = "MonivoWidget"
        // Must match the keys in Dart's WidgetDataKeys
        private const val KEY_DAILY_SAFE = "home_widget_daily_safe"
        private const val KEY_SPENT_TODAY = "home_widget_spent_today"
        private const val KEY_STATUS = "home_widget_status"
        private const val KEY_REMAINING = "home_widget_remaining"
        private const val KEY_REMAINING_DAYS = "home_widget_remaining_days"
        private const val KEY_CURRENCY = "home_widget_currency"
        private const val KEY_LAST_UPDATED = "home_widget_last_updated"
        private const val KEY_HAS_BUDGET = "home_widget_has_budget"
        private const val KEY_QUICK_ACTION = "home_widget_quick_action"

        private const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, HomeScreenWidgetProvider::class.java)
            )
            for (id in ids) {
                val intent = Intent(context, HomeScreenWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id))
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widget(s)")
        try {
            val prefs = getPrefs(context)

            for (appWidgetId in appWidgetIds) {
                try {
                    Log.d(TAG, "Rendering widget id=$appWidgetId")
                    val views = RemoteViews(context.packageName, R.layout.widget_spending_view)

                    val hasBudgetStr = getStringSafe(prefs, KEY_HAS_BUDGET, "false")
                    val hasBudget = hasBudgetStr == "true"
                    Log.d(TAG, "hasBudget=$hasBudget")

                    if (!hasBudget) {
                        renderEmptyState(views, context)
                    } else {
                        renderSpendingData(views, prefs, context)
                    }

                    // ── Quick Action: tap body opens Dashboard ──────────────────
                    val openAppPendingIntent = createLaunchPendingIntent(
                        context,
                        Uri.parse("monivo:///app/home"),
                        appWidgetId * 10,
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)

                    // ── Quick Action: Add Expense button opens Expense Form ─────
                    val addExpensePendingIntent = createLaunchPendingIntent(
                        context,
                        Uri.parse("monivo:///app/expenses/add"),
                        appWidgetId * 10 + 1,
                    )
                    views.setOnClickPendingIntent(R.id.widget_add_expense_button, addExpensePendingIntent)


                    appWidgetManager.updateAppWidget(appWidgetId, views)
                    Log.d(TAG, "Widget id=$appWidgetId updated successfully")
                } catch (innerEx: Exception) {
                    Log.e(TAG, "Error updating single widget id=$appWidgetId: ${innerEx.message}", innerEx)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "ERROR in onUpdate: ${e.javaClass.simpleName}: ${e.message}", e)
        }
    }

    private fun createLaunchPendingIntent(
        context: Context,
        uri: Uri,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "es.antonborri.home_widget.action.LAUNCH"
            data = uri
            putExtra("es.antonborri.home_widget.initiallyLaunchedFromHomeWidget", uri.toString())
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (android.os.Build.VERSION.SDK_INT >= 35) {
            val options = android.app.ActivityOptions.makeBasic().setPendingIntentCreatorBackgroundActivityStartMode(1)
            PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
        } else if (android.os.Build.VERSION.SDK_INT >= 34) {
            val options = android.app.ActivityOptions.makeBasic().setPendingIntentBackgroundActivityStartMode(1)
            PendingIntent.getActivity(context, requestCode, intent, flags, options.toBundle())
        } else {
            PendingIntent.getActivity(context, requestCode, intent, flags)
        }
    }


    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "onEnabled called — first widget placed")
        HomeWidgetServiceWrapper.updateWidgetData(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive action=${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == "com.sufiyan.monivo.FORCE_WIDGET_UPDATE") {
            HomeWidgetServiceWrapper.updateWidgetData(context)
        }
    }

    private fun renderSpendingData(
        views: RemoteViews,
        prefs: SharedPreferences,
        context: Context,
    ) {
        val dailySafeRaw = getStringSafe(prefs, KEY_DAILY_SAFE, "0")
        val spentTodayRaw = getStringSafe(prefs, KEY_SPENT_TODAY, "0")
        val status = getStringSafe(prefs, KEY_STATUS, "on_track")
        val remainingRaw = getStringSafe(prefs, KEY_REMAINING, "0")
        val remainingDaysRaw = getStringSafe(prefs, KEY_REMAINING_DAYS, "0")
        val currency = getStringSafe(prefs, KEY_CURRENCY, "INR")

        val dailySafe = dailySafeRaw.toDoubleOrNull() ?: 0.0
        val spentToday = spentTodayRaw.toDoubleOrNull() ?: 0.0
        val remaining = remainingRaw.toDoubleOrNull() ?: 0.0
        val remainingDays = remainingDaysRaw.toIntOrNull() ?: 0

        val symbol = getCurrencySymbol(currency)

        // ── Safe Spending amount ────────────────────────────────────────
        views.setTextViewText(
            R.id.widget_safe_spending_amount,
            formatCurrency(dailySafe, symbol),
        )

        // ── Spent Today ─────────────────────────────────────────────────
        views.setTextViewText(
            R.id.widget_spent_today_amount,
            formatCurrency(spentToday, symbol),
        )

        // ── Status label ────────────────────────────────────────────────
        val statusLabel = when {
            status.startsWith("over:") -> {
                val overAmount = status.removePrefix("over:").toDoubleOrNull() ?: 0.0
                "${formatCurrency(overAmount, symbol)} over"
            }
            status == "on_track" -> "On Track"
            status == "no_budget" -> "No Budget"
            status == "error" -> "Open app to refresh"
            else -> "On Track"
        }
        views.setTextViewText(R.id.widget_status, statusLabel)

        // ── Status color ────────────────────────────────────────────────
        val statusColor = when {
            status.startsWith("over:") -> 0xFFD32F2F.toInt()  // Red
            status == "on_track" -> 0xFF388E3C.toInt()        // Green
            else -> 0xFF757575.toInt()                         // Grey
        }
        views.setTextColor(R.id.widget_status, statusColor)
        views.setTextColor(R.id.widget_safe_spending_amount, statusColor)

        // ── Add Expense button text ─────────────────────────────────────
        views.setTextViewText(R.id.widget_add_expense_button, "+ Add Expense")

        // ── Label text ──────────────────────────────────────────────────
        views.setTextViewText(R.id.widget_safe_spending_label, "Today's Safe Spending")
        views.setTextViewText(R.id.widget_spent_today_label, "Spent Today")

        if (remainingDays > 0) {
            views.setTextViewText(
                R.id.widget_remaining_text,
                "${formatCurrency(remaining, symbol)} left · ${remainingDays}d remaining",
            )
        } else {
            views.setTextViewText(R.id.widget_remaining_text, "")
        }
    }

    private fun renderEmptyState(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_safe_spending_label, "Smart Budget Tracker")
        views.setTextViewText(R.id.widget_safe_spending_amount, "—")
        views.setTextViewText(R.id.widget_spent_today_label, "")
        views.setTextViewText(R.id.widget_spent_today_amount, "")
        views.setTextViewText(
            R.id.widget_status,
            "Open app to set up a budget",
        )
        views.setTextColor(R.id.widget_status, 0xFF757575.toInt())
        views.setTextViewText(R.id.widget_add_expense_button, "+ Add Expense")
        views.setTextViewText(R.id.widget_remaining_text, "")
    }

    private fun formatCurrency(amount: Double, symbol: String): String {
        return "$symbol${String.format(Locale.US, "%,.0f", amount)}"
    }

    private fun getCurrencySymbol(code: String): String {
        return when (code) {
            "INR" -> "₹"
            "USD" -> "$"
            "EUR" -> "€"
            "GBP" -> "£"
            "JPY" -> "¥"
            "AED" -> "د.إ"
            "CAD" -> "C$"
            "AUD" -> "A$"
            "SGD" -> "S$"
            else -> "₹"
        }
    }

    private fun getStringSafe(prefs: SharedPreferences, key: String, default: String): String {
        return try {
            val value = prefs.all[key] ?: return default
            value.toString()
        } catch (e: Exception) {
            default
        }
    }

    private fun getPrefs(context: Context): SharedPreferences {
        return try {
            HomeWidgetPlugin.getData(context)
        } catch (e: Exception) {
            context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
        }
    }
}

/**
 * Helper that invokes the native widget update.
 */
object HomeWidgetServiceWrapper {
    fun updateWidgetData(context: Context) {
        HomeScreenWidgetProvider.updateAllWidgets(context)
    }
}

