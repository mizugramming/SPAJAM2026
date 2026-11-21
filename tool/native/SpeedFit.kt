package jp.spajam.polish_workshop

import java.io.File
import java.util.Locale
import kotlin.math.roundToLong
import kotlin.system.exitProcess

private data class Peak(val startNs: Long, val endNs: Long, val mps: Double)
private data class Take(val name: String, val startNs: Long, val endNs: Long, val peaks: List<Peak>)
private data class Split(val train: List<List<Peak>>, val holdout: List<Peak>, val description: String)

// Only a pass bounded by two velocity sign changes is a complete training example.
// The game can start responding earlier, with the current and last peak available so far.
private fun readTake(file: File, activeFromNs: Long): Take {
    val motion = DeskMotion()
    val peaks = mutableListOf<Peak>()
    var firstNs = -1L
    var lastNs = -1L
    var passStartNs = -1L
    file.useLines { lines ->
        val rows = lines.iterator()
        require(rows.hasNext() && rows.next().trim() == "t_s,x_m_s2,y_m_s2,z_m_s2") { "Invalid header in ${file.name}" }
        for (row in rows) {
            if (row.isBlank()) continue
            val cells = row.split(',')
            require(cells.size == 4) { "Expected 4 columns in ${file.name}" }
            val seconds = cells[0].toDouble()
            val ns = (seconds * 1e9).roundToLong()
            val xyz = FloatArray(3) { cells[it + 1].toFloat() }
            require(seconds.isFinite() && ns > lastNs && xyz.all { it.isFinite() }) { "Invalid sample in ${file.name}" }
            if (firstNs < 0) firstNs = ns
            lastNs = ns
            val sample = motion.update(ns, xyz)
            if (!sample.contact || sample.began) passStartNs = ns
            val speed = sample.completedPassPeakMps ?: continue
            if (passStartNs >= activeFromNs) peaks.add(Peak(passStartNs, ns, speed))
            passStartNs = ns
        }
    }
    return Take(file.path, maxOf(activeFromNs, firstNs), lastNs, peaks)
}

private fun quantile(values: List<Double>, fraction: Double): Double {
    val sorted = values.sorted()
    val rank = sorted.lastIndex * fraction
    val lower = rank.toInt()
    return sorted[lower] + (sorted[minOf(lower + 1, sorted.lastIndex)] - sorted[lower]) * (rank - lower)
}

private fun fmt(value: Double) = String.format(Locale.ROOT, "%.4f", value)

private fun split(takes: List<Take>): Split {
    if (takes.size > 1) return Split(takes.dropLast(1).map { it.peaks }, takes.last().peaks, "held-out take ${takes.last().name}")
    val take = takes.single()
    val midpoint = take.startNs + (take.endNs - take.startNs) / 2
    // Exclude the pass crossing the boundary, so a pass never contributes to both sets.
    return Split(listOf(take.peaks.filter { it.endNs <= midpoint }), take.peaks.filter { it.startNs >= midpoint },
        "second half of ${take.name} (same take)")
}

private fun describe(label: String, examples: List<Peak>) {
    val speeds = examples.map { it.mps }
    val stats = if (speeds.isEmpty()) "" else
        " range=${fmt(speeds.min())}..${fmt(speeds.max())} median=${fmt(quantile(speeds, .5))} m/s"
    println("$label passes=${speeds.size}$stats")
}

fun main(args: Array<String>) {
    val customStart = args.firstOrNull() == "--from-seconds"
    val activeFrom = if (customStart) args.getOrNull(1)?.toDoubleOrNull() else 3.0
    require(activeFrom != null && activeFrom.isFinite() && activeFrom >= 0) { "Expected a non-negative CSV time in seconds" }
    val labelled = args.drop(if (customStart) 2 else 0)
    val boundary = labelled.indexOf("--fast")
    require(labelled.firstOrNull() == "--slow" && boundary in 2 until labelled.lastIndex) {
        "Usage: SpeedFitKt [--from-seconds 3] --slow slow1.csv [slow2.csv ...] --fast fast1.csv [fast2.csv ...]"
    }
    val paths = labelled.slice(1 until boundary) + labelled.drop(boundary + 1)
    require(paths.map { File(it).canonicalFile }.distinct().size == paths.size) { "Use distinct labelled recordings" }
    println("Fit complete passes inside t >= $activeFrom s. Earlier samples warm up the detector.")
    val takes = paths.map { readTake(File(it), (activeFrom * 1e9).roundToLong()) }
    val groups = listOf(takes.take(boundary - 1), takes.drop(boundary - 1))
    val splits = groups.map { split(it) }
    val labels = listOf("slow", "fast")
    for (i in labels.indices) {
        for (take in groups[i]) describe("${labels[i]} ${take.name}", take.peaks)
        describe("${labels[i]} fit", splits[i].train.flatten())
        describe("${labels[i]} ${splits[i].description}", splits[i].holdout)
    }
    if (splits.any { split -> split.train.any { it.size < 2 } || split.holdout.size < 2 }) {
        System.err.println("Insufficient complete passes for fit or holdout. Record another labelled take.")
        exitProcess(2)
    }
    // Each take gets one vote for its class center, irrespective of its duration or stroke count.
    val centers = splits.map { split -> quantile(split.train.map { take -> quantile(take.map { it.mps }, .5) }, .5) }
    val (slow, fast) = splits.map { it.train.flatten().map { sample -> sample.mps } }
    println("Training centers in m/s: slow=${fmt(centers[0])} fast=${fmt(centers[1])}")
    if (centers[0] >= centers[1]) {
        System.err.println("Labelled speed centers are reversed or equal. Record comparable travel distances.")
        exitProcess(2)
    }
    if (slow.max() >= fast.min()) System.err.println("Slow and fast training ranges overlap.")
    val threshold = centers.average()
    val correct = splits.mapIndexed { i, split -> split.holdout.count { (it.mps >= threshold) == (i == 1) } }
    for (i in labels.indices) println("${labels[i]} holdout: ${correct[i]}/${splits[i].holdout.size} correct at ${fmt(threshold)} m/s")
    if (quantile(slow, .75) >= quantile(fast, .25) || correct.indices.any { 2 * correct[it] <= splits[it].holdout.size }) {
        System.err.println("The classes do not separate reliably in this recording. Keep existing calibration.")
        exitProcess(2)
    }
    println("Interpolation anchors in m/s: slowPeakMps=${fmt(centers[0])} fastPeakMps=${fmt(centers[1])}")
}
