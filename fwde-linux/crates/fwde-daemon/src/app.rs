use std::path::Path;

use anyhow::Result;
use fwde_backend::{apply_move_plans, BackendSnapshot, WindowBackend};
use fwde_core::{
    legacy_params::load_user_parameter_settings, legacy_runtime::update_window_states,
    LegacyConfig, LegacyEngine, LegacySimulationStats,
};
use tracing::{info, warn};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LoopConfig {
    pub max_ticks: usize,
}

impl Default for LoopConfig {
    fn default() -> Self {
        Self { max_ticks: 1 }
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct TickResult {
    pub stats: LegacySimulationStats,
    pub planned_moves: usize,
    pub applied_moves: usize,
}

pub struct FwdeApp<B: WindowBackend> {
    engine: LegacyEngine,
    backend: B,
}

impl<B: WindowBackend> FwdeApp<B> {
    pub fn new(config: LegacyConfig, backend: B) -> Self {
        Self {
            engine: LegacyEngine::new(config),
            backend,
        }
    }

    pub fn load_config_file(&mut self, path: &Path) -> Result<usize> {
        let changes = load_user_parameter_settings(path, &mut self.engine.config)?;
        Ok(changes)
    }

    pub fn run(&mut self, loop_config: LoopConfig) -> Result<Vec<TickResult>> {
        let mut results = Vec::new();
        for _ in 0..loop_config.max_ticks.max(1) {
            match self.run_tick() {
                Ok(result) => results.push(result),
                Err(error) => {
                    warn!(%error, backend = self.backend.backend_name(), "tick failed");
                    return Err(error);
                }
            }
        }
        Ok(results)
    }

    pub fn run_tick(&mut self) -> Result<TickResult> {
        let snapshot = self.backend.capture_snapshot()?;
        let result = self.process_snapshot(snapshot)?;
        Ok(result)
    }

    fn process_snapshot(&mut self, snapshot: BackendSnapshot) -> Result<TickResult> {
        update_window_states(
            &mut self.engine,
            snapshot.windows,
            snapshot.outputs,
            snapshot
                .pointer_position
                .map(|pointer| (pointer.x, pointer.y)),
            snapshot.timestamp_ms,
        );
        self.engine.state.active_window = snapshot.focused_window;

        let stats = self.engine.calculate_dynamic_layout(snapshot.timestamp_ms);
        let plans = self.engine.apply_window_movements();
        let windows = self
            .engine
            .state
            .windows
            .iter()
            .cloned()
            .map(|window| window.into())
            .collect::<Vec<_>>();
        let applied_moves = apply_move_plans(&mut self.backend, &windows, &plans)?;

        info!(
            backend = self.backend.backend_name(),
            tracked = stats.tracked_windows,
            overlaps = stats.overlap_pairs,
            planned_moves = plans.len(),
            applied_moves,
            "processed fwde tick"
        );

        Ok(TickResult {
            stats,
            planned_moves: plans.len(),
            applied_moves,
        })
    }
}

impl From<fwde_core::LegacyManagedWindow> for fwde_core::WindowState {
    fn from(window: fwde_core::LegacyManagedWindow) -> Self {
        fwde_core::WindowState::new(fwde_core::WindowInfo {
            id: window.hwnd,
            title: window.title,
            app_id: window.app_id,
            class_name: window.class_name,
            process_name: window.process_name,
            pid: None,
            output: window.monitor,
            frame: fwde_core::Rect::new(window.x, window.y, window.width, window.height),
            floating: window.floating,
            fullscreen: window.fullscreen,
            minimized: window.minimized,
            pinned: window.manual_lock_until_ms.is_some(),
            visible: window.visible,
            urgent: false,
            workspace: None,
            role: None,
            window_type: None,
            is_popup: window.popup,
            has_caption: window.has_caption,
            is_tool_window: window.tool_window,
        })
    }
}
