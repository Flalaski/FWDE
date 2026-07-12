use std::env;

use fwde_core::{OutputInfo, Rect, WindowInfo};

use crate::{replay::ReplayBackend, BackendError, BackendEvent, BackendSnapshot, WindowBackend};

#[derive(Debug, Default)]
pub struct X11Backend {
    replay: Option<ReplayBackend>,
}

impl X11Backend {
    pub fn new() -> Self {
        let replay = env::var("FWDE_SNAPSHOT_PATH").ok().map(ReplayBackend::new);
        Self { replay }
    }
}

impl WindowBackend for X11Backend {
    fn backend_name(&self) -> &'static str {
        if self.replay.is_some() {
            "x11-replay"
        } else {
            "x11"
        }
    }

    fn capture_snapshot(&mut self) -> Result<BackendSnapshot, BackendError> {
        if let Some(replay) = &mut self.replay {
            return replay.capture_snapshot();
        }

        Err(BackendError::Unavailable(
            "X11 capture is not implemented yet; set FWDE_SNAPSHOT_PATH to drive the daemon with recorded snapshots".into(),
        ))
    }

    fn list_windows(&mut self) -> Result<Vec<WindowInfo>, BackendError> {
        if let Some(replay) = &mut self.replay {
            return replay.list_windows();
        }

        Err(BackendError::Unavailable(
            "X11 integration is not implemented yet".into(),
        ))
    }

    fn list_outputs(&mut self) -> Result<Vec<OutputInfo>, BackendError> {
        if let Some(replay) = &mut self.replay {
            return replay.list_outputs();
        }

        Err(BackendError::Unavailable(
            "X11 integration is not implemented yet".into(),
        ))
    }

    fn move_window(&mut self, id: u64, frame: Rect) -> Result<(), BackendError> {
        if let Some(replay) = &mut self.replay {
            return replay.move_window(id, frame);
        }

        Err(BackendError::Unavailable(
            "X11 integration is not implemented yet".into(),
        ))
    }

    fn poll_events(&mut self) -> Result<Vec<BackendEvent>, BackendError> {
        if let Some(replay) = &mut self.replay {
            return replay.poll_events();
        }

        Ok(vec![BackendEvent::Tick])
    }
}
