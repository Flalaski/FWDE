# Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-08-02 | Redesigned FWDE physics system from center-attraction to overlap-based repulsion | The original center-attraction system was too forceful and noticeable. The new system only acts when windows actually overlap or are too close, providing gentle separation forces. This creates a more natural, subtle experience where windows maintain their positions unless there's a real need to adjust them. Also added user move detection to temporarily pause physics when someone manually positions a window. |
