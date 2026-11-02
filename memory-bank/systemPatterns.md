# System Patterns

## Architectural Patterns

### Window Registry (single classification, per-tick snapshot)
- **One record per HWND**: `_WinReg()` stores every fact about a window (`valid`, `floating`, `fullscreen`, `appbar`, `cloaked`, `plugin`, `tiny`, `movable`, rect/style/monitor) so callers never re-probe Win32
- **Signature invalidation**: records are re-classified only when the cheap signature changes (style/ex-style first, then rect), the TTL expires, or `_cfgGen` is bumped by `SyncRuntimeFromConfig()`
- **Per-tick snapshot**: `_WinRegSnapshot()` publishes the records plus a movable-handle set at the start of every physics tick; the O(n²) force loop, collision passes and movement pass read the snapshot and make no Win32 calls
- **Predicates are views**: `IsWindowValid`, `IsWindowFloating`, `IsFullscreenWindow`, `IsShellAppBarWindow`, `IsPluginWindow`, `IsTinyUtilityWindow`, `_IsPhysicsMovable` all resolve through the registry

### Achievable-Displacement Energy + Idle Gate
- **Energy = motion the visual layer can produce**: the force sum uses the clamped target delta (not raw velocity) and excludes bodies `ApplyWindowMovements` refuses to move, so a body pinned at a screen edge cannot hold the engine in `chaos`
- **Provable no-op detection**: when every tracked window's real rect matches the engine's state, nothing is dragging/menuing/snapping, the tracked set is unchanged and energy is below `(1.5/0.45)²` per window, the force/collision pipeline is skipped for that tick
- **Dirty-flag wake**: `_layoutDirty` is set by tracked-set changes and by `ApplyWindowMovements`' external-move resync, so the engine wakes within one tick of any real movement

### Sophisticated Layout Algorithm Architecture
- **Strategy Pattern**: Multiple bin packing algorithms (FirstFit, BestFit, NextFit, WorstFit, BottomLeftFill, Guillotine) implemented as interchangeable strategies
- **Template Method Pattern**: Common layout evaluation framework with algorithm-specific implementations
- **Observer Pattern**: Layout change notifications for visual feedback and system state updates
- **Command Pattern**: Layout operations (save, load, apply) implemented as reversible commands
- **Factory Pattern**: Algorithm instantiation based on configuration and performance requirements

### Genetic Algorithm Evolution System
- **Population-Based Optimization**: Maintains diverse layout solutions with fitness-based selection
- **Multi-Objective Fitness**: Balances multiple criteria (overlap, accessibility, aesthetics, user preference)
- **Elitism Strategy**: Preserves best solutions while allowing population diversity
- **Adaptive Parameters**: Mutation and crossover rates adjust based on population convergence
- **Real-Time Evolution**: Continuous improvement with user feedback integration

### Layout Persistence and Management
- **Repository Pattern**: Centralized layout storage with JSON persistence and metadata management
- **Version Control Pattern**: Layout versioning with migration support for backward compatibility
- **Caching Strategy**: Performance optimization through layout preview caching and smart loading
- **Matching Algorithm**: Intelligent window matching across sessions using multiple criteria

## Design Patterns

### Bin Packing Algorithm Patterns
- **Strategy Selection**: Dynamic algorithm choice based on window characteristics and performance requirements
- **Space Partitioning**: Recursive space division for complex layout optimization
- **Constraint Satisfaction**: Window placement within bounds and overlap constraints
- **Performance Benchmarking**: Real-time efficiency measurement and strategy comparison

### Virtual Desktop Integration Patterns
- **Workspace Isolation**: Per-desktop layout management with independent physics boundaries
- **State Synchronization**: Automatic layout switching with workspace change detection
- **Profile Management**: Customizable per-workspace configuration and rule sets
- **API Abstraction**: Windows 11 virtual desktop API integration with fallback mechanisms

## Common Idioms

### Layout Optimization Idioms
- **Fitness Evaluation**: Multi-factor scoring system for layout quality assessment
- **Space Efficiency Calculation**: Mathematical optimization for screen space utilization
- **User Preference Learning**: Pattern recognition for adaptive layout improvement
- **Performance-Quality Tradeoff**: Configurable balance between calculation speed and layout optimality

### Window Management Idioms
- **Smart Window Matching**: Title, class, and process-based window identification across sessions
- **Relative Positioning**: Screen-independent layout storage using proportional coordinates
- **Animated Transitions**: Smooth window movement for professional user experience
- **Error Recovery**: Graceful handling of missing windows and changed system configurations

### Plugin Dependency Tracking Patterns
- **Hierarchical Relationship Detection**: Multi-method window relationship analysis using API calls, spatial analysis, and pattern matching
- **Intelligent Grouping Algorithms**: Clustering based on proximity, type, timing, and hierarchy with configurable parameters
- **Group Behavior Patterns**: Specialized physics and movement behaviors for different plugin group types
- **Lifecycle State Management**: Comprehensive tracking of plugin window creation, updates, and cleanup
- **Session State Persistence**: Robust session management with JSON storage and automatic reconstruction

### Window Relationship Patterns
- **Parent-Child Detection**: Windows API integration for detecting true hierarchical relationships
- **Spatial Correlation**: Distance-based relationship inference with confidence scoring
- **Temporal Correlation**: Creation timing analysis for identifying related window groups
- **Pattern-Based Matching**: Plugin naming and class pattern analysis for component identification
- **Multi-Factor Validation**: Confidence scoring system combining multiple relationship indicators

## Common Idioms

### Plugin Group Management Idioms
- **Leader-Follower Dynamics**: Group movement coordination with designated leader windows
- **Formation Preservation**: Maintaining relative positions and arrangements within groups
- **Cohesion Force Application**: Physics modifications to keep related windows together
- **Group Type Specialization**: Different behaviors for instrument racks, effect chains, mixer sections
- **Automatic Group Evolution**: Dynamic group membership based on changing window relationships

### Dependency Tracking Idioms
- **Multi-Method Validation**: Cross-validation of relationships using multiple detection methods
- **Confidence-Based Decision Making**: Relationship strength assessment for grouping decisions
- **Lifecycle Event Handling**: Automatic group updates based on window creation and destruction
- **Session State Reconstruction**: Intelligent matching of persisted groups to current windows
- **Error-Resilient Group Management**: Graceful handling of missing or changed plugin windows