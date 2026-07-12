# Progress (Updated: 2026-07-12)

## Done

- User's tuned FWDE config adopted as new system defaults across all parameters
- All parameter slider ranges massively expanded (2-5x) for further fine-tuning
- Added missing parameter overrides: SeedDiagonalStep, NoiseScale, NoiseInfluence, ManualWindowAlpha, ManualLockDuration, UserMoveTimeout, TooltipDuration, ResizeDelay, MinMargin, MinGap, ManualGapBonus, AnimationDuration, PhysicsUpdateInterval
- Implemented multi-pass chain-effect collision resolution (5 iterative passes with diminishing force weights)
- Chain physics uses probed positions so velocity from pass 1 cascades to pass 2, creating realistic chain reactions
- Wired Config["Damping"] into all hardcoded damping factors across CalculateWindowForces
- Redesigned FWDE physics system from center-attraction to overlap-based repulsion
- Implemented user move detection to temporarily pause physics
- Added gentle edge repulsion to keep windows on screen
- Reduced physics timing for smoother, more subtle movement
- Added overlap calculation functions for accurate collision detection

## Doing

- Testing the chain-effect physics with real window clusters
- Monitoring performance with 5-pass collision resolution

## Next

- Fine-tune chain pass weights based on real-world testing
- Add visual indicators for chain propagation (debug overlay)
- Consider adaptive pass count based on window cluster density
