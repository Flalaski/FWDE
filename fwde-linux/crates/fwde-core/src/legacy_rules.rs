use crate::{
    geometry::Vec2,
    legacy_config::LegacyConfig,
    legacy_types::{LegacyManagedWindow, LegacyMonitor},
};

pub fn lerp(a: f64, b: f64, t: f64) -> f64 {
    a + (b - a) * t
}

pub fn ease_out_cubic(t: f64) -> f64 {
    1.0 - (1.0 - t).powi(3)
}

pub fn clamp(value: f64, min: f64, max: f64) -> f64 {
    value.clamp(min, max)
}

pub fn is_overlapping(
    window: &LegacyManagedWindow,
    others: &[LegacyManagedWindow],
    overlap_tolerance: f64,
) -> bool {
    others.iter().any(|other| {
        if window.hwnd == other.hwnd {
            return false;
        }

        let overlap_x =
            (window.x + window.width).min(other.x + other.width) - window.x.max(other.x);
        let overlap_y =
            (window.y + window.height).min(other.y + other.height) - window.y.max(other.y);
        overlap_x > overlap_tolerance && overlap_y > overlap_tolerance
    })
}

pub fn get_window_placement_seed(window: &LegacyManagedWindow) -> u64 {
    let hwnd = window.hwnd;
    let width = window.width.round() as u64;
    let height = window.height.round() as u64;
    hwnd.saturating_add(width.saturating_mul(37))
        .saturating_add(height.saturating_mul(53))
}

pub fn get_seeded_diagonal_offset(window: &LegacyManagedWindow, config: &LegacyConfig) -> Vec2 {
    let seed = get_window_placement_seed(window);
    let directions = [
        Vec2::new(-1.0, -1.0),
        Vec2::new(1.0, -1.0),
        Vec2::new(-1.0, 1.0),
        Vec2::new(1.0, 1.0),
    ];
    let direction = directions[(seed % directions.len() as u64) as usize];
    let max_steps = config.seed_diagonal_max_steps.max(1) as u64;
    let step_count = (seed / 4) % max_steps + 1;
    let jitter = if config.seed_jitter_range > 0.0 {
        let jitter_range = config.seed_jitter_range.round() as i64;
        ((seed / 17) as i64 % (jitter_range * 2 + 1)) - jitter_range
    } else {
        0
    };
    let magnitude = config.seed_diagonal_step * step_count as f64 + jitter as f64;
    direction * magnitude
}

pub fn get_seeded_pair_direction(win1: &LegacyManagedWindow, win2: &LegacyManagedWindow) -> Vec2 {
    let seed = win1
        .hwnd
        .saturating_mul(31)
        .saturating_add(win2.hwnd.saturating_mul(17));
    let directions = [
        Vec2::new(-1.0, -1.0),
        Vec2::new(1.0, -1.0),
        Vec2::new(-1.0, 1.0),
        Vec2::new(1.0, 1.0),
    ];
    directions[(seed % directions.len() as u64) as usize]
}

pub fn is_plugin_window(window: &LegacyManagedWindow) -> bool {
    let class_name = window.class_name.clone().unwrap_or_default().to_lowercase();
    let title = window.title.to_lowercase();
    let process_name = window
        .process_name
        .clone()
        .unwrap_or_default()
        .to_lowercase();

    let plugin_classes = [
        "vst",
        "vstplugin",
        "audiounit",
        "au",
        "rtas",
        "aax",
        "qt5qwindowicon",
        "qt6qwindowicon",
        "js",
        "plugin",
        "float",
        "dock",
    ];
    let plugin_titles = [
        "vst",
        "au",
        "js:",
        "plugin",
        "synth",
        "effect",
        "eq",
        "compressor",
        "reverb",
        "delay",
        "filter",
        "oscillator",
        "sampler",
        "drum",
        "fx",
    ];
    let daw_processes = [
        "reaper",
        "ableton",
        "flstudio",
        "cubase",
        "studioone",
        "bitwig",
        "protools",
    ];

    let is_daw_process = daw_processes.iter().any(|daw| process_name.contains(daw));
    if is_daw_process {
        if plugin_classes
            .iter()
            .any(|pattern| class_name.contains(pattern))
        {
            return true;
        }
        if plugin_titles.iter().any(|pattern| title.contains(pattern)) {
            return true;
        }
        return window.width < 800.0 && window.height < 600.0;
    }

    plugin_classes
        .iter()
        .any(|pattern| class_name.contains(pattern))
        || plugin_titles.iter().any(|pattern| title.contains(pattern))
}

