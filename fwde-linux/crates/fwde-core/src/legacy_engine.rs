use crate::{
    geometry::{Rect, Vec2},
    legacy_config::LegacyConfig,
    legacy_rules::{
        calculate_space_seeking_force, get_seeded_pair_direction, is_plugin_window,
        is_window_floating, lerp, pack_windows_optimally,
    },
    legacy_types::{LegacyManagedWindow, LegacyMonitor, LegacyRuntimeState, ManualWindowMarker},
    model::{OutputInfo, WindowInfo},
};

#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct LegacySimulationStats {
    pub moved_windows: usize,
    pub overlap_pairs: usize,
    pub tracked_windows: usize,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WindowMovePlan {
    pub hwnd: u64,
    pub x: f64,
    pub y: f64,
}

#[derive(Debug, Clone)]
pub struct LegacyEngine {
    pub config: LegacyConfig,
    pub state: LegacyRuntimeState,
}

impl LegacyEngine {
    pub fn new(config: LegacyConfig) -> Self {
        Self {
            config,
            state: LegacyRuntimeState::default(),
        }
    }

    pub fn sync_outputs(&mut self, outputs: &[OutputInfo]) {
        self.state.outputs = outputs.iter().map(LegacyMonitor::from_output).collect();
        self.state.monitor = if self.config.multimonitor_expanse {
            self.get_virtual_desktop_bounds()
        } else {
            self.get_primary_monitor_coordinates()
        };
    }

    pub fn update_window_states_from_backend(&mut self, windows: Vec<WindowInfo>, now_ms: u64) {
        let previous = self.state.windows.clone();
        let mut translated = Vec::new();

        for window in windows {
            let mut managed = LegacyManagedWindow::from_window_info(window, now_ms);
            managed.is_plugin = is_plugin_window(&managed);
            managed.floating = is_window_floating(&managed, &self.config);

            if let Some(existing) = previous
                .iter()
                .find(|candidate| candidate.hwnd == managed.hwnd)
            {
                managed.last_move_ms = existing.last_move_ms;
                managed.vx = existing.vx;
                managed.vy = existing.vy;
                managed.target_x = existing.target_x;
                managed.target_y = existing.target_y;
                managed.manual_lock_until_ms = existing.manual_lock_until_ms;
                managed.is_manual = existing.is_manual;
                managed.just_dragged_at_ms = existing.just_dragged_at_ms;
                managed.lock_lost_at_ms = existing.lock_lost_at_ms;
            }

            if managed.floating && !managed.fullscreen && !managed.minimized {
                translated.push(managed);
            }
        }

        self.state.windows = translated;
    }

    pub fn calculate_dynamic_layout(&mut self, now_ms: u64) -> LegacySimulationStats {
        let mut stats = LegacySimulationStats {
            tracked_windows: self.state.windows.len(),
            ..LegacySimulationStats::default()
        };

        if !self.state.arrangement_active || !self.state.physics_enabled {
            return stats;
        }

        let snapshot = self.state.windows.clone();
        let mut current_energy = 0.0;

        for index in 0..self.state.windows.len() {
            let overlaps = self.calculate_window_forces(index, &snapshot, now_ms);
            stats.overlap_pairs += overlaps;
            current_energy +=
                self.state.windows[index].vx.powi(2) + self.state.windows[index].vy.powi(2);
        }

        self.state.system_energy = lerp(self.state.system_energy, current_energy, 0.1);
        self.resolve_floating_collisions(now_ms, &mut stats);
        stats.tracked_windows = self.state.windows.len();
        stats
    }

