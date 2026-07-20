# PerformanceTrail — Full Architecture Audit & Reconstruction Guide

> **Target audience:** An AI (or developer) tasked with reconstructing AstroMonix's `PerformanceTrail` as a
> portable method for a **non-browser project** that has its own debug/logging system.
>
> This document is a complete, self-contained blueprint. It describes every design decision, every API
> surface, every throttle rule, and every integration hook — so you can adapt it to any environment
> (game engine, native app, server-side runtime, embedded system, CLI tool).

---

## 1. Executive Summary

**PerformanceTrail** is a ~370-line, zero-dependency, IIFE-based instrumentation layer for a browser-based
3D astrology app. Its job is to:

- **Time spans** (`start`/`end`) with nanosecond-equivalent precision (`performance.now()`).
- **Aggregate** min/max/avg/last per span label — always on, negligible overhead.
- **Throttle console output** so the debug channel isn't flooded.
- **Enrich errors** with structured key=value context rendered to the same debug channel.
- **Track FPS** via a per-frame `tick()` method.
- **Gate everything** behind `_enabled` so the cost is a single boolean short-circuit when off.

The system is **not** a general-purpose logging framework. It is a **timing-and-error enrichment**
tool that sits *alongside* the project's main debug system (`debugConsole`), feeding it the same data
but using a separate output path (`console.error`) to exploit the browser's built-in log-level filtering.

---

## 2. File & Loading

| Property | Value |
|----------|-------|
| File | `js/performance-trail.js` |
| Size | ~370 lines (including comments) |
| Dependencies | **None** (pure IIFE, no imports) |
| Load order | Loaded via `<script src="js/performance-trail.js" defer></script>` in `index.html` line 7626 |
| Load timing | Early enough that `window.PerfTrail` exists before any instrumented code runs |
| Execution model | IIFE — runs immediately at parse time; no `DOMContentLoaded` or `load` event needed |

---

## 3. Full Architecture Audit

### 3.1 Module Structure

```
;(function () {
    'use strict';
    var PT = { ... };          // The singleton object
    // ... auto-enable logic ...
    // ... default budgets ...
    window.PerfTrail = PT;     // Primary export
    window.PerformanceTrail = PT; // Legacy alias
    globalThis.PerfTrail = PT; // Global fallback
})();
```

### 3.2 Internal State (`PT` properties)

| Property | Type | Purpose |
|----------|------|---------|
| `_enabled` | `boolean` | Master gate. When `false`, `start()` returns immediately. |
| `_spans` | `{}` | Active spans: `{ label: { start: DOMHighResTimeStamp, threshold: ms } }`. Key deleted on `end()`. |
| `_history` | `[]` | Ring buffer of completed spans: `{ label, elapsed, ts, overBudget }`. Capped at 200. |
| `_aggregates` | `{}` | Per-label stats: `{ count, total, min, max, last }`. Always accumulates even when console output is suppressed. |
| `_budgets` | `{}` | Per-label budget thresholds (ms). Set via `.budget(label, ms)`. |
| `_maxHistory` | `200` | History cap to prevent unbounded growth. |
| `_lastLogged` | `{}` | Per-label last-output timestamp (for console throttle). |
| `_logThrottleMs` | `{}` | Per-label minimum interval between console outputs (ms). |
| `_frameCount` | `number` | Rolling FPS counter (reset every 1s window). |
| `_frameWindowStart` | `DOMHighResTimeStamp` | Start of current FPS measurement window. |
| `_frameFPS` | `number` | Most recent FPS reading. |

### 3.3 Budget Table (default thresholds)

Set at the bottom of the IIFE via `PT.budget(label, ms)`:

