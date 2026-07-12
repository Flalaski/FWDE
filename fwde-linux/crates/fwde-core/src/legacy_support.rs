use crate::legacy_types::LegacyManagedWindow;

pub fn clone_map_deep<T: Clone>(value: &T) -> T {
    value.clone()
}

pub fn get_partition_grid_size() -> f64 {
    400.0
}

pub fn update_last_seen(window: &mut LegacyManagedWindow, now_ms: u64) {
    window.last_seen_ms = now_ms;
}
