use crate::{
    legacy_config::LegacyConfig,
    legacy_engine::LegacyEngine,
    legacy_runtime::TooltipMessage,
    legacy_types::{LegacyManagedWindow, LegacyRuntimeState},
};

#[derive(Debug, Clone, PartialEq)]
pub struct MenuItem {
    pub label: String,
    pub enabled: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct MenuModel {
    pub main_items: Vec<MenuItem>,
    pub debug_items: Vec<MenuItem>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskbarRect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

pub fn status_text(is_enabled: bool) -> &'static str {
    if is_enabled {
        "enabled"
    } else {
        "disabled"
    }
}

pub fn get_window_lock_status_text(
    state: &LegacyRuntimeState,
    focused_hwnd: Option<u64>,
    now_ms: u64,
) -> &'static str {
    let Some(hwnd) = focused_hwnd else {
        return "n/a";
    };

    match state.windows.iter().find(|window| window.hwnd == hwnd) {
        Some(window)
            if window
                .manual_lock_until_ms
                .map(|expiry| now_ms < expiry)
                .unwrap_or(false) =>
        {
            "enabled"
        }
        Some(_) => "disabled",
        None => "n/a",
    }
}

pub fn build_fwde_menus(
    state: &LegacyRuntimeState,
    config: &LegacyConfig,
    debug_mode: bool,
    focused_hwnd: Option<u64>,
    now_ms: u64,
) -> MenuModel {
    let arrangement_status = status_text(state.arrangement_active);
    let physics_status = status_text(state.physics_enabled);
    let expanse_status = status_text(config.multimonitor_expanse);
    let debug_status = status_text(debug_mode);
    let lock_status = get_window_lock_status_text(state, focused_hwnd, now_ms);

    let main_items = vec![
        MenuItem {
            label: format!("Toggle Arrangement [{arrangement_status}]"),
            enabled: true,
        },
        MenuItem {
            label: "Optimize Windows".to_string(),
            enabled: true,
        },
        MenuItem {
            label: format!("Toggle Physics [{physics_status}]"),
            enabled: true,
        },
        MenuItem {
            label: format!("Toggle Multimonitor Expanse [{expanse_status}]"),
            enabled: true,
        },
        MenuItem {
            label: format!("Toggle Window Lock [{lock_status}]"),
            enabled: true,
        },
        MenuItem {
            label: "Parameter Settings".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Save Settings".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Load Settings".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Restart FWDE".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Exit".to_string(),
            enabled: true,
        },
    ];

    let debug_items = vec![
        MenuItem {
            label: format!("Toggle Debug Mode [{debug_status}]"),
            enabled: true,
        },
        MenuItem {
            label: "Debug Window Info".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Debug Active Window".to_string(),
            enabled: true,
        },
        MenuItem {
            label: "Force Add Active Window".to_string(),
            enabled: true,
        },
    ];

    MenuModel {
        main_items,
        debug_items,
    }
}

pub fn restart_fwde() -> &'static str {
    "reload"
}

pub fn show_taskbar_menu() -> TooltipMessage {
    TooltipMessage {
        text: "ShowTaskbarMenu".to_string(),
    }
}

pub fn get_taskbar_rect(outputs: &[crate::legacy_types::LegacyMonitor]) -> Option<TaskbarRect> {
    let primary = outputs
        .iter()
        .find(|monitor| monitor.primary)
        .or_else(|| outputs.first())?;
    Some(TaskbarRect {
        x: primary.left,
        y: primary.bottom - 40.0,
        width: primary.width,
        height: 40.0,
    })
}

pub fn toggle_debug_mode(debug_mode: &mut bool) {
    *debug_mode = !*debug_mode;
}

pub fn debug_window_info(state: &LegacyRuntimeState) -> String {
    let mut lines = vec![format!("Tracked windows: {}", state.windows.len())];
    for window in &state.windows {
        lines.push(describe_window(window));
    }
    lines.join("\n")
}

pub fn force_add_active_window(engine: &mut LegacyEngine, active_window: LegacyManagedWindow) {
    if engine
        .state
        .windows
        .iter()
        .all(|window| window.hwnd != active_window.hwnd)
    {
        engine.state.windows.push(active_window);
    }
}

pub fn debug_active_window(state: &LegacyRuntimeState, active_hwnd: Option<u64>) -> String {
    let Some(hwnd) = active_hwnd else {
        return "No active window".to_string();
    };
    match state.windows.iter().find(|window| window.hwnd == hwnd) {
        Some(window) => describe_window(window),
        None => format!("Window {hwnd} is not currently managed"),
    }
}

pub fn on_exit(state: &mut LegacyRuntimeState) {
    state.manual_windows.clear();
    state.internal_move_depth = 0;
}

fn describe_window(window: &LegacyManagedWindow) -> String {
    format!(
        "hwnd={} title={:?} class={:?} process={:?} pos=({}, {}) size=({}, {}) plugin={} floating={} locked={}",
        window.hwnd,
        window.title,
        window.class_name,
        window.process_name,
        window.x,
        window.y,
        window.width,
        window.height,
        window.is_plugin,
        window.floating,
        window.manual_lock_until_ms.is_some(),
    )
}
