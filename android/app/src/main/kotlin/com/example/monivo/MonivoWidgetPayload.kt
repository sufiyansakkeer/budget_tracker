package com.example.monivo

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * What the app wrote for the home-screen widget: one JSON string built by
 * `HomeWidgetPayload` (lib/features/widgets/home_widget_payload.dart).
 *
 * Every figure and sentence in it is already worked out and formatted by the
 * app, so the widget never formats money or recomputes a budget; it only
 * decides which layout fits and paints it.
 */
internal class WidgetPayload private constructor(
    /** The day the figures are for, `yyyy-MM-dd` in local time. */
    val asOf: String,
    val light: WidgetColors?,
    val dark: WidgetColors?,
    /** Shown once the day has turned since [asOf]. */
    val stale: WidgetMessage,
    val figures: WidgetFigures?,
    val message: WidgetMessage?,
) {
    /** What to show today: the figures or message for today, or the stale message. */
    fun contentFor(today: String): WidgetContent? = when {
        asOf != today -> stale
        figures != null -> figures
        else -> message
    }

    companion object {
        const val KEY = "home_widget_payload"
        private const val VERSION = 2

        /** The stored payload, or null when there is none or it can't be read. */
        fun read(prefs: SharedPreferences): WidgetPayload? = try {
            (prefs.all[KEY] as? String)?.let(::parse)
        } catch (e: Exception) {
            null
        }

        fun parse(raw: String): WidgetPayload? {
            val json = JSONObject(raw)
            // A format this version doesn't know: show "open the app" instead.
            if (json.optInt("v") != VERSION) return null
            val colors = json.optJSONObject("colors")
            return WidgetPayload(
                asOf = json.getString("asOf"),
                light = WidgetColors.parse(colors?.optJSONObject("light")),
                dark = WidgetColors.parse(colors?.optJSONObject("dark")),
                stale = WidgetMessage.parse(json.getJSONObject("stale")),
                figures = if (json.optString("state") == "ready") {
                    WidgetFigures.parse(json)
                } else {
                    null
                },
                message = json.optJSONObject("message")?.let(WidgetMessage::parse),
            )
        }

        /** Today in the device's time zone, in the payload's format. */
        fun today(now: Date = Date()): String =
            SimpleDateFormat("yyyy-MM-dd", Locale.US).format(now)
    }
}

internal sealed interface WidgetContent

/**
 * A sentence to act on: no budget, an error, out of date, or not set up.
 * [short] stands in for [title] in the smallest sizes.
 */
internal data class WidgetMessage(
    val title: String,
    val body: String,
    val short: String = title,
) : WidgetContent {
    companion object {
        fun parse(json: JSONObject): WidgetMessage {
            val title = json.getString("title")
            return WidgetMessage(
                title = title,
                body = json.optString("body"),
                short = json.optString("short", title),
            )
        }
    }
}

/** The active budget's figures for today, as the app's Home shows them. */
internal data class WidgetFigures(
    val label: String,
    val shortLabel: String,
    val safe: WidgetMoney,
    val statusLabel: String,
    val statusTone: String,
    val todayProgress: Float,
    val spentLabel: String,
    val spent: String,
    val restLabel: String,
    val rest: String,
    val budgetName: String,
    val daysLeft: String,
    val budgetLeft: String,
    val budgetProgress: Float,
    val budgetTone: String,
    /** Everything above as one sentence, for screen readers. */
    val summary: String,
) : WidgetContent {
    companion object {
        fun parse(json: JSONObject): WidgetFigures {
            val status = json.getJSONObject("status")
            val today = json.getJSONObject("today")
            val budget = json.getJSONObject("budget")
            return WidgetFigures(
                label = json.getString("label"),
                shortLabel = json.getString("shortLabel"),
                safe = WidgetMoney.parse(json.getJSONObject("safe")),
                statusLabel = status.getString("label"),
                statusTone = status.getString("tone"),
                todayProgress = today.getDouble("progress").toFloat(),
                spentLabel = today.getString("spentLabel"),
                spent = today.getString("spent"),
                restLabel = today.getString("restLabel"),
                rest = today.getString("rest"),
                budgetName = budget.getString("name"),
                daysLeft = budget.getString("daysLeft"),
                budgetLeft = budget.getString("left"),
                budgetProgress = budget.getDouble("progress").toFloat(),
                budgetTone = budget.getString("tone"),
                summary = json.getString("summary"),
            )
        }
    }
}