| Label | Budget (ms) | Scope |
|-------|-------------|-------|
| `calculateChart` | 5000 | Full chart calculation pipeline |
| `chart-calc-core` | 4000 | Core astronomy calculation |
| `chart-calc-aspects` | 500 | Aspect computation |
| `chart-calc-ui` | 1500 | UI updates triggered by chart calc |
| `updatePlanetInfo` | 8000 | Planet info panel (note: high due to interpret data load) |
| `updateAllSystems` | 2000 | Parallel system update phase |
| `smartUIUpdates` | 500 | Smart UI refresh |
| `renderChart` | 2000 | 3D chart render |
| `animation-frame` | 33 | Per-frame budget (~30fps target) |
| `aspect-calculation` | 200 | |
| `house-calculation` | 100 | |
| `planet-interpretations` | 500 | |
| `ephemeris-lookup` | 300 | |
| `sonics-update` | 200 | |
| `visualization-update` | 300 | |
| `planet-panel-prep` | 50 | |
| `planet-panel-interpret` | 800 | |
| `planet-panel-interpret-first` | 500 | |
| `planet-panel-interpret-rest` | 500 | |
| `planet-panel-dom` | 700 | |
| `planet-panel-stars` | 500 | |
| `planet-panel-cleanup` | 200 | |
| `planet-panel-archetypes` | 1000 | |
| `init-interpretation-system` | 3000 | |
| `interp-gen-planet` | 100 | |
| `interp-gen-planet-fetch` | 80 | |
| `divine-deferred-all` | 500 | Background divine generation |
| `resolve-placement` | 50 | |
| `resolve-loadcats` | 20 | |
| `resolve-lookups` | 10 | |
| `resolve-deities` | 10 | |
| `resolve-stories` | 10 | |

---

## 4. Complete API Reference

### 4.1 `PT.enable()` / `PT.disable()`
Toggle the master `_enabled` gate. When disabled, `start()` is a no-op. Aggregation continues
but console output is suppressed.

### 4.2 `PT.budget(label, ms)`
Set a budget threshold for a span label. Used by `end()` to determine `overBudget` flag.
If no budget is set, threshold is `Infinity` (never over-budget).

### 4.3 `PT.start(label)`
```javascript
_pt && _pt.start('my-operation');
```
- If `!_enabled`, returns immediately (zero-cost guard).
- Stores `performance.now()` and the label's budget threshold in `_spans[label]`.
- **Critical pattern:** `var _pt = window.PerfTrail; _pt && _pt.start(...)` — the `_pt &&` guard
  means if PerfTrail hasn't loaded yet or was removed, the call chain silently no-ops.

### 4.4 `PT.end(label)` → `number` (elapsed ms)
```javascript
_pt && _pt.end('my-operation');
```
- Looks up `_spans[label]`. If missing (span never started), returns `0`.
- Deletes the span entry from `_spans`.
- Computes `elapsed = performance.now() - span.start`.
- **Always updates aggregates** (even if `_enabled` is false at end time — aggregates are cheap).
- Pushes entry to history ring buffer (capped at 200).
- Determines `overBudget = elapsed > span.threshold`.
- **Throttle logic for console output:**
  - Over-budget spans: logged at most once per **1000ms** (dedicated `__overbudget__` throttle key).
  - Within-budget spans: logged per per-label throttle (default 500ms, 3000ms for `animation-frame`, 5000ms for `fps`).
- Formats output with color-coded `console.error()`:
  - ⚠️ (orange) for over-budget.
  - ⏱️ (blue) for within-budget.
  - Shows: label, duration, budget threshold, avg/min/max for repeated spans.
