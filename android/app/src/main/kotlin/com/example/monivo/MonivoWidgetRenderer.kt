package com.example.monivo

import android.app.PendingIntent
import android.content.Context
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.os.Build
import android.text.Layout
import android.text.SpannableStringBuilder
import android.util.Log
import android.util.SizeF
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import androidx.annotation.LayoutRes
import androidx.annotation.RequiresApi
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The widget's layouts, **richest first**. For a given widget size the first
 * one that fits is used ([WidgetRenderer.choose]); what fits depends on the
 * space the launcher gives the widget and on how much room each layout's
 * content needs at the current font and display size
 * ([WidgetRenderer.sizedLayouts]).
 *
 * Content priority, highest first: the amount; what it is (label) and its
 * status; today's spending against it; the budget behind it; Add expense.
 * Each step down drops from the end of that list. [mustFit] names the text
 * that must show in full for a layout to count as fitting; anything else
 * (the budget's name) may be shortened with an ellipsis by design.
 */
internal enum class WidgetLayout(
    @LayoutRes val res: Int,
    val forFigures: Boolean,
    val minWidthDp: Float,
    val mustFit: IntArray,
) {
    /** Large: budget, amount, status, today, budget left and its track, Add expense. */
    EXPANDED(
        R.layout.widget_expanded, true, 220f,
        intArrayOf(
            R.id.widget_label, R.id.widget_amount, R.id.widget_status,
            R.id.widget_spent_label, R.id.widget_spent,
            R.id.widget_rest_label, R.id.widget_rest,
            R.id.widget_budget_left, R.id.widget_add_label,
        ),
    ),

    /** Medium: amount, status and budget, today's track, spent and left today. */
    STANDARD(
        R.layout.widget_standard, true, 200f,
        intArrayOf(
            R.id.widget_label, R.id.widget_amount, R.id.widget_status,
            R.id.widget_spent_label, R.id.widget_spent,
            R.id.widget_rest_label, R.id.widget_rest,
        ),
    ),

    /** Narrow and tall: amount, status, today's track, left today, Add. */
    COMPACT_TALL(
        R.layout.widget_compact_tall, true, 96f,
        intArrayOf(
            R.id.widget_label, R.id.widget_amount, R.id.widget_status,
            R.id.widget_rest_label, R.id.widget_rest, R.id.widget_add_label,
        ),
    ),

    /** Wide and short: amount and status, left today, Add. */
    ROW_WIDE(
        R.layout.widget_row, true, 280f,
        intArrayOf(
            R.id.widget_label, R.id.widget_amount, R.id.widget_status,
            R.id.widget_rest_label, R.id.widget_rest,
        ),
    ),
    ROW(
        R.layout.widget_row, true, 200f,
        intArrayOf(R.id.widget_label, R.id.widget_amount, R.id.widget_status),
    ),

    /** Small: amount, label and status. */
    COMPACT(
        R.layout.widget_compact, true, 96f,
        intArrayOf(R.id.widget_label, R.id.widget_amount, R.id.widget_status),
    ),

    /** Wide and very short: amount and label beside Add; status as a dot. */
    ROW_SLIM(
        R.layout.widget_row, true, 200f,
        intArrayOf(R.id.widget_label, R.id.widget_amount),
    ),

    /** Small and short: amount and label; status as a dot. */
    COMPACT_SLIM(
        R.layout.widget_compact, true, 96f,
        intArrayOf(R.id.widget_label, R.id.widget_amount),
    ),

    /** Label above an amount that fills what is left (never below its floor). */
    GLANCE_LABELLED(
        R.layout.widget_glance, true, 96f,
        intArrayOf(R.id.widget_label, R.id.widget_amount),
    ),

    /** The amount alone, filling the space (never below its floor). */
    GLANCE(R.layout.widget_glance, true, 48f, intArrayOf(R.id.widget_amount)),

    /** Last resort: the amount in whole units, sized to fit. */
    GLANCE_WHOLE(R.layout.widget_glance, true, 0f, intArrayOf()),

    MESSAGE_FULL(
        R.layout.widget_message, false, 160f,
        intArrayOf(R.id.widget_title, R.id.widget_body, R.id.widget_add_label),
    ),
    MESSAGE(R.layout.widget_message, false, 96f, intArrayOf(R.id.widget_title, R.id.widget_body)),
    MESSAGE_TITLE(R.layout.widget_message, false, 96f, intArrayOf(R.id.widget_title)),

    /** Last resort for messages: the title, sized to fit. */
    MESSAGE_GLANCE(R.layout.widget_message_glance, false, 0f, intArrayOf()),
}

/** A layout, filled in, and the smallest size (dp) that shows its content. */
internal data class SizedLayout(val layout: WidgetLayout, val size: SizeF, val views: RemoteViews)

/**
 * Builds the widget's [RemoteViews] for each [WidgetLayout] and measures how
 * much room each needs.
 *
 * Colours: Android 12+ gets the palette's light and dark colours and switches
 * with the system theme by itself. Older versions get the colours for the
 * theme in force when the widget is drawn; their progress bars keep the
 * neutral colours from resources (tinting them needs Android 12).
 */
internal class WidgetRenderer(
    private val context: Context,
    private val light: WidgetColors,
    private val dark: WidgetColors,
    private val openApp: PendingIntent,
    private val addExpense: PendingIntent,
) {
    private val current: WidgetColors =
        if ((context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        ) dark else light
    private val density = context.resources.displayMetrics.density

    /**
     * Every layout that can show [content] at this font and display size,
     * richest first, with the smallest size (dp) at which its must-fit text
     * shows in full.
     */
    fun sizedLayouts(content: WidgetContent): List<SizedLayout> =
        WidgetLayout.values()
            .filter { it.forFigures == (content is WidgetFigures) }
            .mapNotNull { layout ->
                val views = build(layout, content)
                requiredSize(layout, views)?.let { SizedLayout(layout, it, views) }
            }

    fun build(layout: WidgetLayout, content: WidgetContent): RemoteViews {
        val views = RemoteViews(context.packageName, layout.res)
        image(views, R.id.widget_surface) { it.surface }
        views.setOnClickPendingIntent(android.R.id.background, openApp)
        when (content) {
            is WidgetFigures -> figures(views, layout, content)
            is WidgetMessage -> message(views, layout, content)
        }
        return views
    }

    private fun figures(views: RemoteViews, layout: WidgetLayout, f: WidgetFigures) {
        views.setContentDescription(android.R.id.background, f.summary)
        // The full label where it has a line to itself; "Safe today" where it
        // shares the space with the amount or the Add button.
        val roomy = layout == WidgetLayout.EXPANDED || layout == WidgetLayout.STANDARD
        text(views, R.id.widget_label, if (roomy) f.label else f.shortLabel) { it.muted }
        text(views, R.id.widget_amount, f.safe.styled()) { it.ink }
        image(views, R.id.widget_status_dot) { it.tone(f.statusTone) }
        text(views, R.id.widget_status, f.statusLabel) { it.ink }
        if (layout == WidgetLayout.COMPACT_SLIM || layout == WidgetLayout.ROW_SLIM) {
            views.setViewVisibility(R.id.widget_status, View.GONE)
        }
        if (layout == WidgetLayout.GLANCE || layout == WidgetLayout.GLANCE_WHOLE) {
            views.setViewVisibility(R.id.widget_label_row, View.GONE)
        }
        if (layout == WidgetLayout.GLANCE_WHOLE) {
            text(views, R.id.widget_amount, f.safe.styled(fraction = false)) { it.ink }
        }

        if (layout == WidgetLayout.EXPANDED) {
            text(views, R.id.widget_budget, f.budgetName) { it.ink }
        } else {
            text(views, R.id.widget_budget, "· ${f.budgetName}") { it.muted }
        }
        text(views, R.id.widget_days_left, f.daysLeft) { it.muted }

        progress(views, R.id.widget_today_progress, f.todayProgress) { it.tone(f.statusTone) }
        text(views, R.id.widget_spent_label, f.spentLabel) { it.muted }
        text(views, R.id.widget_spent, f.spent) { it.ink }
        text(views, R.id.widget_rest_label, f.restLabel) { it.muted }
        text(views, R.id.widget_rest, f.rest) { it.ink }
        if (layout == WidgetLayout.ROW || layout == WidgetLayout.ROW_SLIM) {
            views.setViewVisibility(R.id.widget_metrics, View.GONE)
        }

        image(views, R.id.widget_divider) { it.divider }
        text(views, R.id.widget_budget_left, f.budgetLeft) { it.ink }
        progress(views, R.id.widget_budget_progress, f.budgetProgress) { it.tone(f.budgetTone) }

        addButton(views, short = layout == WidgetLayout.COMPACT_TALL)
    }

    private fun message(views: RemoteViews, layout: WidgetLayout, m: WidgetMessage) {
        views.setContentDescription(
            android.R.id.background,
            if (m.body.isEmpty()) m.title else "${m.title}. ${m.body}",
        )
        text(views, R.id.widget_title, if (layout == WidgetLayout.MESSAGE_GLANCE) m.short else m.title) { it.ink }
        text(views, R.id.widget_body, m.body) { it.muted }
        if (layout == WidgetLayout.MESSAGE_TITLE || m.body.isEmpty()) {
            views.setViewVisibility(R.id.widget_body, View.GONE)
        }
        if (layout != WidgetLayout.MESSAGE_FULL) {
            views.setViewVisibility(R.id.widget_add, View.GONE)
        }
        addButton(views, short = false)
    }

    private fun addButton(views: RemoteViews, short: Boolean) {
        views.setOnClickPendingIntent(R.id.widget_add, addExpense)
        image(views, R.id.widget_add_bg) { it.accent }
        image(views, R.id.widget_add_icon) { it.onAccent }
        val label = context.getString(
            if (short) R.string.widget_add_short else R.string.widget_add_expense,
        )
        text(views, R.id.widget_add_label, label) { it.onAccent }
    }

    // ── Colours ──────────────────────────────────────────────────────────────

    private inline fun text(
        views: RemoteViews,
        id: Int,
        value: CharSequence,
        color: (WidgetColors) -> Int,
    ) {
        views.setTextViewText(id, ltr(value))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setDayNight(views, id, "setTextColor", color(light), color(dark))
        } else {
            views.setTextColor(id, color(current))
        }
    }

    private inline fun image(views: RemoteViews, id: Int, color: (WidgetColors) -> Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setDayNight(views, id, "setColorFilter", color(light), color(dark))
        } else {
            views.setInt(id, "setColorFilter", color(current))
        }
    }

    private inline fun progress(
        views: RemoteViews,
        id: Int,
        value: Float,
        fill: (WidgetColors) -> Int,
    ) {
        views.setProgressBar(id, PROGRESS_MAX, (value.coerceIn(0f, 1f) * PROGRESS_MAX).roundToInt(), false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setDayNight(views, id, "setProgressTintList", fill(light), fill(dark), list = true)
            setDayNight(views, id, "setProgressBackgroundTintList", light.track, dark.track, list = true)
        }
    }

    /**
     * [text] set left to right, like the app. A figure that starts with an
     * Arabic-script currency symbol (ر.ع.) would otherwise make a host that
     * guesses the direction from the first letter draw the line right to
     * left, with the symbol after the digits. The layouts also declare
     * `textDirection="ltr"`; this holds even where that is not applied.
     */
    private fun ltr(text: CharSequence): CharSequence =
        SpannableStringBuilder(LRM).append(text)

    @RequiresApi(Build.VERSION_CODES.S)
    private fun setDayNight(
        views: RemoteViews,
        id: Int,
        method: String,
        day: Int,
        night: Int,
        list: Boolean = false,
    ) {
        if (list) {
            views.setColorStateList(id, method, ColorStateList.valueOf(day), ColorStateList.valueOf(night))
        } else {
            views.setColorInt(id, method, day, night)
        }
    }

    // ── Measuring ────────────────────────────────────────────────────────────

    /**
     * The smallest size (dp) at which [layout] shows its must-fit text in
     * full, measured with the real layout at this font and display size, or
     * null when no reasonable width is enough (a very long amount at a very
     * large font size); then a smaller layout takes over.
     */
    private fun requiredSize(layout: WidgetLayout, views: RemoteViews): SizeF? {
        if (layout.mustFit.isEmpty()) return FALLBACK_SIZE
        val view = try {
            views.apply(context, FrameLayout(context))
        } catch (e: Exception) {
            Log.w(TAG, "Couldn't measure ${layout.name}", e)
            return null
        }
        fixTextSizes(view)
        var widthDp = layout.minWidthDp
        repeat(MAX_ATTEMPTS) {
            view.measure(
                View.MeasureSpec.makeMeasureSpec((widthDp * density).roundToInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
            )
            val shortBy = layout.mustFit.maxOf { id -> shortfallPx(view.findViewById(id), view) }
            if (shortBy <= 0f) {
                return SizeF(widthDp, ceil(view.measuredHeight / density) + HEIGHT_SLACK_DP)
            }
            widthDp += max(WIDTH_STEP_DP, ceil(shortBy / density))
            if (widthDp > MAX_WIDTH_DP) return null
        }
        return null
    }

    /**
     * The smallest layouts auto-size their amount to fill the space; it is
     * measured at its floor size (its declared size), so auto-sizing must
     * not shrink it while it is being measured.
     */
    private fun fixTextSizes(view: View) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (view is TextView) view.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE)
        if (view is ViewGroup) for (i in 0 until view.childCount) fixTextSizes(view.getChildAt(i))
    }

    /**
     * How much wider (px) [text] needs to be to show without an ellipsis: 0
     * when it fits or is hidden. One-line text reports its exact shortfall;
     * wrapping text reports a token amount, so the width grows by a step.
     */
    private fun shortfallPx(text: TextView?, root: View): Float {
        if (text == null || !isShownIn(text, root)) return 0f
        val layout = text.layout ?: return 0f
        val ellipsized = (0 until layout.lineCount).any { layout.getEllipsisCount(it) > 0 }
        if (!ellipsized) return 0f
        if (text.maxLines != 1) return 1f
        val needed = Layout.getDesiredWidth(text.text, text.paint)
        return max(1f, needed - layout.width + 1f)
    }

    private fun isShownIn(view: View, root: View): Boolean {
        var v: View? = view
        while (v != null) {
            if (v.visibility != View.VISIBLE) return false
            if (v === root) return true
            v = v.parent as? ViewGroup
        }
        return true
    }

    companion object {
        private const val TAG = "MonivoWidget"
        private const val LRM = "\u200E"
        private const val PROGRESS_MAX = 1000
        private const val MAX_ATTEMPTS = 16
        private const val WIDTH_STEP_DP = 8f
        private const val MAX_WIDTH_DP = 720f

        /** Room for rounding between this process and the launcher's. */
        private const val HEIGHT_SLACK_DP = 2f

        /**
         * The last-resort layouts claim the smallest size, so they are used
         * only when nothing else fits.
         */
        private val FALLBACK_SIZE = SizeF(1f, 1f)

        /**
         * The layout for a widget of [size] (dp): the richest of [layouts]
         * that fits, else the smallest. "Fits" allows the same 1 dp of
         * rounding as Android's own choice (RemoteViews.fitsIn).
         */
        fun choose(layouts: List<SizedLayout>, size: SizeF): SizedLayout =
            layouts.firstOrNull { fits(it.size, size) }
                ?: layouts.minBy { it.size.width * it.size.height }

        fun fits(layout: SizeF, widget: SizeF): Boolean =
            ceil(widget.width) + 1 > layout.width && ceil(widget.height) + 1 > layout.height
    }
}
