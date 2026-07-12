use serde::{Deserialize, Serialize};

use crate::geometry::{Rect, Vec2};

pub type WindowId = u64;
pub type OutputId = u32;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EngineConfig {
    pub min_gap: f64,
    pub repulsion_force: f64,
    pub attraction_force: f64,
    pub damping: f64,
    pub max_speed: f64,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            min_gap: 8.0,
            repulsion_force: 0.18,
            attraction_force: 0.01,
            damping: 0.82,
            max_speed: 32.0,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutputInfo {
    pub id: OutputId,
    pub name: String,
    pub bounds: Rect,
    pub work_area: Rect,
    pub primary: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowInfo {
    pub id: WindowId,
    pub title: String,
    pub app_id: Option<String>,
    pub class_name: Option<String>,
    pub process_name: Option<String>,
    pub pid: Option<u32>,
    pub output: OutputId,
    pub frame: Rect,
    pub floating: bool,
    pub fullscreen: bool,
    pub minimized: bool,
    pub pinned: bool,
    pub visible: bool,
    pub urgent: bool,
    pub workspace: Option<String>,
    pub role: Option<String>,
    pub window_type: Option<String>,
    pub is_popup: bool,
    pub has_caption: bool,
    pub is_tool_window: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowState {
    pub info: WindowInfo,
    pub velocity: Vec2,
}

impl WindowState {
    pub fn new(info: WindowInfo) -> Self {
        Self {
            info,
            velocity: Vec2::default(),
        }
    }
}
