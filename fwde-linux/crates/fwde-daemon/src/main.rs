use std::{env, path::PathBuf};

use anyhow::Result;
use fwde_backend::{x11::X11Backend, WindowBackend};
use fwde_core::LegacyConfig;
use tracing::{info, warn};

mod app;

use app::{FwdeApp, LoopConfig};

fn loop_config_from_env() -> LoopConfig {
    let max_ticks = env::var("FWDE_MAX_TICKS")
        .ok()
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(1);
    LoopConfig { max_ticks }
}

fn config_path_from_env() -> Option<PathBuf> {
    env::var("FWDE_CONFIG_PATH").ok().map(PathBuf::from)
}

fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .with_target(false)
        .compact()
        .init();

    let backend = X11Backend::new();
    let backend_name = backend.backend_name();
    let mut app = FwdeApp::new(LegacyConfig::default(), backend);
    let loop_config = loop_config_from_env();

    info!(backend = backend_name, "starting fwde-linux daemon");

    if let Some(config_path) = config_path_from_env() {
        match app.load_config_file(&config_path) {
            Ok(changes) => {
                info!(path = %config_path.display(), changes, "loaded FWDE config overrides")
            }
            Err(error) => {
                warn!(path = %config_path.display(), %error, "failed to load FWDE config overrides")
            }
        }
    }

    let results = app.run(loop_config)?;
    if let Some(last) = results.last() {
        info!(
            moved = last.stats.moved_windows,
            overlaps = last.stats.overlap_pairs,
            tracked = last.stats.tracked_windows,
            planned_moves = last.planned_moves,
            applied_moves = last.applied_moves,
            "fwde-linux daemon tick complete"
        );
    }

    Ok(())
}