pub fn is_window_floating(window: &LegacyManagedWindow, config: &LegacyConfig) -> bool {
    if window.fullscreen || window.minimized {
        return false;
    }

    let process_name = window
        .process_name
        .clone()
        .unwrap_or_default()
        .to_lowercase();
    let class_name = window.class_name.clone().unwrap_or_default();
    let title = window.title.clone();

    if config
        .force_float_processes
        .iter()
        .any(|pattern| process_name == pattern.to_lowercase())
    {
        return true;
    }

    if ["consolewindowclass", "cascadia_hosting_window_class"]
        .iter()
        .any(|pattern| class_name.eq_ignore_ascii_case(pattern))
    {
        return true;
    }

    if is_plugin_window(window) {
        return true;
    }

    if window.tool_window || !window.visible {
        return true;
    }

    if config
        .float_class_patterns
        .iter()
        .any(|pattern| wildcard_like(&class_name, pattern))
    {
        return true;
    }

    if config
        .float_title_patterns
        .iter()
        .any(|pattern| wildcard_like(&title, pattern))
    {
        return true;
    }

    window.popup || window.floating
}

pub fn calculate_future_overlap(
    window: &LegacyManagedWindow,
    x: f64,
    y: f64,
    others: &[LegacyManagedWindow],
) -> f64 {
    let mut overlap_score = 0.0;
    for other in others {
        if other.hwnd == window.hwnd {
            continue;
        }

        let overlap_x = (x + window.width).min(other.x + other.width) - x.max(other.x);
        let overlap_y = (y + window.height).min(other.y + other.height) - y.max(other.y);
        let overlap_x = overlap_x.max(0.0);
        let overlap_y = overlap_y.max(0.0);
        overlap_score += (overlap_x * overlap_y) / (window.width * window.height).max(1.0);
    }
    overlap_score
}

pub fn calculate_density_at_point(
    test_x: f64,
    test_y: f64,
    windows: &[LegacyManagedWindow],
    exclude_hwnd: Option<u64>,
) -> f64 {
    let mut density = 0.0;
    let influence_radius = 200.0;

    for window in windows {
        if exclude_hwnd == Some(window.hwnd) {
            continue;
        }

        let (win_center_x, win_center_y) = window.center();
        let dx = test_x - win_center_x;
        let dy = test_y - win_center_y;
        let distance = (dx * dx + dy * dy).sqrt();

        if distance < influence_radius {
            let influence = (influence_radius - distance) / influence_radius;
            let size_weight = (window.width * window.height).sqrt() / 1000.0;
            density += influence * size_weight;
        }
    }

    density
}

pub fn find_least_crowded_direction(
    window: &LegacyManagedWindow,
    all_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
) -> Option<Vec2> {
    let (center_x, center_y) = window.center();
    let directions = [
        Vec2::new(0.0, -1.0),
        Vec2::new(1.0, -1.0),
        Vec2::new(1.0, 0.0),
        Vec2::new(1.0, 1.0),
        Vec2::new(0.0, 1.0),
        Vec2::new(-1.0, 1.0),
        Vec2::new(-1.0, 0.0),
        Vec2::new(-1.0, -1.0),
    ];

    let mut best_direction = None;
    let mut lowest_density = f64::MAX;
    let search_distance = 300.0;

    for direction in directions {
        let test_x = center_x + direction.x * search_distance;
        let test_y = center_y + direction.y * search_distance;
        if test_x < monitor.left + window.width / 2.0
            || test_x > monitor.right - window.width / 2.0
            || test_y < monitor.top + window.height / 2.0
            || test_y > monitor.bottom - window.height / 2.0
        {
            continue;
        }

        let density = calculate_density_at_point(test_x, test_y, all_windows, Some(window.hwnd));
        if density < lowest_density {
            lowest_density = density;
            best_direction = Some(direction);
        }
    }

    best_direction
}

