use std::collections::HashMap;

use crate::{
    geometry::Vec2,
    legacy_config::LegacyConfig,
    legacy_engine::{LegacyEngine, WindowMovePlan},
    legacy_rules::{
        clamp, find_best_position, get_seeded_diagonal_offset, is_plugin_window, lerp,
    },
    legacy_types::{LegacyManagedWindow, LegacyMonitor, LegacyRuntimeState, ManualWindowMarker},
    model::{OutputInfo, WindowInfo},
};

#[derive(Debug, Clone, Default, PartialEq)]
pub struct TooltipMessage {
    pub text: String,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct BlurBehindStruct {
    pub enable: bool,
    pub region: Option<u64>,
    pub transition_on_maximized: bool,
}

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct WindowSnapshot {
    pub hwnd: u64,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

pub fn is_dropdown_or_menu_window(window: &LegacyManagedWindow) -> bool {
    let class_name = window.class_name.clone().unwrap_or_default().to_lowercase();
    let title = window.title.to_lowercase();
    let menu_classes = [
        "#32768",
        "dv2controlhost",
        "dropdown",
        "combolbox",
        "menu",
        "popup",
        "contextmenu",
    ];

    if menu_classes
        .iter()
        .any(|pattern| class_name.contains(pattern))
    {
        return true;
    }

    window.popup
        && !window.has_caption
        && window.tool_window
        && title.is_empty()
        && window.width < 600.0
        && window.height < 600.0
}

pub fn get_open_dropdown_menu_parent(windows: &[LegacyManagedWindow]) -> Option<u64> {
    windows
        .iter()
        .find(|window| is_dropdown_or_menu_window(window))
        .map(|window| window.hwnd)
}

pub fn acquire_high_res_timer(state: &mut LegacyRuntimeState) {
    state.internal_move_depth = state.internal_move_depth.saturating_add(1);
}

pub fn release_high_res_timer(state: &mut LegacyRuntimeState) {
    state.internal_move_depth = state.internal_move_depth.saturating_sub(1);
}

pub fn get_dragged_managed_window(
    state: &LegacyRuntimeState,
    hovered_hwnd: Option<u64>,
    left_button_pressed: bool,
) -> Option<u64> {
    if !left_button_pressed {
        return None;
    }

    hovered_hwnd.filter(|hwnd| state.windows.iter().any(|window| window.hwnd == *hwnd))
}

pub fn safe_win_exist(window: Option<&WindowInfo>) -> bool {
    window.is_some()
}

pub fn safe_monitor_get(
    outputs: &[LegacyMonitor],
    monitor_number: Option<u32>,
) -> Option<LegacyMonitor> {
    monitor_number
        .and_then(|number| {
            outputs
                .iter()
                .find(|monitor| monitor.number == number)
                .cloned()
        })
        .or_else(|| outputs.iter().find(|monitor| monitor.primary).cloned())
        .or_else(|| outputs.first().cloned())
}

pub fn safe_monitor_get_work_area(
    outputs: &[LegacyMonitor],
    monitor_number: Option<u32>,
) -> Option<LegacyMonitor> {
    safe_monitor_get(outputs, monitor_number)
}

pub fn monitor_get_from_point(outputs: &[LegacyMonitor], x: f64, y: f64) -> Option<u32> {
    outputs
        .iter()
        .find(|monitor| {
            x >= monitor.left && x < monitor.right && y >= monitor.top && y < monitor.bottom
        })
        .map(|monitor| monitor.number)
}

pub fn is_fullscreen_window(window: &LegacyManagedWindow, outputs: &[LegacyMonitor]) -> bool {
    if window.fullscreen {
        return true;
    }

    let class_name = window.class_name.clone().unwrap_or_default();
    let process_name = window
        .process_name
        .clone()
        .unwrap_or_default()
        .to_lowercase();
    let manageable_classes = [
        "MozillaWindowClass",
        "Chrome_WidgetWin_1",
        "ApplicationFrameWindow",
        "SunAwtFrame",
        "Notepad",
        "Notepad++",
        "Code.exe",
        "Cursor.exe",
        "devenv.exe",
        "XamlExplorerHost",
        "CabinetWClass",
        "WorkerW",
        "Progman",
    ];
    if manageable_classes
        .iter()
        .any(|pattern| class_name.eq_ignore_ascii_case(pattern))
    {
        return false;
    }

    let manageable_processes = [
        "firefox.exe",
        "chrome.exe",
        "msedge.exe",
        "code.exe",
        "cursor.exe",
        "notepad.exe",
        "notepad++.exe",
        "devenv.exe",
        "explorer.exe",
        "winword.exe",
        "excel.exe",
        "powerpnt.exe",
        "outlook.exe",
    ];
    if manageable_processes
        .iter()
        .any(|pattern| process_name.contains(pattern.trim_end_matches(".exe")))
    {
        return false;
    }

    let fullscreen_classes = [
        "UnityWndClass",
        "UnrealWindow",
        "Valve001",
        "SDL_app",
        "GLUT",
        "d3d",
        "D3D",
    ];
    if fullscreen_classes
        .iter()
        .any(|pattern| class_name.eq_ignore_ascii_case(pattern))
    {
        return true;
    }

    let fullscreen_processes = [
        "steam",
        "vlc",
        "mpc-hc",
        "potplayer",
        "obs64",
        "obs32",
        "streamlabs obs",
    ];
    if fullscreen_processes
        .iter()
        .any(|pattern| process_name.contains(pattern))
    {
        return true;
    }

    let Some(monitor) = safe_monitor_get(outputs, Some(window.monitor)) else {
        return false;
    };
    let tolerance = 50.0;
    let covers_width = window.width >= monitor.width - tolerance;
    let covers_height = window.height >= monitor.height - tolerance;
    let at_origin = window.x <= monitor.left + tolerance && window.y <= monitor.top + tolerance;
    covers_width
        && covers_height
        && at_origin
        && (!window.has_caption
            || window.title.to_lowercase().contains("full screen")
            || window.title.to_lowercase().contains("fullscreen"))
}

pub fn is_window_valid(window: &LegacyManagedWindow, outputs: &[LegacyMonitor]) -> bool {
    if is_fullscreen_window(window, outputs) {
        return false;
    }
    if window.minimized {
        return false;
    }
    if window.title.is_empty() || window.title == "Program Manager" {
        return false;
    }
    window.visible && !window.tool_window
}

pub fn show_tooltip(text: impl Into<String>) -> TooltipMessage {
    TooltipMessage { text: text.into() }
}

pub fn get_current_monitor_info(
    outputs: &[LegacyMonitor],
    pointer: Option<(f64, f64)>,
) -> Option<LegacyMonitor> {
    if let Some((x, y)) = pointer {
        let number = monitor_get_from_point(outputs, x, y);
        safe_monitor_get(outputs, number)
    } else {
        outputs
            .iter()
            .find(|monitor| monitor.primary)
            .cloned()
            .or_else(|| outputs.first().cloned())
    }
}

pub fn get_primary_monitor_coordinates(outputs: &[LegacyMonitor]) -> Option<LegacyMonitor> {
    outputs
        .iter()
        .find(|monitor| monitor.primary)
        .cloned()
        .or_else(|| outputs.first().cloned())
}

pub fn get_virtual_desktop_bounds(outputs: &[LegacyMonitor]) -> Option<LegacyMonitor> {
    if outputs.is_empty() {
        return None;
    }
    let left = outputs
        .iter()
        .map(|monitor| monitor.left)
        .fold(f64::MAX, f64::min);
    let right = outputs
        .iter()
        .map(|monitor| monitor.right)
        .fold(f64::MIN, f64::max);
    let top = outputs
        .iter()
        .map(|monitor| monitor.top)
        .fold(f64::MAX, f64::min);
    let bottom = outputs
        .iter()
        .map(|monitor| monitor.bottom)
        .fold(f64::MIN, f64::max);
    Some(LegacyMonitor {
        left,
        right,
        top,
        bottom,
        width: right - left,
        height: bottom - top,
        number: 0,
        center_x: (right + left) / 2.0,
        center_y: (bottom + top) / 2.0,
        name: "virtual".to_string(),
        primary: false,
    })
}

pub fn find_non_overlapping_position(
    window: &LegacyManagedWindow,
    other_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
    config: &LegacyConfig,
) -> Option<Vec2> {
    let positioned = find_best_position(window, other_windows, monitor, config);
    if positioned.is_some() {
        return positioned;
    }

    let offset = get_seeded_diagonal_offset(window, config);
    Some(Vec2::new(
        clamp(
            window.x + offset.x,
            monitor.left + config.min_margin,
            monitor.right - window.width - config.min_margin,
        ),
        clamp(
            window.y + offset.y,
            monitor.top + config.min_margin,
            monitor.bottom - window.height - config.min_margin,
        ),
    ))
}

pub fn create_blur_behind_struct() -> BlurBehindStruct {
    BlurBehindStruct {
        enable: true,
        region: None,
        transition_on_maximized: false,
    }
}

pub fn apply_stabilization(
    window: &mut LegacyManagedWindow,
    config: &LegacyConfig,
    history: &mut Vec<Vec2>,
) {
    history.push(Vec2::new(window.vx, window.vy));
    if history.len() > 5 {
        history.remove(0);
    }
    let avg_vx = history.iter().map(|sample| sample.x).sum::<f64>() / history.len().max(1) as f64;
    let avg_vy = history.iter().map(|sample| sample.y).sum::<f64>() / history.len().max(1) as f64;
    let avg_speed = (avg_vx * avg_vx + avg_vy * avg_vy).sqrt();

    if avg_speed < config.stabilization.min_speed_threshold * 2.0 {
        let t = (avg_speed / (config.stabilization.min_speed_threshold * 2.0)).min(1.0);
        let stability_factor = ease_out_cubic(t);
        let current_damping = lerp(
            config.damping - config.stabilization.damping_boost,
            config.damping,
            stability_factor,
        );
        window.vx *= current_damping;
        window.vy *= current_damping;
        if avg_speed < 0.1 {
            let stop_factor = ease_out_cubic(avg_speed / 0.1);
            window.vx *= stop_factor;
            window.vy *= stop_factor;
        }
    } else {
        window.vx *= config.damping;
        window.vy *= config.damping;
    }

    if avg_speed < 0.05
        && (window.x - window.target_x).abs() < 0.5
        && (window.y - window.target_y).abs() < 0.5
    {
        window.x = window.target_x;
        window.y = window.target_y;
        window.vx = 0.0;
        window.vy = 0.0;
    }
}

pub fn bezier3(p0: f64, p1: f64, p2: f64, p3: f64, t: f64) -> f64 {
    let a = lerp(p0, p1, t);
    let b = lerp(p1, p2, t);
    let c = lerp(p2, p3, t);
    let d = lerp(a, b, t);
    let e = lerp(b, c, t);
    lerp(d, e, t)
}

pub fn smooth_step(t: f64) -> f64 {
    t * t * (3.0 - 2.0 * t)
}

pub fn calculate_future_overlap(
    window: &LegacyManagedWindow,
    x: f64,
    y: f64,
    other_windows: &[LegacyManagedWindow],
) -> f64 {
    let mut overlap_score = 0.0;
    for other in other_windows {
        if other.hwnd == window.hwnd {
            continue;
        }
        let overlap_x = (x + window.width).min(other.x + other.width) - x.max(other.x);
        let overlap_y = (y + window.height).min(other.y + other.height) - y.max(other.y);
        overlap_score +=
            overlap_x.max(0.0) * overlap_y.max(0.0) / (window.width * window.height).max(1.0);
    }
    overlap_score
}

pub fn atan2(y: f64, x: f64) -> f64 {
    y.atan2(x)
}

pub fn resolve_collisions(
    positions: &mut [LegacyManagedWindow],
    outputs: &[LegacyMonitor],
    config: &LegacyConfig,
) {
    let max_iterations = 8;
    let mut changed = true;
    let mut iterations = 0;

    while changed && iterations < max_iterations {
        changed = false;
        iterations += 1;

        for i in 0..positions.len() {
            let Some(monitor) = safe_monitor_get_work_area(outputs, Some(positions[i].monitor))
            else {
                continue;
            };
            let new_x = clamp(
                positions[i].x,
                monitor.left + config.min_margin,
                monitor.right - positions[i].width - config.min_margin,
            );
            let new_y = clamp(
                positions[i].y,
                monitor.top + config.min_margin,
                monitor.bottom - positions[i].height - config.min_margin,
            );
            if new_x != positions[i].x || new_y != positions[i].y {
                positions[i].x = new_x;
                positions[i].y = new_y;
                changed = true;
            }

            for j in 0..positions.len() {
                if i == j {
                    continue;
                }
                let overlap_x = (positions[i].x + positions[i].width)
                    .min(positions[j].x + positions[j].width)
                    - positions[i].x.max(positions[j].x);
                let overlap_y = (positions[i].y + positions[i].height)
                    .min(positions[j].y + positions[j].height)
                    - positions[i].y.max(positions[j].y);
                if overlap_x > config.stabilization.overlap_tolerance
                    && overlap_y > config.stabilization.overlap_tolerance
                {
                    let dx = (positions[i].x + positions[i].width / 2.0)
                        - (positions[j].x + positions[j].width / 2.0);
                    let dy = (positions[i].y + positions[i].height / 2.0)
                        - (positions[j].y + positions[j].height / 2.0);
                    let dist = (dx * dx + dy * dy).sqrt().max(1.0);
                    let push = (overlap_x + overlap_y) / 8.0;
                    positions[i].x += dx * push / dist * 0.12;
                    positions[i].y += dy * push / dist * 0.12;
                    positions[j].x -= dx * push / dist * 0.12;
                    positions[j].y -= dy * push / dist * 0.12;
                    changed = true;
                }
            }
        }
    }
}

pub fn add_manual_window_border(state: &mut LegacyRuntimeState, hwnd: u64, expire_at_ms: u64) {
    state
        .manual_windows
        .insert(hwnd, ManualWindowMarker { expire_at_ms });
}

pub fn remove_manual_window_border(state: &mut LegacyRuntimeState, hwnd: u64) {
    state.manual_windows.remove(&hwnd);
}

pub fn update_manual_borders(state: &mut LegacyRuntimeState, now_ms: u64) {
    state
        .manual_windows
        .retain(|_, marker| marker.expire_at_ms > now_ms);
}

pub fn clear_manual_flags(state: &mut LegacyRuntimeState, now_ms: u64) {
    let expired: Vec<u64> = state
        .manual_windows
        .iter()
        .filter_map(|(hwnd, marker)| (marker.expire_at_ms <= now_ms).then_some(*hwnd))
        .collect();

    for hwnd in expired {
        if let Some(window) = state.windows.iter_mut().find(|window| window.hwnd == hwnd) {
            window.lock_lost_at_ms = Some(now_ms);
            window.manual_lock_until_ms = None;
            window.is_manual = false;
        }
        state.manual_windows.remove(&hwnd);
    }
}

pub fn drag_window(
    engine: &mut LegacyEngine,
    hwnd: u64,
    current_mouse: (f64, f64),
    final_mouse: (f64, f64),
    now_ms: u64,
) -> Option<WindowMovePlan> {
    let index = engine
        .state
        .windows
        .iter()
        .position(|window| window.hwnd == hwnd)?;
    let window = &mut engine.state.windows[index];
    engine.state.active_window = Some(hwnd);
    engine.state.last_user_move_ms = now_ms;

    let offset_x = current_mouse.0 - window.x;
    let offset_y = current_mouse.1 - window.y;
    let Some(monitor) = safe_monitor_get(&engine.state.outputs, Some(window.monitor)) else {
        return None;
    };

    let new_x = clamp(
        final_mouse.0 - offset_x,
        monitor.left + engine.config.min_margin,
        monitor.right - window.width - engine.config.min_margin,
    );
    let new_y = clamp(
        final_mouse.1 - offset_y,
        monitor.top + engine.config.min_margin,
        monitor.bottom - window.height - engine.config.min_margin,
    );
    window.x = new_x;
    window.y = new_y;
    window.target_x = new_x;
    window.target_y = new_y;
    window.vx = 0.0;
    window.vy = 0.0;
    window.last_move_ms = now_ms;
    window.just_dragged_at_ms = Some(now_ms);
    window.manual_lock_until_ms = Some(now_ms + engine.config.manual_lock_duration_ms);
    add_manual_window_border(
        &mut engine.state,
        hwnd,
        now_ms + engine.config.manual_lock_duration_ms,
    );

    Some(WindowMovePlan {
        hwnd,
        x: new_x,
        y: new_y,
    })
}

pub fn window_move_handler(
    engine: &mut LegacyEngine,
    hwnd: u64,
    new_frame: WindowSnapshot,
    now_ms: u64,
) {
    if let Some(window) = engine
        .state
        .windows
        .iter_mut()
        .find(|window| window.hwnd == hwnd)
    {
        window.x = new_frame.x;
        window.y = new_frame.y;
        window.width = new_frame.width;
        window.height = new_frame.height;
        window.last_move_ms = now_ms;
        window.vx = 0.0;
        window.vy = 0.0;
        window.manual_lock_until_ms = Some(now_ms + engine.config.manual_lock_duration_ms);
        window.is_manual = true;
        engine.state.active_window = Some(hwnd);
        engine.state.last_user_move_ms = now_ms;
        engine.state.snap_in_progress.insert(hwnd, now_ms + 2_000);
        add_manual_window_border(
            &mut engine.state,
            hwnd,
            now_ms + engine.config.manual_lock_duration_ms,
        );
    }
}

pub fn window_size_handler(
    engine: &mut LegacyEngine,
    hwnd: u64,
    new_frame: WindowSnapshot,
    now_ms: u64,
) {
    window_move_handler(engine, hwnd, new_frame, now_ms);
}

pub fn update_window_states(
    engine: &mut LegacyEngine,
    windows: Vec<WindowInfo>,
    outputs: Vec<OutputInfo>,
    pointer: Option<(f64, f64)>,
    now_ms: u64,
) {
    engine.sync_outputs(&outputs);
    engine.state.monitor = if engine.config.multimonitor_expanse {
        get_virtual_desktop_bounds(&engine.state.outputs)
    } else {
        get_current_monitor_info(&engine.state.outputs, pointer)
    };
    engine.update_window_states_from_backend(windows, now_ms);
    update_manual_borders(&mut engine.state, now_ms);
    clear_manual_flags(&mut engine.state, now_ms);
}

pub fn move_window_api(
    hwnd: u64,
    x: f64,
    y: f64,
    w: Option<f64>,
    h: Option<f64>,
) -> WindowMovePlan {
    let _ = (w, h);
    WindowMovePlan { hwnd, x, y }
}

pub fn partition_windows(
    windows: &[LegacyManagedWindow],
    partition_grid_size: f64,
) -> HashMap<(i64, i64), Vec<u64>> {
    let mut buckets = HashMap::new();
    for window in windows {
        let gx = (window.x / partition_grid_size).floor() as i64;
        let gy = (window.y / partition_grid_size).floor() as i64;
        buckets
            .entry((gx, gy))
            .or_insert_with(Vec::new)
            .push(window.hwnd);
    }
    buckets
}

pub fn is_daw_plugin(window: &LegacyManagedWindow) -> bool {
    is_plugin_window(window)
}

pub fn is_electron_app(window: &LegacyManagedWindow) -> bool {
    let class_name = window.class_name.clone().unwrap_or_default();
    let process_name = window
        .process_name
        .clone()
        .unwrap_or_default()
        .to_lowercase();
    let electron_classes = [
        "Chrome_WidgetWin_1",
        "Chrome_WidgetWin_0",
        "ElectronMainWindow",
        "CEF-OSC-WIDGET",
    ];
    let electron_processes = [
        "cursor", "code", "discord", "slack", "spotify", "whatsapp", "telegram", "notion",
        "obsidian", "typora", "hyper",
    ];
    electron_classes
        .iter()
        .any(|pattern| class_name.eq_ignore_ascii_case(pattern))
        || electron_processes
            .iter()
            .any(|pattern| process_name.contains(pattern))
}

fn ease_out_cubic(t: f64) -> f64 {
    1.0 - (1.0 - t).powi(3)
}
