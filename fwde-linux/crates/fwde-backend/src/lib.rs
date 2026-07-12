pub mod replay;
pub mod x11;

use fwde_core::{OutputInfo, Rect, WindowInfo, WindowMovePlan, WindowState};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone)]
pub enum BackendEvent {
    WindowAdded(WindowInfo),
    WindowRemoved { id: u64 },
    WindowUpdated(WindowInfo),
    FocusChanged { id: Option<u64> },
    OutputLayoutChanged(Vec<OutputInfo>),
    PointerMoved { x: f64, y: f64 },
    Tick,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PointerPosition {
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct BackendSnapshot {
    pub outputs: Vec<OutputInfo>,
    pub windows: Vec<WindowInfo>,
    pub focused_window: Option<u64>,
    pub hovered_window: Option<u64>,
    pub pointer_position: Option<PointerPosition>,
    pub timestamp_ms: u64,
}

#[derive(Debug, Error)]
pub enum BackendError {
    #[error("backend is unavailable: {0}")]
    Unavailable(String),
    #[error("backend operation failed: {0}")]
    Operation(String),
}

pub trait WindowBackend {
    fn backend_name(&self) -> &'static str;
    fn capture_snapshot(&mut self) -> Result<BackendSnapshot, BackendError>;
    fn list_windows(&mut self) -> Result<Vec<WindowInfo>, BackendError>;
    fn list_outputs(&mut self) -> Result<Vec<OutputInfo>, BackendError>;
    fn move_window(&mut self, id: u64, frame: Rect) -> Result<(), BackendError>;
    fn poll_events(&mut self) -> Result<Vec<BackendEvent>, BackendError>;
}

pub fn apply_move_plans(
    backend: &mut dyn WindowBackend,
    windows: &[WindowState],
    moves: &[WindowMovePlan],
) -> Result<usize, BackendError> {
    let mut applied = 0;
    for planned in moves {
        let Some(window) = windows.iter().find(|window| window.info.id == planned.hwnd) else {
            continue;
        };

        let frame = Rect::new(
            planned.x,
            planned.y,
            window.info.frame.width,
            window.info.frame.height,
        );
        backend.move_window(planned.hwnd, frame)?;
        applied += 1;
    }
    Ok(applied)
}

pub fn managed_windows(all_windows: Vec<WindowInfo>) -> Vec<WindowState> {
    all_windows
        .into_iter()
        .filter(|window| window.floating && !window.fullscreen && !window.minimized)
        .map(WindowState::new)
        .collect()
}
