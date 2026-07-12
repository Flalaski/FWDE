Cold transliteration coverage map

AHK sections now represented in Rust modules:
- Core physics and orchestration: legacy_engine.rs
- Helper rules and packing logic: legacy_rules.rs
- Runtime/window handler helpers: legacy_runtime.rs
- Parameter persistence and settings model: legacy_params.rs
- Debug/menu/taskbar scaffolding: legacy_debug.rs
- Config/state/window mirrors: legacy_config.rs and legacy_types.rs

Backend gaps intentionally left Linux-specific:
- Real X11/Wayland event subscription
- Real global hotkeys
- Real taskbar integration
- Real menu/dropdown ownership detection beyond metadata heuristics
- Real move/resize backend application
