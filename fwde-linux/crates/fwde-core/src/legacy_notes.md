Initial cold transliteration layer:
- LegacyConfig mirrors AHK Config defaults.
- LegacyManagedWindow and LegacyRuntimeState mirror g["Windows"] and global g state.
- LegacyEngine keeps FWDE-style orchestration names: update_window_states_from_backend, calculate_dynamic_layout, apply_window_movements, optimize_window_positions, toggle_window_lock.
- legacy_rules.rs preserves helper-style functions from the AHK script for overlap, packing, plugin detection, and floating heuristics.
