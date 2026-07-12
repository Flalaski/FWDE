use std::{env, fs, path::PathBuf};

use fwde_core::{OutputInfo, Rect, WindowInfo};

use crate::{BackendError, BackendEvent, BackendSnapshot, WindowBackend};

#[derive(Debug, Clone)]
pub struct ReplayBackend {
    snapshot_path: PathBuf,
    applied_moves_path: Option<PathBuf>,
    last_snapshot: Option<BackendSnapshot>,
    applied_moves: Vec<(u64, Rect)>,
}

impl ReplayBackend {
    pub fn new(path: String) -> Self {
        Self {
            snapshot_path: PathBuf::from(path),
            applied_moves_path: env::var("FWDE_APPLIED_MOVES_PATH").ok().map(PathBuf::from),
            last_snapshot: None,
            applied_moves: Vec::new(),
        }
    }

    fn flush_applied_moves(&self) -> Result<(), BackendError> {
        let Some(path) = &self.applied_moves_path else {
            return Ok(());
        };

        let payload = self
            .applied_moves
            .iter()
            .map(|(id, frame)| {
                serde_json::json!({
                    "id": id,
                    "frame": {
                        "x": frame.x,
                        "y": frame.y,
                        "width": frame.width,
                        "height": frame.height
                    }
                })
            })
            .collect::<Vec<_>>();

        let json = serde_json::to_string_pretty(&payload).map_err(|error| {
            BackendError::Operation(format!(
                "failed to serialize applied moves for {}: {error}",
                path.display()
            ))
        })?;

        fs::write(path, json).map_err(|error| {
            BackendError::Operation(format!(
                "failed to write applied moves file {}: {error}",
                path.display()
            ))
        })
    }

    fn read_snapshot(&mut self) -> Result<BackendSnapshot, BackendError> {
        let raw = fs::read_to_string(&self.snapshot_path).map_err(|error| {
            BackendError::Operation(format!(
                "failed to read snapshot file {}: {error}",
                self.snapshot_path.display()
            ))
        })?;

        let snapshot = serde_json::from_str::<BackendSnapshot>(&raw).map_err(|error| {
            BackendError::Operation(format!(
                "failed to parse snapshot file {}: {error}",
                self.snapshot_path.display()
            ))
        })?;
        self.last_snapshot = Some(snapshot.clone());
        Ok(snapshot)
    }

    pub fn applied_moves(&self) -> &[(u64, Rect)] {
        &self.applied_moves
    }
}

impl WindowBackend for ReplayBackend {
    fn backend_name(&self) -> &'static str {
        "replay"
    }

    fn capture_snapshot(&mut self) -> Result<BackendSnapshot, BackendError> {
        self.read_snapshot()
    }

    fn list_windows(&mut self) -> Result<Vec<WindowInfo>, BackendError> {
        Ok(self.read_snapshot()?.windows)
    }

    fn list_outputs(&mut self) -> Result<Vec<OutputInfo>, BackendError> {
        Ok(self.read_snapshot()?.outputs)
    }

    fn move_window(&mut self, id: u64, frame: Rect) -> Result<(), BackendError> {
        self.applied_moves.push((id, frame));
        self.flush_applied_moves()?;
        Ok(())
    }

    fn poll_events(&mut self) -> Result<Vec<BackendEvent>, BackendError> {
        Ok(vec![BackendEvent::Tick])
    }
}