pub fn calculate_space_seeking_force(
    window: &LegacyManagedWindow,
    all_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
) -> Vec2 {
    if all_windows.len() <= 2 {
        return Vec2::default();
    }

    let (center_x, center_y) = window.center();
    let density_radius = 250.0;
    let mut local_density = 0.0;

    for other in all_windows {
        if other.hwnd == window.hwnd {
            continue;
        }

        let (other_x, other_y) = other.center();
        let dx = center_x - other_x;
        let dy = center_y - other_y;
        let distance = (dx * dx + dy * dy).sqrt();
        if distance < density_radius {
            let proximity_weight = (density_radius - distance) / density_radius;
            let size_weight = (other.width * other.height).sqrt() / 1000.0;
            local_density += proximity_weight * size_weight;
        }
    }

    if local_density < 2.0 {
        return Vec2::default();
    }

    let Some(direction) = find_least_crowded_direction(window, all_windows, monitor) else {
        return Vec2::default();
    };

    let force_magnitude = (local_density - 2.0).min(3.0);
    direction * force_magnitude
}

pub fn score_position(
    position: Vec2,
    window: &LegacyManagedWindow,
    placed_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
    strategy: &str,
    config: &LegacyConfig,
) -> f64 {
    let mut score = 1000.0;
    let center_distance = ((position.x + window.width / 2.0 - monitor.center_x).powi(2)
        + (position.y + window.height / 2.0 - monitor.center_y).powi(2))
    .sqrt();

    match strategy {
        "center" => score -= center_distance * 0.5,
        "edges" => score += center_distance * 0.3,
        "topLeft" => score -= (position.x + position.y) * 0.1,
        _ => {}
    }

    for placed in placed_windows {
        let placed_distance = ((position.x + window.width / 2.0 - placed.x - placed.width / 2.0)
            .powi(2)
            + (position.y + window.height / 2.0 - placed.y - placed.height / 2.0).powi(2))
        .sqrt();
        if placed_distance < 100.0 {
            score -= (100.0 - placed_distance) * 2.0;
        } else if placed_distance > 200.0 {
            score += 50.0;
        }
    }

    let margin = config.min_margin;
    if position.x > monitor.left + margin
        && position.x < monitor.right - window.width - margin
        && position.y > monitor.top + margin
        && position.y < monitor.bottom - window.height - margin
    {
        score += 200.0;
    }

    score
}

