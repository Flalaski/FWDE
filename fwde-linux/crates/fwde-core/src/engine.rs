use crate::{
    geometry::Vec2,
    model::{EngineConfig, OutputId, OutputInfo, WindowState},
};

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct SimulationStats {
    pub moved_windows: usize,
    pub overlap_pairs: usize,
}

#[derive(Debug, Clone)]
pub struct SimulationEngine {
    config: EngineConfig,
}

impl SimulationEngine {
    pub fn new(config: EngineConfig) -> Self {
        Self { config }
    }

    pub fn config(&self) -> &EngineConfig {
        &self.config
    }

    pub fn step(
        &self,
        windows: &mut [WindowState],
        outputs: &[OutputInfo],
        dt_seconds: f64,
    ) -> SimulationStats {
        let mut stats = SimulationStats::default();
        let dt = dt_seconds.max(0.001);

        for index in 0..windows.len() {
            if windows[index].info.pinned
                || windows[index].info.fullscreen
                || windows[index].info.minimized
            {
                continue;
            }

            let output_id = windows[index].info.output;
            let bounds = work_area_for(outputs, output_id).or_else(|| {
                outputs
                    .iter()
                    .find(|output| output.primary)
                    .map(|output| output.work_area)
            });

            let Some(bounds) = bounds else {
                continue;
            };

            let mut force = attraction_toward(
                bounds,
                windows[index].info.frame.center(),
                self.config.attraction_force,
            );

            for other_index in 0..windows.len() {
                if index == other_index {
                    continue;
                }

                let overlap = windows[index]
                    .info
                    .frame
                    .intersection_area(windows[other_index].info.frame);
                if overlap <= 0.0 {
                    continue;
                }

                stats.overlap_pairs += 1;
                let direction = (windows[index].info.frame.center()
                    - windows[other_index].info.frame.center())
                .normalized();
                let escape = if direction == Vec2::default() {
                    Vec2::new(1.0, 0.0)
                } else {
                    direction
                };
                force += escape * (self.config.repulsion_force * overlap.sqrt());
            }

            let mut velocity = (windows[index].velocity + force * dt) * self.config.damping;
            let speed = velocity.magnitude();
            if speed > self.config.max_speed {
                velocity = velocity.normalized() * self.config.max_speed;
            }

            let next = crate::geometry::Rect::new(
                windows[index].info.frame.x + velocity.x,
                windows[index].info.frame.y + velocity.y,
                windows[index].info.frame.width,
                windows[index].info.frame.height,
            )
            .clamp_to(bounds);

            if next != windows[index].info.frame {
                stats.moved_windows += 1;
            }

            windows[index].velocity = velocity;
            windows[index].info.frame = next;
        }

        stats
    }
}

fn work_area_for(outputs: &[OutputInfo], output_id: OutputId) -> Option<crate::geometry::Rect> {
    outputs
        .iter()
        .find(|output| output.id == output_id)
        .map(|output| output.work_area)
}

fn attraction_toward(bounds: crate::geometry::Rect, point: Vec2, coefficient: f64) -> Vec2 {
    let delta = bounds.center() - point;
    delta * coefficient
}

#[cfg(test)]
mod tests {
    use crate::{
        engine::SimulationEngine,
        geometry::Rect,
        model::{EngineConfig, OutputInfo, WindowInfo, WindowState},
    };

    #[test]
    fn step_reduces_direct_overlap() {
        let engine = SimulationEngine::new(EngineConfig::default());
        let output = OutputInfo {
            id: 1,
            name: "DP-1".into(),
            bounds: Rect::new(0.0, 0.0, 1920.0, 1080.0),
            work_area: Rect::new(0.0, 0.0, 1920.0, 1040.0),
            primary: true,
        };
        let mut windows = vec![
            WindowState::new(WindowInfo {
                id: 1,
                title: "A".into(),
                app_id: Some("app.a".into()),
                class_name: Some("AppA".into()),
                process_name: Some("app-a".into()),
                pid: Some(1),
                output: 1,
                frame: Rect::new(100.0, 100.0, 400.0, 300.0),
                floating: true,
                fullscreen: false,
                minimized: false,
                pinned: false,
                visible: true,
                urgent: false,
                workspace: None,
                role: None,
                window_type: Some("normal".into()),
                is_popup: false,
                has_caption: true,
                is_tool_window: false,
            }),
            WindowState::new(WindowInfo {
                id: 2,
                title: "B".into(),
                app_id: Some("app.b".into()),
                class_name: Some("AppB".into()),
                process_name: Some("app-b".into()),
                pid: Some(2),
                output: 1,
                frame: Rect::new(120.0, 120.0, 400.0, 300.0),
                floating: true,
                fullscreen: false,
                minimized: false,
                pinned: false,
                visible: true,
                urgent: false,
                workspace: None,
                role: None,
                window_type: Some("normal".into()),
                is_popup: false,
                has_caption: true,
                is_tool_window: false,
            }),
        ];

        let before = windows[0]
            .info
            .frame
            .intersection_area(windows[1].info.frame);
        for _ in 0..10 {
            engine.step(&mut windows, &[output.clone()], 1.0 / 60.0);
        }
        let after = windows[0]
            .info
            .frame
            .intersection_area(windows[1].info.frame);

        assert!(
            after < before,
            "expected overlap to shrink: before={before}, after={after}"
        );
    }
}
