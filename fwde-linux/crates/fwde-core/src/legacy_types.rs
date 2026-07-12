use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::{
    geometry::Rect,
    model::{OutputId, OutputInfo, WindowId, WindowInfo},
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LegacyMonitor {
    pub left: f64,
    pub right: f64,
    pub top: f64,
    pub bottom: f64,
    pub width: f64,
    pub height: f64,
    pub number: OutputId,
    pub center_x: f64,
    pub center_y: f64,
    pub name: String,
    pub primary: bool,
}

impl LegacyMonitor {
    pub fn from_output(output: &OutputInfo) -> Self {
        let work_area = output.work_area;
        Self {
            left: work_area.x,
            right: work_area.right(),
            top: work_area.y,
            bottom: work_area.bottom(),
            width: work_area.width,
            height: work_area.height,
            number: output.id,
            center_x: work_area.center().x,
            center_y: work_area.center().y,
            name: output.name.clone(),
            primary: output.primary,
        }
    }

    pub fn rect(&self) -> Rect {
        Rect::new(self.left, self.top, self.width, self.height)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ManualWindowMarker {
    pub expire_at_ms: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LegacyManagedWindow {
    pub hwnd: WindowId,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    pub area: f64,
    pub mass: f64,
    pub last_move_ms: u64,
    pub vx: f64,
    pub vy: f64,
    pub target_x: f64,
    pub target_y: f64,
    pub monitor: OutputId,
    pub is_plugin: bool,
    pub last_seen_ms: u64,
    pub manual_lock_until_ms: Option<u64>,
    pub is_manual: bool,
    pub just_dragged_at_ms: Option<u64>,
    pub lock_lost_at_ms: Option<u64>,
    pub title: String,
    pub class_name: Option<String>,
    pub process_name: Option<String>,
    pub app_id: Option<String>,
    pub visible: bool,
    pub tool_window: bool,
    pub popup: bool,
    pub has_caption: bool,
    pub floating: bool,
    pub fullscreen: bool,
    pub minimized: bool,
}

impl LegacyManagedWindow {
    pub fn from_window_info(window: WindowInfo, now_ms: u64) -> Self {
        let area = window.frame.width * window.frame.height;
        Self {
            hwnd: window.id,
            x: window.frame.x,
            y: window.frame.y,
            width: window.frame.width,
            height: window.frame.height,
            area,
            mass: area / 100_000.0,
            last_move_ms: 0,
            vx: 0.0,
            vy: 0.0,
            target_x: window.frame.x,
            target_y: window.frame.y,
            monitor: window.output,
            is_plugin: false,
            last_seen_ms: now_ms,
            manual_lock_until_ms: None,
            is_manual: false,
            just_dragged_at_ms: None,
            lock_lost_at_ms: None,
            title: window.title,
            class_name: window.class_name,
            process_name: window.process_name,
            app_id: window.app_id,
            visible: window.visible,
            tool_window: window.is_tool_window,
            popup: window.is_popup,
            has_caption: window.has_caption,
            floating: window.floating,
            fullscreen: window.fullscreen,
            minimized: window.minimized,
        }
    }

    pub fn rect(&self) -> Rect {
        Rect::new(self.x, self.y, self.width, self.height)
    }

    pub fn center(&self) -> (f64, f64) {
        (self.x + self.width / 2.0, self.y + self.height / 2.0)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LegacyRuntimeState {
    pub monitor: Option<LegacyMonitor>,
    pub outputs: Vec<LegacyMonitor>,
    pub arrangement_active: bool,
    pub last_user_move_ms: u64,
    pub active_window: Option<WindowId>,
    pub windows: Vec<LegacyManagedWindow>,
    pub physics_enabled: bool,
    pub snap_in_progress: HashMap<WindowId, u64>,
    pub manual_windows: HashMap<WindowId, ManualWindowMarker>,
    pub system_energy: f64,
    pub internal_move_depth: u32,
    pub last_internal_move_tick_ms: u64,
}

impl Default for LegacyRuntimeState {
    fn default() -> Self {
        Self {
            monitor: None,
            outputs: Vec::new(),
            arrangement_active: true,
            last_user_move_ms: 0,
            active_window: None,
            windows: Vec::new(),
            physics_enabled: true,
            snap_in_progress: HashMap::new(),
            manual_windows: HashMap::new(),
            system_energy: 1.0,
            internal_move_depth: 0,
            last_internal_move_tick_ms: 0,
        }
    }
}