pub fn generate_position_candidates(
    window: &LegacyManagedWindow,
    placed_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
    strategy: &str,
    config: &LegacyConfig,
) -> Vec<Vec2> {
    let usable_left = monitor.left + config.min_margin;
    let usable_top = monitor.top + config.min_margin;
    let usable_right = monitor.right - config.min_margin - window.width;
    let usable_bottom = monitor.bottom - config.min_margin - window.height;

    let mut candidates = Vec::new();

    match strategy {
        "topLeft" => {
            let mut y = usable_top;
            while y <= usable_bottom {
                let mut x = usable_left;
                while x <= usable_right {
                    candidates.push(Vec2::new(x, y));
                    if candidates.len() > 100 {
                        return candidates;
                    }
                    x += 60.0;
                }
                y += 60.0;
            }
        }
        "center" => {
            let center_x = monitor.center_x - window.width / 2.0;
            let center_y = monitor.center_y - window.height / 2.0;
            candidates.push(Vec2::new(center_x, center_y));
            let mut spiral_radius: f64 = 50.0;
            while spiral_radius <= 300.0 {
                let spiral_angles = (spiral_radius / 25.0).floor().max(8.0) as u32;
                for angle_step in 0..spiral_angles {
                    let angle =
                        angle_step as f64 * (2.0 * std::f64::consts::PI / spiral_angles as f64);
                    let x = center_x + spiral_radius * angle.cos();
                    let y = center_y + spiral_radius * angle.sin();
                    if x >= usable_left
                        && x <= usable_right
                        && y >= usable_top
                        && y <= usable_bottom
                    {
                        candidates.push(Vec2::new(x, y));
                    }
                }
                spiral_radius += 50.0;
            }
        }
        "edges" => {
            let mut x = usable_left;
            while x <= usable_right {
                candidates.push(Vec2::new(x, usable_top));
                candidates.push(Vec2::new(x, usable_bottom));
                x += 80.0;
            }
            let mut y = usable_top;
            while y <= usable_bottom {
                candidates.push(Vec2::new(usable_left, y));
                candidates.push(Vec2::new(usable_right, y));
                y += 80.0;
            }
        }
        "gaps" => {
            for placed in placed_windows {
                candidates.push(Vec2::new(
                    placed.x + placed.width + config.min_gap,
                    placed.y,
                ));
                candidates.push(Vec2::new(
                    placed.x - window.width - config.min_gap,
                    placed.y,
                ));
                candidates.push(Vec2::new(
                    placed.x,
                    placed.y + placed.height + config.min_gap,
                ));
                candidates.push(Vec2::new(
                    placed.x,
                    placed.y - window.height - config.min_gap,
                ));
            }
        }
        _ => {}
    }

    let seed_offset = get_seeded_diagonal_offset(window, config);
    let mut seeded = Vec::new();
    for candidate in candidates.iter().take(24) {
        seeded.push(Vec2::new(
            clamp(candidate.x + seed_offset.x, usable_left, usable_right),
            clamp(candidate.y + seed_offset.y, usable_top, usable_bottom),
        ));
    }
    seeded.extend(candidates);
    seeded
}

pub fn find_best_position(
    window: &LegacyManagedWindow,
    placed_windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
    config: &LegacyConfig,
) -> Option<Vec2> {
    let strategies = ["topLeft", "center", "edges", "gaps"];
    let mut best_position = None;
    let mut best_score = f64::MIN;

    for strategy in strategies {
        for candidate in
            generate_position_candidates(window, placed_windows, monitor, strategy, config)
        {
            if candidate.x < monitor.left + config.min_margin
                || candidate.x > monitor.right - window.width - config.min_margin
                || candidate.y < monitor.top + config.min_margin
                || candidate.y > monitor.bottom - window.height - config.min_margin
            {
                continue;
            }

            let mut test_window = window.clone();
            test_window.x = candidate.x;
            test_window.y = candidate.y;
            if !is_overlapping(
                &test_window,
                placed_windows,
                config.stabilization.overlap_tolerance,
            ) {
                let score =
                    score_position(candidate, window, placed_windows, monitor, strategy, config);
                if score > best_score {
                    best_score = score;
                    best_position = Some(candidate);
                }
            }
        }
        if best_position.is_some() && best_score > 0.0 {
            break;
        }
    }

    best_position
}

pub fn pack_windows_optimally(
    windows: &[LegacyManagedWindow],
    monitor: &LegacyMonitor,
    config: &LegacyConfig,
) -> Vec<(u64, Vec2)> {
    let mut placed = Vec::<LegacyManagedWindow>::new();
    let mut output = Vec::new();

    for window in windows {
        if let Some(position) = find_best_position(window, &placed, monitor, config) {
            let mut placed_window = window.clone();
            placed_window.x = position.x;
            placed_window.y = position.y;
            output.push((window.hwnd, position));
            placed.push(placed_window);
        }
    }

    output
}

fn wildcard_like(value: &str, pattern: &str) -> bool {
    let normalized_value = value.to_lowercase();
    let normalized_pattern = pattern.to_lowercase().replace(".*", "").replace('*', "");
    normalized_value.contains(&normalized_pattern)
}
