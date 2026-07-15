import 'package:flutter/material.dart';

/// Shared visual-language primitives for the whole app.
///
/// Colour is semantic and identical across money and body: green = "on plan",
/// amber = "attention", red = "problem". The heat ramp below is the single
/// source of truth for every intensity visualisation (muscle heatmap, day
/// calendar, load charts) so they always read the same way.

/// "On plan / good" — a value that is healthy.
const Color vizGood = Color(0xFF22C55E);

/// "Attention" — worth a look, not yet a problem.
const Color vizWarn = Color(0xFFF59E0B);

/// "Problem" — over the limit / overload / deficit.
const Color vizBad = Color(0xFFEF4444);

/// Neutral cool tone used as the "no data / cold" end of the heat ramp.
const Color vizCold = Color(0xFF93C5FD);

/// Blends a cool → amber → red ramp for a heat intensity in [0, 1].
///
/// [base] is returned for (near-)zero intensity so an empty cell blends into
/// the surface instead of showing a cold-blue tile.
Color heatColor(double t, Color base) {
  final v = t.clamp(0.0, 1.0);
  if (v <= 0.02) return base;
  if (v < 0.5) {
    return Color.lerp(vizCold, vizWarn, v / 0.5)!;
  }
  return Color.lerp(vizWarn, vizBad, (v - 0.5) / 0.5)!;
}

/// Maps a ratio of actual-to-limit onto the shared green/amber/red semantics.
/// [ratio] < warnAt → good, < badAt → attention, else problem.
Color vizStatusColor(double ratio,
    {double warnAt = 0.85, double badAt = 1.0}) {
  if (ratio >= badAt) return vizBad;
  if (ratio >= warnAt) return vizWarn;
  return vizGood;
}