- Also feeds `window.debugConsole.log()` (the project's debug panel).

### 4.5 `PT.wrap(label, fn)` → return value of `fn`
```javascript
window.PerfTrail.wrap('planet-panel', async () => { ... });
```
- Calls `start(label)`, then `fn()`.
- Handles both sync and async functions:
  - If `fn()` returns a thenable, attaches `.then(onFulfilled, onRejected)` to call `end(label)`.
  - If sync, calls `end(label)` immediately after.
- Returns the function's return value (or the promise).

### 4.6 `PT.error(source, message, context)`
```javascript
window.PerfTrail.error('3d-vis', 'WebGL context lost', { frame: 45, planets: 10 });
```
- Formats context object into `key=value, key2=value2` string.
- Objects in context values are JSON-stringified (with fallback to `'[object]'`).
- Output via `console.error()` with color formatting:
  - ❌ (red) icon.
  - `[source]` in pink.
  - `message` in bold white.
  - Context in grey.
- Also feeds `window.debugConsole.log()`.

### 4.7 `PT.checkpoint(label, data)`
```javascript
window.PerfTrail.checkpoint('pipeline-phase', { phase: 3, planets: 8 });
```
- Logs a marker without timing. Useful for state snapshots in the performance trail.
- Output format: ◆ (purple diamond) + label + key=value context.
- Gated by `_enabled`.

### 4.8 `PT.tick()` → `number` (current FPS)
```javascript
var _pt = window.PerfTrail; _pt && _pt.tick();
```
- Called once per animation frame (in `_performMainAnimationUpdate`).
- Increments `_frameCount`. Every 1 second:
  - Computes FPS = `frameCount * 1000 / elapsedMs`.
  - Resets counter.
  - If FPS < 45 and throttle allows, logs via `console.error()`.
- Returns current FPS reading (0 until first 1s window completes).

### 4.9 `PT.fps()` → `number`
Returns the most recent FPS reading without side effects.

### 4.10 `PT.report()` → `Array | null`
- Builds a `console.table()` of all aggregates: label, count, last_ms, avg_ms, min_ms, max_ms, total_ms.
- Returns the rows array (or null if no data).

### 4.11 `PT.dump()` → `Object`
- Builds a JSON payload: `{ aggregates, history (last 100), active spans, budgets, timestamp }`.
- Attempts `navigator.clipboard.writeText()` for clipboard copy.
- Logs the JSON to console.
- Returns the payload object.

### 4.12 `PT.reset()`
Clears all spans, history, aggregates, throttle timestamps, and FPS data.

---

## 5. Throttle System (Deep Dive)

The throttle system prevents console flooding while keeping aggregates accurate.

### 5.1 Per-label throttle map

| Label | Throttle (ms) | Rationale |
|-------|---------------|-----------|
| `animation-frame` | 3000 | Fires every frame (60/sec); logging every frame would destroy console performance |
| `fps` | 5000 | Secondary FPS report; coarse enough |
| `_default` | 500 | All other spans: max 2 console outputs per second |
| `__overbudget__` | 1000 | Over-budget spans always log, but still throttled to 1/sec total across all labels |

### 5.2 How `_shouldLog(label)` works

```javascript
_shouldLog: function (label) {
    var now = Date.now();
    var last = this._lastLogged[label] || 0;
    var throttle = this._logThrottleMs[label] || this._logThrottleMs['_default'];
    if (now - last < throttle) return false;
    this._lastLogged[label] = now;
    return true;
}
```

- Uses `Date.now()` (not `performance.now()`) for throttle — wall-clock time is appropriate here.
- The throttle check is **after** aggregation, so aggregates are always fresh even when console output is suppressed.

### 5.3 Over-budget override

Over-budget spans bypass the per-label throttle and use a shared `__overbudget__` throttle
(1000ms). This ensures you *always see* budget violations, but they still can't flood the console
more than once per second total.

---

## 6. Activation System

### 6.1 Auto-enable conditions (in priority order)

```
1. Hostname is localhost / 127.0.0.1 / *.local  →  auto-enable
2. URL param ?debug_perf=1                       →  enable
3. URL param ?debug=1                            →  enable
4. localStorage 'astromonix-perf-trail' === '1'  →  enable
5. URL param ?debug_perf=0                       →  force-disable (overrides all above)
6. localStorage 'astromonix-perf-trail' === '0'  →  force-disable
```

### 6.2 Why auto-enable on localhost

The assumption is that production deployments don't use localhost. This means developers
get perf output by default without adding URL params, and production users never see it.

### 6.3 Guard pattern

```javascript
try {
    // All activation logic wrapped in try/catch
    // In case localStorage or URLSearchParams throws (e.g., sandboxed iframe)
} catch (e) { /* ignore */ }
```

---

## 7. Output & Integration Strategy

### 7.1 Why `console.error()` for everything?

Browser DevTools have a log-level filter: **Verbose / Info / Warnings / Errors**.

By routing ALL PerfTrail output through `console.error()`:
- Developers filter to the "Errors" level.
- They see: PerfTrail timing data **AND** real application errors — side by side.
- The noisy Info/Warnings tabs stay clean for other debugging.
- No custom filter panel needed — uses built-in browser tooling.

### 7.2 Color-coding

| Icon | Color | Meaning |
|------|-------|---------|
| ⏱️ | Blue (#6cf) | Within-budget span |
| ⚠️ | Orange (#f90) | Over-budget span |
| ❌ | Red (#f44) | Error enrichment |
| ◆ | Purple (#c9f) | Checkpoint |
| ○ | Red (#f66) | Low FPS warning |

### 7.3 Debug panel integration

PerfTrail feeds `window.debugConsole.log()` in two places:
1. `end()` — after aggregation, sends `[perf] label: Xms` (with ⚠️ if over budget).
2. `error()` — sends `❌ [source] message | key=value`.

The debug panel has its own throttle, so no additional throttling is applied here.

### 7.4 Zero-cost when disabled

Every call site uses the pattern:
```javascript
var _pt = window.PerfTrail;
_pt && _pt.start('label');    // truthiness short-circuit: if _pt is falsy, no call
```

When `_enabled` is false, `start()` returns immediately. The cost is:
- One variable assignment (`var _pt = window.PerfTrail;`)
- One truthiness check (`_pt &&`)
- For `end()`: if `_spans[label]` is undefined (because `start()` was a no-op), returns 0 immediately.

**Total overhead when disabled: ~2 boolean checks per instrumented boundary.** Negligible.

---

## 8. Design Principles (Transferable)

| # | Principle | Implementation |
|---|-----------|---------------|
| 1 | **Zero-cost when off** | `_pt && _pt.start(...)` short-circuits. `start()` returns immediately when `!_enabled`. |
| 2 | **Aggregation always runs** | Even when console output is suppressed, aggregates accumulate. `report()` always shows fresh data. |
| 3 | **Budgets warn, don't throw** | Over-budget spans get ⚠️ styling but never interrupt execution. |
| 4 | **History is bounded** | Ring buffer capped at 200 entries — no memory leak from long-running sessions. |
| 5 | **Per-label throttle, not global** | Each span type has its own throttle. `animation-frame` can log at 3s intervals while other spans log at 500ms. |
| 6 | **Over-budget always surfaces** | Dedicated 1s throttle for over-budget spans ensures they're never completely silent. |
| 7 | **Single output channel** | All output goes to one filtered level so devs see perf + errors together. |
| 8 | **Fail-safe activation** | All activation logic wrapped in try/catch for hostile environments (sandboxed iframes, missing localStorage). |
| 9 | **No dependencies** | Self-contained IIFE. Works in any JS environment with `performance.now()` and `console`. |
| 10 | **Dual-publish** | Primary output to `console.error`, secondary feed to project's debug panel — best of both worlds. |

---

## 9. Instrumentation Patterns (Call-Site Examples)

### 9.1 Simple span (sync)

```javascript
var _pt = window.PerfTrail; _pt && _pt.start('calculateChart');
// ... work ...
var _pt2 = window.PerfTrail; _pt2 && _pt2.end('calculateChart');
```

Note: Two variables (`_pt`, `_pt2`) because `var` is function-scoped and minification
may rename them. The actual reference is identical — it's a stylistic convention in this codebase.

### 9.2 Nested spans

```javascript
var _pt = window.PerfTrail; _pt && _pt.start('calculateChart');
    // ...
    var _ptSub = window.PerfTrail; _ptSub && _ptSub.start('chart-calc-core');
    // ... core work ...
    // _ptSub.end() not explicitly called in some paths (relying on end-of-function cleanup)
var _pt2 = window.PerfTrail; _pt2 && _pt2.end('calculateChart');
```

### 9.3 Per-frame FPS tracking

```javascript
_performMainAnimationUpdate(now, deltaTime, frameCount) {
    var _pt = window.PerfTrail; _pt && _pt.tick();
    _pt && _pt.start('animation-frame');
    // ... render work ...
    var _pt2 = window.PerfTrail; _pt2 && _pt2.end('animation-frame');
}
```

### 9.4 Error enrichment (not yet adopted in codebase, but API is available)

```javascript
window.PerfTrail.error('3d-vis', 'WebGL context lost', {
    frame: frameCount,
    planets: planetCount,
    memory: performance.memory ? performance.memory.usedJSHeapSize : 'N/A'
});
```

---

## 10. Reconstruction Guide for a Non-Browser Project

> **Assumption:** Your target project has its own debug/logging system. It does NOT have
> `console`, `performance.now()`, `localStorage`, `URLSearchParams`, `navigator.clipboard`,
> or `window`. It DOES have a high-resolution timer and a logging sink.

### 10.1 What to Port (The Core)

Port these pieces. They are environment-agnostic:

```
PerformanceTrail Core:
├── _enabled (boolean gate)
├── _spans (active span map)
├── _aggregates (per-label stats: count, total, min, max, last)
├── _history (ring buffer, capped)
├── _budgets (per-label thresholds)
├── _lastLogged (per-label throttle timestamps)
├── _logThrottleMs (per-label throttle intervals)
├── start(label)
├── end(label) → elapsed ms
├── wrap(label, fn) → return value
├── error(source, message, context)
├── checkpoint(label, data)
├── enable() / disable()
├── budget(label, ms)
├── report() → stats array
├── dump() → full payload
├── reset()
└── _shouldLog(label) → boolean
```

### 10.2 What to Replace (Environment-Specific)

| Browser API | Replacement in your project |
|-------------|----------------------------|
| `performance.now()` | Your project's high-res timer (e.g., `std::chrono::high_resolution_clock`, `System.nanoTime()`, `time.perf_counter()`, `clock_gettime(CLOCK_MONOTONIC)`) |
| `console.error()` | Your project's debug log sink at a specific severity level |
| `console.table()` | Your project's table/structured-data output (or omit — report returns raw data) |
| `Date.now()` (throttle) | Your project's wall-clock time or monotonic time (any ms-precision clock works for throttle) |
| `window.location.hostname` | Your project's environment detection (is this a dev build? CI? production?) |
| `URLSearchParams` | Your project's config/flag system (env vars, CLI flags, config file, feature flags) |
| `localStorage` | Your project's persistent config store (INI file, database, registry, plist) |
| `navigator.clipboard.writeText()` | Omit, or use your project's clipboard API |
| `window.debugConsole.log()` | Your project's debug system log method |
| `window.PerfTrail` global | Your project's singleton/static accessor (e.g., `PerfTrail::instance()`, `GPerfTrail`, DI container) |

### 10.3 What to Omit

- **FPS tracking** (`tick()`, `fps()`, `_frameCount`, `_frameWindowStart`, `_frameFPS`):
  Only relevant for frame-based rendering. If your project doesn't have animation frames, omit this.
  If it does (game engine, UI render loop), port it but replace the 1-second window with your
  engine's frame timing.

- **Browser-specific output formatting**: The `%c` CSS style strings in `console.error()` calls.
  Replace with your debug system's native formatting (structured log fields, severity levels,
  color tags, etc.).

### 10.4 Recommended Abstraction Layer

Create a thin abstraction between PerfTrail and your environment:

```cpp
// Example: C++ abstraction layer
class PerfTrailSink {
public:
    static double highResTime();                    // wraps your platform timer
    static void logWarning(const std::string& msg); // wraps your debug system
    static void logInfo(const std::string& msg);
    static void logError(const std::string& msg, const std::string& context);
    static void logTable(const std::vector<Row>& rows);
    static bool isDevEnvironment();                 // env detection
    static std::optional<std::string> getConfigFlag(const std::string& key);
    static void setPersistentConfig(const std::string& key, const std::string& value);
};
```

Then PerfTrail calls these instead of browser APIs directly. This makes future ports trivial.

### 10.5 Step-by-Step Reconstruction Plan

#### Step 1: Define the Data Structures

```
SpanEntry:       { startTime: f64, threshold: f64 }
HistoryEntry:    { label: string, elapsed: f64, timestamp: u64, overBudget: bool }
Aggregate:       { count: u32, total: f64, min: f64, max: f64, last: f64 }
```

Use a hash map (dictionary) for `_spans`, `_aggregates`, `_budgets`, `_lastLogged`, `_logThrottleMs`,
keyed by string label.

#### Step 2: Implement `start()` and `end()`

Pseudo-code for `end()`:

```
function end(label):
    span = _spans[label]
    if not span: return 0
    delete _spans[label]

    elapsed = highResTime() - span.start
    overBudget = elapsed > span.threshold

    // Always aggregate
    agg = _aggregates.getOrCreate(label, { count:0, total:0, min:INF, max:0, last:0 })
    agg.count += 1
    agg.total += elapsed
    agg.min = min(agg.min, elapsed)
    agg.max = max(agg.max, elapsed)
    agg.last = elapsed

    // Cap history
    _history.push({ label, elapsed, timestamp: wallClockMs(), overBudget })
    if _history.size > _maxHistory: _history.popFront()

    // Throttled output
    if shouldLog(label, overBudget):
        sink.logTiming(label, elapsed, span.threshold, overBudget, agg)

    // Feed debug system
    debugSystem.log("[perf] " + label + ": " + formatMs(elapsed) + (overBudget ? " ⚠️" : ""))

    return elapsed
```

#### Step 3: Implement the Throttle

```
function shouldLog(label, overBudget):
    if not _enabled: return false
    now = wallClockMs()
    if overBudget:
        key = "__overbudget__"
        interval = 1000
    else:
        key = label
        interval = _logThrottleMs.get(label) or _logThrottleMs.get("_default") or 500

    last = _lastLogged.get(key) or 0
    if now - last < interval: return false
    _lastLogged[key] = now
    return true
```

#### Step 4: Implement Activation

Replace the browser activation chain:

```
function autoEnable():
    try:
        if isDevEnvironment(): enable(); return
        if getConfigFlag("debug_perf") == "1": enable(); return
        if getConfigFlag("debug") == "1": enable(); return
        if getPersistentConfig("perf-trail") == "1": enable(); return
        if getConfigFlag("debug_perf") == "0": disable(); return
        if getPersistentConfig("perf-trail") == "0": disable(); return
    catch: // ignore
```

#### Step 5: Implement `error()`, `checkpoint()`, `wrap()`, `report()`, `dump()`, `reset()`

These are straightforward ports. Key notes:

- **`error(source, message, context)`**: Iterate context keys, stringify values, concatenate.
  If your debug system supports structured logging, pass context as a native key-value map instead
  of stringifying.

- **`wrap(label, fn)`**: In a language with proper async/await, this is simpler:
  ```
  async function wrap(label, fn):
      start(label)
      try:
          result = await fn()
          return result
      finally:
          end(label)
  ```

- **`report()`**: Return the aggregates array. Let the caller decide how to display it.

- **`dump()`**: Return a snapshot object. Don't worry about clipboard — that's a browser nicety.

- **`reset()`**: Clear all maps and counters. Straightforward.

#### Step 6: Instrument Your Code

Use the same guard pattern everywhere:

```
// At top of functions:
auto _pt = PerfTrail::instance();
_pt && _pt->start("my-operation");

// At end of functions (or use RAII/scoped guard):
_pt && _pt->end("my-operation");
```

In languages with RAII (C++, Rust, D), create a `ScopedSpan` class:

```cpp
class ScopedSpan {
    PerfTrail* pt;
    std::string label;
public:
    ScopedSpan(PerfTrail* pt, std::string label) : pt(pt), label(std::move(label)) {
        if (pt) pt->start(this->label);
    }
    ~ScopedSpan() {
        if (pt) pt->end(label);
    }
};

// Usage:
void calculateChart() {
    ScopedSpan span(PerfTrail::instance(), "calculateChart");
    // ... work ...
} // auto-end on scope exit
```

### 10.6 Configuration File Integration (Example)

Instead of URL params and localStorage, use your project's config:

```yaml
# config/debug.yaml
performance_trail:
  enabled: true              # Master switch
  budgets:                   # Per-label thresholds (ms)
    calculateChart: 5000
    updateAllSystems: 2000
    animation_frame: 33
  throttle:
    default: 500             # ms between logs for any span
    animation_frame: 3000    # special throttle for high-frequency spans
    overbudget: 1000         # throttle for over-budget warnings
  history_max: 200           # ring buffer cap
  auto_enable: dev           # "dev", "always", "never", "config"
```

Your `autoEnable()` reads this config file instead of URL/localStorage.

### 10.7 Testing the Port

After porting, verify:

1. **Disabled cost**: With `_enabled = false`, instrumented functions should have no measurable overhead.
2. **Aggregation accuracy**: Run `calculateChart` 10 times, call `report()`, verify min/max/avg are correct.
3. **Throttle behavior**: Spam `end('test', ...)` 1000 times in a loop. Console should show ~2-5 outputs, not 1000.
4. **Over-budget surfacing**: Set budget to 1ms, run a 50ms operation. ⚠️ must appear.
5. **History cap**: Push 500 entries. Verify `_history.length <= 200`.
6. **Nested spans**: Start A, start B, end B, end A — no cross-contamination.
7. **Reset**: Call `reset()`, verify all state is cleared.
8. **Dual-publish**: Verify both your debug system and the perf output channel receive data.

---

## 11. Quick-Reference: File & Line Map

| What | Where |
|------|-------|
| Full source | `js/performance-trail.js` (1-370) |
| IIFE structure | Lines 20-368 |
| State declarations | Lines 25-43 |
| `start()` | Lines 67-73 |
| `end()` | Lines 75-159 |
| `wrap()` | Lines 161-173 |
| `error()` | Lines 175-205 |
| `checkpoint()` | Lines 207-219 |
| `tick()` / `fps()` | Lines 221-242 |
| `report()` | Lines 244-263 |
| `dump()` | Lines 265-282 |
| `reset()` | Lines 284-291 |
| Auto-enable logic | Lines 293-319 |
| Default budgets | Lines 321-355 |
| Global export | Lines 357-368 |
| Script tag in HTML | `index.html` line 7626 |
| Key call site: `calculateChart` | `js/app.js` line 9732 (start), 10208 (end) |
| Key call site: `updateAllSystems` | `js/app.js` line 7497 (start), 7508 (end) |
| Key call site: `updatePlanetInfo` | `js/app.js` line 10516 (start), 11965 (end) |
| Key call site: `animation-frame` | `js/3d-visualization.js` line 26553 (tick), 26554 (start), 26974 (end) |
| Usage notes (repo memory) | `/memories/repo/performance-trail-usage.md` |

---

## 12. Summary for the Reconstructing AI

You are building a **timing-and-error-enrichment singleton** that:

1. Has a boolean master gate (`_enabled`).
2. Tracks spans via `start(label)` / `end(label)` using a high-res monotonic clock.
3. Accumulates per-label stats (count, total, min, max, last) — always, even when output is suppressed.
4. Maintains a bounded history ring buffer.
5. Throttles output per-label to prevent log flooding.
6. Surfaces over-budget spans with priority (dedicated throttle, always visible).
7. Enriches errors with structured key=value context.
8. Has zero measurable overhead when disabled.
9. Routes output to TWO sinks: your project's main debug system AND a dedicated performance log channel.
10. Auto-enables in dev environments, disables in production, overridable by config.

**The soul of the system is the throttle.** Without it, a per-frame span would produce 60 console
writes per second and destroy performance. The throttle decouples the instrumentation density from
the output density — you can instrument every frame, every loop iteration, every function call,
and still get clean, readable output.

**Adapt the output formatting to your debug system's conventions.** The browser version uses
`console.error()` with `%c` CSS styling to exploit the browser's Error filter. Your version
should use whatever mechanism your debug system provides for severity-filtered, color-coded output.
If your debug system supports structured logging natively, pass context objects as structured data
rather than stringifying them.
