# Copilot Instructions for FWDE

## Project Overview
- FWDE is a sophisticated window layout and physics engine for Windows, focused on subtle, natural window management and plugin grouping (see memory-bank/systemPatterns.md).
- The core logic is in FWDE.ahk (AutoHotkey v2), with supporting architectural notes in memory-bank/.

## Key Architectural Patterns
- **Strategy Pattern**: Multiple bin-packing/layout algorithms are implemented as interchangeable strategies.
- **Genetic Algorithm**: Used for layout optimization, balancing overlap, accessibility, and user preference.
- **Observer/Command Patterns**: Layout changes and operations are event-driven and reversible.
- **Repository Pattern**: Layouts and session state are persisted in JSON, with versioning and migration support.
- **Plugin Grouping**: Windows are grouped by class/title/process, with leader-follower and group-specific physics.

## Developer Workflows
- Main script: FWDE.ahk (AutoHotkey v2.0 required)
- No build step; run directly with AHK v2 interpreter.
- Debugging: Use DebugMode global, and Ctrl+Alt+D hotkey for window info.
- Physics and arrangement are always active unless explicitly toggled (see ToggleArrangement/TogglePhysics functions).
- Layout and physics parameters are configured in the global Config map at the top of FWDE.ahk.

## Project-Specific Conventions
- Window and group state is tracked in the global `g` map.
- Manual window moves set a temporary lock (ManualLock) to prevent physics override.
- Physics is overlap/repulsion-based, not center-attraction (see decisionLog.md).
- Window relationships and plugin groups are detected using multi-factor analysis (class, title, timing, etc).
- Layout algorithms and group behaviors are extensible via strategy/factory patterns.

## Integration & Extensibility
- Designed for DAW/plugin-heavy workflows (Ableton, REAPER, etc), with special handling for plugin windows.
- Virtual desktop and multi-monitor support via API abstraction and workspace isolation.
- Session state and group membership are persisted and reconstructed across runs.

## Key Files & References
- FWDE.ahk: Main logic, config, and all core algorithms
- memory-bank/systemPatterns.md: Architectural and design patterns
- memory-bank/decisionLog.md: Major design decisions and rationale
- memory-bank/activeContext.md: Current goals and blockers
- memory-bank/progress.md: Recent changes and roadmap

## Example Patterns
- To add a new layout algorithm: implement as a strategy and register in the factory.
- To add a new group behavior: extend group detection and add physics rules for the new type.
- To debug window state: use Ctrl+Alt+D or inspect the `g["Windows"]` map.

---
For more context, see the memory-bank/ directory and comments in FWDE.ahk.