    pub fn apply_window_movements(&mut self) -> Vec<WindowMovePlan> {
        let mut moves = Vec::new();
        let monitor = self
            .state
            .monitor
            .clone()
            .or_else(|| self.get_primary_monitor_coordinates());
        let Some(monitor) = monitor else {
            return moves;
        };

        // Capture immutable state needed for protection checks to avoid borrowing self in loop.
        let active_window = self.state.active_window;
        let last_user_move_ms = self.state.last_user_move_ms;
        let user_move_timeout_ms = self.config.user_move_timeout_ms;
        let snap_in_progress = self.state.snap_in_progress.clone();

        for window in &mut self.state.windows {
            let now_ms: u64 = 0;
            let is_active = active_window == Some(window.hwnd);
            let is_recently_moved = now_ms.saturating_sub(last_user_move_ms) < user_move_timeout_ms;
            let is_manually_locked = window
                .manual_lock_until_ms
                .map(|expires| now_ms < expires)
                .unwrap_or(false);
            let was_just_unlocked = window
                .lock_lost_at_ms
                .map(|lost_at| now_ms.saturating_sub(lost_at) < 100)
                .unwrap_or(false);
            let is_being_snapped = snap_in_progress
                .get(&window.hwnd)
                .map(|expires| now_ms < *expires)
                .unwrap_or(false);

            let is_protected = is_manually_locked
                || is_active
                || (is_recently_moved && is_active)
                || is_being_snapped
                || was_just_unlocked;

            if is_protected {
                continue;
            }

            let alpha = if Self::is_electron_window(window) {
                0.45
            } else {
                0.18
            };
            let smoothed_x = window.x + (window.target_x - window.x) * alpha;
            let smoothed_y = window.y + (window.target_y - window.y) * alpha;
            let bounded_x = smoothed_x.clamp(monitor.left, monitor.right - window.width);
            let bounded_y = smoothed_y.clamp(
                monitor.top + self.config.min_margin,
                monitor.bottom - self.config.min_margin - window.height,
            );

            if (bounded_x - window.x).abs() >= 1.5 || (bounded_y - window.y).abs() >= 1.5 {
                window.x = bounded_x;
                window.y = bounded_y;
                moves.push(WindowMovePlan {
                    hwnd: window.hwnd,
                    x: bounded_x,
                    y: bounded_y,
                });
            }
        }

        moves
    }

