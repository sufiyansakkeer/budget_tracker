package com.example.monivo

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Debug builds only. Renders the home-screen widget, exactly as the provider
 * builds it, at many widget sizes and font scales, and checks each result:
 *
 * - **clipped**: the chosen layout's content is taller than the slot;
 * - **cut**: text that must show in full is ellipsized at that size.
 *
 * It writes one PNG per font scale and a text report to
 * `files/widget-preview/`, and logs the report under the tag
 * `MonivoWidgetPreview`.
 *
 * Parameters (in `files/widget-preview-in/request.properties`, or as string
 * extras): `payload`, a file in `files/widget-preview-in/` (default: what
 * the app last wrote); `scales`, font scales such as `1.0,1.3,2.0`;
 * `night`; `sizes`, `WxH,WxH` in dp (default: common launcher cells);
 * `out`, the output name; `dump`, to log each view's bounds.
 * ```
 * adb shell am start -n com.example.monivo/.WidgetPreviewActivity \
 *   --es payload ontrack.json --es scales 1.0,1.3,2.0 --es night false
 * ```
 */
class WidgetPreviewActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Parameters come from files/widget-preview-in/request.properties
        // (so any launch of this activity renders the same thing), and
        // intent extras override them.
        val request = java.util.Properties().apply {
            val file = File(File(filesDir, "widget-preview-in"), "request.properties")
            if (file.exists()) file.inputStream().use { load(it) }
        }
        fun param(key: String): String? = intent.getStringExtra(key) ?: request.getProperty(key)
        val payloadName = param("payload")
        val scales = param("scales")?.split(",")?.map { it.trim().toFloat() }
            ?: listOf(resources.configuration.fontScale)
        val night = param("night")?.toBoolean() ?: false
        val sizes = param("sizes")?.let(::parseSizes) ?: DEFAULT_SIZES
        val dumpTree = param("dump")?.toBoolean() ?: false
        val tag = param("out") ?: (payloadName?.removeSuffix(".json") ?: "stored")

        val raw = if (payloadName != null) {
            File(File(filesDir, "widget-preview-in"), payloadName).readText()
        } else {
            HomeWidgetPlugin.getData(this).all[WidgetPayload.KEY] as? String
        }
        val payload = raw?.let { WidgetPayload.parse(it) }
        val content = payload?.contentFor(WidgetPayload.today()) ?: WidgetMessage(
            getString(R.string.widget_setup_title),
            getString(R.string.widget_setup_body),
        )

        val outDir = File(filesDir, "widget-preview").apply { mkdirs() }
        val report = StringBuilder()
        for (scale in scales) {
            val ctx = configured(scale, night)
            val light = payload?.light ?: WidgetColors.defaults(ctx, night = false)
            val dark = payload?.dark ?: WidgetColors.defaults(ctx, night = true)
            val noop = PendingIntent.getActivity(
                this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
            )
            val renderer = WidgetRenderer(ctx, light, dark, noop, noop)
            val layouts = renderer.sizedLayouts(content)
            report.append("== $tag  font ${scale}x  ${if (night) "dark" else "light"}\n")
            report.append(
                "   layouts: " + layouts.joinToString { "${it.layout.name} ${dp(it.size)}" } + "\n",
            )
            val cells = sizes.map { size -> renderCell(ctx, layouts, size, report, dumpTree) }
            val sheet = sheet(cells, if (night) Color.rgb(28, 30, 36) else Color.rgb(150, 160, 175))
            val file = File(outDir, "${tag}_${if (night) "dark" else "light"}_$scale.png")
            file.outputStream().use { sheet.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
        File(outDir, "${tag}_${if (night) "dark" else "light"}.txt").writeText(report.toString())
        report.lines().forEach { Log.i(TAG, it) }

        // Nothing to show: the output is the files. Finishing keeps the
        // activity out of the way of the next run.
        finish()
    }

    private class Cell(val bitmap: Bitmap, val caption: String, val problem: Boolean)

    private fun renderCell(
        ctx: Context,
        layouts: List<SizedLayout>,
        size: SizeF,
        report: StringBuilder,
        dumpTree: Boolean,
    ): Cell {
        val density = ctx.resources.displayMetrics.density
        val chosen = WidgetRenderer.choose(layouts, size)
        val w = (size.width * density).roundToInt()
        val h = (size.height * density).roundToInt()
        // How tall the content wants to be at this width, against the slot,
        // with auto-sized text at its declared (floor) size.
        val natural = chosen.views.apply(ctx, FrameLayout(ctx))
        noAutoSize(natural)
        natural.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        val fallback = chosen.layout.mustFit.isEmpty()
        val overflowDp = if (fallback) 0f else (natural.measuredHeight - h) / density

        val view = chosen.views.apply(ctx, FrameLayout(ctx))

        view.measure(
            View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
        )
        view.layout(0, 0, w, h)
        val cut = cutTexts(view, if (fallback) intArrayOf(R.id.widget_amount, R.id.widget_title) else chosen.layout.mustFit)

        // A fill that does not cover its button or card.
        val unfilled = listOf(
            R.id.widget_surface to android.R.id.background,
            R.id.widget_add_bg to R.id.widget_add,
        ).mapNotNull { (fill, owner) ->
            val f = view.findViewById<View>(fill)
            val o = view.findViewById<View>(owner)
            if (f == null || o == null || !shown(o, view)) null
            else if (f.width < o.width || f.height < o.height) resources.getResourceEntryName(fill)
            else null
        }
        val problems = buildList {
            if (overflowDp > 0.5f) add("CLIPPED ${ceil(overflowDp).toInt()}dp")
            if (cut.isNotEmpty()) add("CUT ${cut.joinToString()}")
            if (unfilled.isNotEmpty()) add("UNFILLED ${unfilled.joinToString()}")
        }
        val caption = "${dp(size)} ${chosen.layout.name}" +
            if (problems.isEmpty()) "" else "  ${problems.joinToString("  ")}"
        report.append("   ${dp(size).padEnd(9)} -> ${chosen.layout.name.padEnd(14)} needs ${dp(chosen.size).padEnd(9)} ${if (problems.isEmpty()) "ok" else problems.joinToString("  ")}\n")

        if (dumpTree) dump(view, "", report)

        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        return Cell(bitmap, caption, problems.isNotEmpty())
    }

    /** Must-fit text that is ellipsized (or, for auto-sized text, cut) at its laid-out size. */
    private fun cutTexts(root: View, ids: IntArray): List<String> = ids.toList().mapNotNull { id ->
        val text = root.findViewById<TextView>(id) ?: return@mapNotNull null
        if (!shown(text, root)) return@mapNotNull null
        val layout = text.layout ?: return@mapNotNull null
        val ellipsized = (0 until layout.lineCount).any { layout.getEllipsisCount(it) > 0 }
        val tooTall = layout.height > text.height - text.compoundPaddingTop - text.compoundPaddingBottom + 1
        if (ellipsized || tooTall) resources.getResourceEntryName(id).removePrefix("widget_") else null
    }

    private fun noAutoSize(view: View) {
        if (view is TextView) view.setAutoSizeTextTypeWithDefaults(TextView.AUTO_SIZE_TEXT_TYPE_NONE)
        if (view is ViewGroup) for (i in 0 until view.childCount) noAutoSize(view.getChildAt(i))
    }

    /** The laid-out view tree with bounds in dp, for debugging a layout. */
    private fun dump(view: View, indent: String, out: StringBuilder) {
        val d = view.resources.displayMetrics.density
        val name = if (view.id > 0) {
            try { view.resources.getResourceEntryName(view.id) } catch (e: Exception) { "?" }
        } else {
            view.javaClass.simpleName
        }
        out.append("      $indent$name ${(view.left / d).roundToInt()},${(view.top / d).roundToInt()} " +
            "${(view.width / d).roundToInt()}x${(view.height / d).roundToInt()}" +
            (if (view.visibility != View.VISIBLE) " (hidden)" else "") + "\n")
        if (view is ViewGroup) for (i in 0 until view.childCount) dump(view.getChildAt(i), "$indent  ", out)
    }

    private fun shown(view: View, root: View): Boolean {
        var v: View? = view
        while (v != null && v !== root) {
            if (v.visibility != View.VISIBLE) return false
            v = v.parent as? ViewGroup
        }
        return true
    }

    /** The cells on a wallpaper-coloured sheet, captioned, wrapped to rows. */
    private fun sheet(cells: List<Cell>, wallpaper: Int): Bitmap {
        val gap = 36
        val captionHeight = 44
        val maxRowWidth = 2400
        val rows = mutableListOf<MutableList<Cell>>(mutableListOf())
        var rowWidth = gap
        for (cell in cells) {
            if (rowWidth + cell.bitmap.width + gap > maxRowWidth && rows.last().isNotEmpty()) {
                rows.add(mutableListOf())
                rowWidth = gap
            }
            rows.last().add(cell)
            rowWidth += cell.bitmap.width + gap
        }
        val width = rows.maxOf { row -> gap + row.sumOf { it.bitmap.width + gap } }
        val height = gap + rows.sumOf { row -> captionHeight + row.maxOf { it.bitmap.height } + gap }
        val out = Bitmap.createBitmap(max(width, 200), height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawColor(wallpaper)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 30f
            typeface = Typeface.MONOSPACE
        }
        var y = gap
        for (row in rows) {
            var x = gap
            for (cell in row) {
                paint.color = if (cell.problem) Color.rgb(255, 80, 80) else Color.WHITE
                canvas.drawText(cell.caption, x.toFloat(), (y + 32).toFloat(), paint)
                canvas.drawBitmap(cell.bitmap, x.toFloat(), (y + captionHeight).toFloat(), null)
                x += cell.bitmap.width + gap
            }
            y += captionHeight + row.maxOf { it.bitmap.height } + gap
        }
        return out
    }

    private fun configured(fontScale: Float, night: Boolean): Context {
        val config = Configuration(resources.configuration).apply {
            this.fontScale = fontScale
            uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                (if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO)
        }
        return createConfigurationContext(config)
    }

    private fun dp(size: SizeF) = "${size.width.roundToInt()}x${size.height.roundToInt()}"

    private fun parseSizes(spec: String): List<SizeF> = spec.split(",").map {
        val (w, h) = it.trim().split("x")
        SizeF(w.toFloat(), h.toFloat())
    }

    companion object {
        private const val TAG = "MonivoWidgetPreview"

        /**
         * Typical launcher cells (Android widget sizing guidance, portrait and
         * landscape) plus in-between sizes.
         */
        val DEFAULT_SIZES = listOf(
            SizeF(110f, 50f), SizeF(130f, 102f), SizeF(130f, 220f), SizeF(130f, 337f),
            SizeF(203f, 102f), SizeF(203f, 220f), SizeF(276f, 60f), SizeF(276f, 102f),
            SizeF(276f, 160f), SizeF(276f, 220f), SizeF(276f, 337f), SizeF(276f, 455f),
            SizeF(349f, 102f), SizeF(349f, 220f), SizeF(412f, 160f), SizeF(160f, 160f),
        )
    }
}