/** A formatted amount in the pieces the app's hero figure sizes differently. */
internal data class WidgetMoney(
    val text: String,
    val sign: String,
    val prefix: String,
    val whole: String,
    val fraction: String,
    val suffix: String,
) {
    /**
     * The hero figure the app's way: the currency symbol and the minor units
     * at half size, so the whole units carry the meaning at a glance.
     *
     * Without [fraction] it is the whole units only, for the smallest sizes:
     * the figure is a floored safe amount, so dropping its minor units
     * rounds it down further and never promises more.
     */
    fun styled(fraction: Boolean = true): CharSequence {
        val out = SpannableStringBuilder()
        fun add(part: String, small: Boolean) {
            if (part.isEmpty()) return
            val start = out.length
            out.append(part)
            if (small) {
                out.setSpan(RelativeSizeSpan(0.5f), start, out.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }
        add(sign, small = false)
        add(prefix, small = true)
        add(whole, small = false)
        if (fraction) add(this.fraction, small = true)
        add(suffix, small = true)
        return out
    }

    companion object {
        fun parse(json: JSONObject) = WidgetMoney(
            text = json.getString("text"),
            sign = json.optString("sign"),
            prefix = json.optString("prefix"),
            whole = json.optString("whole"),
            fraction = json.optString("fraction"),
            suffix = json.optString("suffix"),
        )
    }
}

/** The app's palette colours for one brightness. */
internal data class WidgetColors(
    val surface: Int,
    val ink: Int,
    val muted: Int,
    val track: Int,
    val accent: Int,
    val onAccent: Int,
    val divider: Int,
    val positive: Int,
    val caution: Int,
    val critical: Int,
    val neutral: Int,
) {
    fun tone(name: String?): Int = when (name) {
        "positive" -> positive
        "caution" -> caution
        "critical" -> critical
        else -> neutral
    }

    companion object {
        fun parse(json: JSONObject?): WidgetColors? {
            if (json == null) return null
            return try {
                fun c(key: String) = Color.parseColor(json.getString(key))
                WidgetColors(
                    surface = c("surface"),
                    ink = c("ink"),
                    muted = c("muted"),
                    track = c("track"),
                    accent = c("accent"),
                    onAccent = c("onAccent"),
                    divider = c("divider"),
                    positive = c("positive"),
                    caution = c("caution"),
                    critical = c("critical"),
                    neutral = c("neutral"),
                )
            } catch (e: Exception) {
                null
            }
        }

        /** Monivo's Default palette from resources, for before the app has written its own. */
        fun defaults(context: Context, night: Boolean): WidgetColors {
            val config = Configuration(context.resources.configuration).apply {
                uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                    (if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO)
            }
            val res = context.createConfigurationContext(config)
            return WidgetColors(
                surface = res.getColor(R.color.widget_surface),
                ink = res.getColor(R.color.widget_ink),
                muted = res.getColor(R.color.widget_muted),
                track = res.getColor(R.color.widget_track),
                accent = res.getColor(R.color.widget_accent),
                onAccent = res.getColor(R.color.widget_on_accent),
                divider = res.getColor(R.color.widget_divider),
                positive = res.getColor(R.color.widget_positive),
                caution = res.getColor(R.color.widget_caution),
                critical = res.getColor(R.color.widget_critical),
                neutral = res.getColor(R.color.widget_neutral),
            )
        }
    }
}