    pub fn optimize_window_positions(&mut self) -> usize {
        let Some(monitor) = self.state.monitor.clone() else {
            return 0;
        };

        let mut windows_to_place = self
            .state
            .windows
            .iter()
            .filter(|window| !self.is_window_protected(window, 0, false))
            .cloned()
            .collect::<Vec<_>>();
        windows_to_place.sort_by(|left, right| {
            right
                .area
                .partial_cmp(&left.area)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        let placements = pack_windows_optimally(&windows_to_place, &monitor, &self.config);
        let mut repositioned = 0;

        for (hwnd, position) in placements {
            if let Some(window) = self
                .state
                .windows
                .iter_mut()
                .find(|window| window.hwnd == hwnd)
            {
                window.target_x = position.x;
                window.target_y = position.y;
                window.vx = (position.x - window.x) * 0.1;
                window.vy = (position.y - window.y) * 0.1;
                repositioned += 1;
            }
        }

        repositioned
    }

    pub fn toggle_arrangement(&mut self) {
        self.state.arrangement_active = !self.state.arrangement_active;
    }

    pub fn toggle_physics(&mut self) {
        self.state.physics_enabled = !self.state.physics_enabled;
    }

    pub fn toggle_multimonitor_expanse(&mut self) {
        self.config.multimonitor_expanse = !self.config.multimonitor_expanse;
        self.state.monitor = if self.config.multimonitor_expanse {
            self.get_virtual_desktop_bounds()
        } else {
            self.get_current_monitor_info()
        };
    }

    pub fn toggle_window_lock(&mut self, hwnd: u64, now_ms: u64) -> bool {
        let Some(window) = self
            .state
            .windows
            .iter_mut()
            .find(|window| window.hwnd == hwnd)
        else {
            return false;
        };

        let is_locked = window
            .manual_lock_until_ms
            .map(|expires| now_ms < expires)
            .unwrap_or(false);
        if is_locked {
            window.manual_lock_until_ms = None;
            window.is_manual = false;
            self.state.manual_windows.remove(&hwnd);
            self.state.active_window = None;
            false
        } else {
            let expires = now_ms + self.config.manual_lock_duration_ms;
            window.manual_lock_until_ms = Some(expires);
            window.is_manual = true;
            window.vx = 0.0;
            window.vy = 0.0;
            self.state.active_window = Some(hwnd);
            self.state.last_user_move_ms = now_ms;
            self.state.manual_windows.insert(
                hwnd,
                ManualWindowMarker {
                    expire_at_ms: expires,
                },
            );
            true
        }
    }

    pub fn get_current_monitor_info(&self) -> Option<LegacyMonitor> {
        self.state
            .monitor
            .clone()
            .or_else(|| self.get_primary_monitor_coordinates())
    }

    pub fn get_primary_monitor_coordinates(&self) -> Option<LegacyMonitor> {
        self.state
            .outputs
            .iter()
            .find(|output| output.primary)
            .cloned()
            .or_else(|| self.state.outputs.first().cloned())
    }

    pub fn get_virtual_desktop_bounds(&self) -> Option<LegacyMonitor> {
        if self.state.outputs.is_empty() {
            return None;
        }

        let min_left = self
            .state
            .outputs
            .iter()
            .map(|output| output.left)
            .fold(f64::MAX, f64::min);
        let max_right = self
            .state
            .outputs
            .iter()
            .map(|output| output.right)
            .fold(f64::MIN, f64::max);
        let min_top = self
            .state
            .outputs
            .iter()
            .map(|output| output.top)
            .fold(f64::MAX, f64::min);
        let max_bottom = self
            .state
            .outputs
            .iter()
            .map(|output| output.bottom)
            .fold(f64::MIN, f64::max);

        Some(LegacyMonitor {
            left: min_left,
            right: max_right,
            top: min_top,
            bottom: max_bottom,
            width: max_right - min_left,
            height: max_bottom - min_top,
            number: 0,
            center_x: (max_right + min_left) / 2.0,
            center_y: (max_bottom + min_top) / 2.0,
            name: "virtual".to_string(),
            primary: false,
        })
    }

    fn calculate_window_forces(
        &mut self,
        index: usize,
        snapshot: &[LegacyManagedWindow],
        now_ms: u64,
    ) -> usize {
        let Some(monitor) = self.monitor_for_window(snapshot[index].monitor) else {
            return 0;
        };

        let protected = self.is_window_protected(&snapshot[index], now_ms, false);
        if protected {
            self.state.windows[index].vx = 0.0;
            self.state.windows[index].vy = 0.0;
            return 0;
        }

        let mut overlap_pairs = 0;
        let mut vx = snapshot[index].vx;
        let mut vy = snapshot[index].vy;
        let (window_center_x, window_center_y) = snapshot[index].center();
        let center_dx = monitor.center_x - window_center_x;
        let center_dy = monitor.center_y - window_center_y;
        let center_distance = (center_dx * center_dx + center_dy * center_dy).sqrt();

        if center_distance > 100.0 {
            let attraction_scale = (center_distance / 1200.0).min(0.25);
            let damping_factor = if self.is_electron_app(&snapshot[index]) {
                0.99
            } else {
                0.98
            };
            vx = vx * damping_factor
                + center_dx * self.config.attraction_force * 0.08 * attraction_scale;
            vy = vy * damping_factor
                + center_dy * self.config.attraction_force * 0.08 * attraction_scale;
        } else {
            let damping_factor = if self.is_electron_app(&snapshot[index]) {
                0.998
            } else {
                0.995
            };
            vx *= damping_factor;
            vy *= damping_factor;
        }

        let space_force = calculate_space_seeking_force(&snapshot[index], snapshot, &monitor);
        vx += space_force.x * 0.005;
        vy += space_force.y * 0.005;

        for other in snapshot {
            if other.hwnd == snapshot[index].hwnd || other.fullscreen || other.minimized {
                continue;
            }

            let (other_center_x, other_center_y) = other.center();
            let mut dx = window_center_x - other_center_x;
            let mut dy = window_center_y - other_center_y;
            if dx.abs() < 0.5 && dy.abs() < 0.5 {
                let direction = get_seeded_pair_direction(&snapshot[index], other);
                dx = direction.x;
                dy = direction.y;
            }

            let distance = (dx * dx + dy * dy).sqrt().max(1.0);
            let interaction_range = (((snapshot[index].width * snapshot[index].height)
                + (other.width * other.height))
                .sqrt()
                / 2.5)
                * (200.0 / snapshot[index].width.min(snapshot[index].height)).max(1.0);
            let repulsion_range = interaction_range * self.config.repulsion_range_multiplier;
            let min_dim_pair = snapshot[index]
                .width
                .min(snapshot[index].height)
                .min(other.width)
                .min(other.height)
                .max(1.0);
            let small_window_boost = (self.config.small_window_reference_dim / min_dim_pair)
                .clamp(1.0, self.config.max_small_window_repulsion_boost);

            let overlap_x = (snapshot[index].x + snapshot[index].width).min(other.x + other.width)
                - snapshot[index].x.max(other.x);
            let overlap_y = (snapshot[index].y + snapshot[index].height)
                .min(other.y + other.height)
                - snapshot[index].y.max(other.y);
            if overlap_x > self.config.collision_overlap_threshold
                && overlap_y > self.config.collision_overlap_threshold
            {
                overlap_pairs += 1;
            }

            if distance < repulsion_range {
                let mut repulsion_force =
                    self.config.repulsion_force * (repulsion_range - distance) / repulsion_range;
                if other.is_manual {
                    repulsion_force *= self.config.manual_repulsion_multiplier;
                }
                repulsion_force *= small_window_boost;
                let proximity_multiplier = 1.0 + (1.0 - distance / repulsion_range);
                vx += dx * repulsion_force * proximity_multiplier / distance
                    * self.config.repulsion_impulse_scale;
                vy += dy * repulsion_force * proximity_multiplier / distance
                    * self.config.repulsion_impulse_scale;
            } else if distance < interaction_range * 3.0 {
                let attraction_force =
                    self.config.attraction_force * 0.012 * (distance - interaction_range)
                        / interaction_range;
                vx -= dx * attraction_force / distance * 0.04;
                vy -= dy * attraction_force / distance * 0.04;
            }
        }

        let damping_factor = if self.is_electron_app(&snapshot[index]) {
            0.998
        } else {
            0.994
        };
        vx *= damping_factor;
        vy *= damping_factor;

        let max_speed = self.config.max_speed * 2.0;
        vx = vx.clamp(-max_speed, max_speed);
        vy = vy.clamp(-max_speed, max_speed);

        if vx.abs() < 0.15 && vy.abs() < 0.15 {
            let stabilization_factor = if self.is_electron_app(&snapshot[index]) {
                0.95
            } else {
                0.88
            };
            vx *= stabilization_factor;
            vy *= stabilization_factor;
        }

        let target_x =
            (snapshot[index].x + vx).clamp(monitor.left, monitor.right - snapshot[index].width);
        let target_y = (snapshot[index].y + vy).clamp(
            monitor.top + self.config.min_margin,
            monitor.bottom - self.config.min_margin - snapshot[index].height,
        );

        self.state.windows[index].vx = vx;
        self.state.windows[index].vy = vy;
        self.state.windows[index].target_x = target_x;
        self.state.windows[index].target_y = target_y;

        overlap_pairs
    }

    fn resolve_floating_collisions(&mut self, now_ms: u64, stats: &mut LegacySimulationStats) {
        let snapshot = self.state.windows.clone();

        for i in 0..self.state.windows.len() {
            for j in (i + 1)..self.state.windows.len() {
                let win1 = &snapshot[i];
                let win2 = &snapshot[j];
                if win1.fullscreen || win2.fullscreen || win1.minimized || win2.minimized {
                    continue;
                }

                let overlap_x = (win1.x + win1.width).min(win2.x + win2.width) - win1.x.max(win2.x);
                let overlap_y =
                    (win1.y + win1.height).min(win2.y + win2.height) - win1.y.max(win2.y);
                if overlap_x <= self.config.collision_overlap_threshold
                    || overlap_y <= self.config.collision_overlap_threshold
                {
                    continue;
                }

                let protected1 = self.is_window_protected(win1, now_ms, false);
                let protected2 = self.is_window_protected(win2, now_ms, false);
                if protected1 && protected2 {
                    continue;
                }

                let center_x1 = win1.x + win1.width / 2.0;
                let center_y1 = win1.y + win1.height / 2.0;
                let center_x2 = win2.x + win2.width / 2.0;
                let center_y2 = win2.y + win2.height / 2.0;
                let mut dx = center_x1 - center_x2;
                let mut dy = center_y1 - center_y2;
                if dx.abs() < 0.5 && dy.abs() < 0.5 {
                    let direction = get_seeded_pair_direction(win1, win2);
                    dx = direction.x;
                    dy = direction.y;
                }

                let distance = (dx * dx + dy * dy).sqrt().max(1.0);
                let overlap_area = overlap_x * overlap_y;
                let avg_size = ((win1.width * win1.height) + (win2.width * win2.height)) / 2.0;
                let overlap_ratio = overlap_area / avg_size.max(1.0);
                let mut separation_force = (overlap_x + overlap_y)
                    * self.config.pair_separation_base
                    * (1.0 + overlap_ratio * self.config.pair_separation_overlap_scale);
                if win1.width < self.config.small_window_threshold_w
                    || win1.height < self.config.small_window_threshold_h
                    || win2.width < self.config.small_window_threshold_w
                    || win2.height < self.config.small_window_threshold_h
                {
                    separation_force *= self.config.pair_small_window_boost;
                }

                if !protected1 {
                    self.state.windows[i].vx += dx * separation_force / distance;
                    self.state.windows[i].vy += dy * separation_force / distance;
                }
                if !protected2 {
                    self.state.windows[j].vx -= dx * separation_force / distance;
                    self.state.windows[j].vy -= dy * separation_force / distance;
                }
                stats.moved_windows += 1;
            }
        }
    }

    fn monitor_for_window(&self, output_id: u32) -> Option<LegacyMonitor> {
        if self.config.multimonitor_expanse {
            return self.get_virtual_desktop_bounds();
        }
        self.state
            .outputs
            .iter()
            .find(|output| output.number == output_id)
            .cloned()
            .or_else(|| self.get_primary_monitor_coordinates())
    }

    fn is_window_protected(
        &self,
        window: &LegacyManagedWindow,
        now_ms: u64,
        is_dragged: bool,
    ) -> bool {
        let is_active = self.state.active_window == Some(window.hwnd);
        let is_recently_moved =
            now_ms.saturating_sub(self.state.last_user_move_ms) < self.config.user_move_timeout_ms;
        let is_manually_locked = window
            .manual_lock_until_ms
            .map(|expires| now_ms < expires)
            .unwrap_or(false);
        let was_just_unlocked = window
            .lock_lost_at_ms
            .map(|lost_at| now_ms.saturating_sub(lost_at) < 100)
            .unwrap_or(false);
        let is_being_snapped = self
            .state
            .snap_in_progress
            .get(&window.hwnd)
            .map(|expires| now_ms < *expires)
            .unwrap_or(false);

        (is_manually_locked
            || is_active
            || (is_recently_moved && is_active)
            || is_being_snapped
            || was_just_unlocked)
            && !is_dragged
    }

    fn is_electron_app(&self, window: &LegacyManagedWindow) -> bool {
        Self::is_electron_window(window)
    }

    fn is_electron_window(window: &LegacyManagedWindow) -> bool {
        let class_name = window.class_name.clone().unwrap_or_default();
        let process_name = window
            .process_name
            .clone()
            .unwrap_or_default()
            .to_lowercase();
        let electron_classes = [
            "Chrome_WidgetWin_1",
            "Chrome_WidgetWin_0",
            "ElectronMainWindow",
            "CEF-OSC-WIDGET",
        ];
        let electron_processes = [
            "cursor", "code", "discord", "slack", "spotify", "whatsapp", "telegram", "notion",
            "obsidian", "typora", "hyper",
        ];

        electron_classes
            .iter()
            .any(|pattern| class_name.eq_ignore_ascii_case(pattern))
            || electron_processes
                .iter()
                .any(|pattern| process_name.contains(pattern))
    }
}

#[allow(dead_code)]
fn _rect_from_window(window: &LegacyManagedWindow) -> Rect {
    Rect::new(window.x, window.y, window.width, window.height)
}

#[allow(dead_code)]
fn _vec_from_window_motion(window: &LegacyManagedWindow) -> Vec2 {
    Vec2::new(window.vx, window.vy)
}
