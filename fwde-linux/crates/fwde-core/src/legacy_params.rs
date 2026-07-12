use std::{collections::BTreeMap, fs, path::Path};

use crate::legacy_config::{LegacyConfig, StabilizationConfig};

#[derive(Debug, Clone, PartialEq)]
pub enum ParamType {
    Bool,
    Number,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ParamSpec {
    pub path: String,
    pub label: String,
    pub kind: ParamType,
    pub default_value: ParamValue,
    pub decimals: u32,
    pub scale: f64,
    pub min: f64,
    pub max: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ParamValue {
    Bool(bool),
    Number(f64),
    Text(String),
}

pub fn get_map_value_by_path(config: &LegacyConfig, path: &str) -> Option<ParamValue> {
    Some(match path {
        "MinMargin" => ParamValue::Number(config.min_margin),
        "MinGap" => ParamValue::Number(config.min_gap),
        "SeedDiagonalStep" => ParamValue::Number(config.seed_diagonal_step),
        "SeedDiagonalMaxSteps" => ParamValue::Number(config.seed_diagonal_max_steps as f64),
        "SeedJitterRange" => ParamValue::Number(config.seed_jitter_range),
        "ManualGapBonus" => ParamValue::Number(config.manual_gap_bonus),
        "AttractionForce" => ParamValue::Number(config.attraction_force),
        "RepulsionForce" => ParamValue::Number(config.repulsion_force),
        "EdgeRepulsionForce" => ParamValue::Number(config.edge_repulsion_force),
        "CollisionOverlapThreshold" => ParamValue::Number(config.collision_overlap_threshold),
        "RepulsionRangeMultiplier" => ParamValue::Number(config.repulsion_range_multiplier),
        "RepulsionImpulseScale" => ParamValue::Number(config.repulsion_impulse_scale),
        "SmallWindowReferenceDim" => ParamValue::Number(config.small_window_reference_dim),
        "MaxSmallWindowRepulsionBoost" => {
            ParamValue::Number(config.max_small_window_repulsion_boost)
        }
        "PairSeparationBase" => ParamValue::Number(config.pair_separation_base),
        "PairSeparationOverlapScale" => ParamValue::Number(config.pair_separation_overlap_scale),
        "PairSmallWindowBoost" => ParamValue::Number(config.pair_small_window_boost),
        "SmallWindowThresholdW" => ParamValue::Number(config.small_window_threshold_w),
        "SmallWindowThresholdH" => ParamValue::Number(config.small_window_threshold_h),
        "UserMoveTimeout" => ParamValue::Number(config.user_move_timeout_ms as f64),
        "ManualLockDuration" => ParamValue::Number(config.manual_lock_duration_ms as f64),
        "ResizeDelay" => ParamValue::Number(config.resize_delay_ms as f64),
        "TooltipDuration" => ParamValue::Number(config.tooltip_duration_ms as f64),
        "ParameterHelpTooltipDuration" => {
            ParamValue::Number(config.parameter_help_tooltip_duration_ms as f64)
        }
        "MultimonitorExpanse" => ParamValue::Bool(config.multimonitor_expanse),
        "Damping" => ParamValue::Number(config.damping),
        "MaxSpeed" => ParamValue::Number(config.max_speed),
        "PhysicsTimeStep" => ParamValue::Number(config.physics_time_step_ms as f64),
        "VisualTimeStep" => ParamValue::Number(config.visual_time_step_ms as f64),
        "Smoothing" => ParamValue::Number(config.smoothing),
        "ManualWindowAlpha" => ParamValue::Number(config.manual_window_alpha as f64),
        "NoiseScale" => ParamValue::Number(config.noise_scale),
        "NoiseInfluence" => ParamValue::Number(config.noise_influence),
        "AnimationDuration" => ParamValue::Number(config.animation_duration_ms as f64),
        "PhysicsUpdateInterval" => ParamValue::Number(config.physics_update_interval_ms as f64),
        "ManualRepulsionMultiplier" => ParamValue::Number(config.manual_repulsion_multiplier),
        "Stabilization.MinSpeedThreshold" => {
            ParamValue::Number(config.stabilization.min_speed_threshold)
        }
        "Stabilization.EnergyThreshold" => {
            ParamValue::Number(config.stabilization.energy_threshold)
        }
        "Stabilization.DampingBoost" => ParamValue::Number(config.stabilization.damping_boost),
        "Stabilization.OverlapTolerance" => {
            ParamValue::Number(config.stabilization.overlap_tolerance)
        }
        _ => return None,
    })
}

pub fn set_map_value_by_path(config: &mut LegacyConfig, path: &str, value: ParamValue) -> bool {
    match (path, value) {
        ("MinMargin", ParamValue::Number(v)) => config.min_margin = v,
        ("MinGap", ParamValue::Number(v)) => config.min_gap = v,
        ("SeedDiagonalStep", ParamValue::Number(v)) => config.seed_diagonal_step = v,
        ("SeedDiagonalMaxSteps", ParamValue::Number(v)) => {
            config.seed_diagonal_max_steps = v.round() as u32
        }
        ("SeedJitterRange", ParamValue::Number(v)) => config.seed_jitter_range = v,
        ("ManualGapBonus", ParamValue::Number(v)) => config.manual_gap_bonus = v,
        ("AttractionForce", ParamValue::Number(v)) => config.attraction_force = v,
        ("RepulsionForce", ParamValue::Number(v)) => config.repulsion_force = v,
        ("EdgeRepulsionForce", ParamValue::Number(v)) => config.edge_repulsion_force = v,
        ("CollisionOverlapThreshold", ParamValue::Number(v)) => {
            config.collision_overlap_threshold = v
        }
        ("RepulsionRangeMultiplier", ParamValue::Number(v)) => {
            config.repulsion_range_multiplier = v
        }
        ("RepulsionImpulseScale", ParamValue::Number(v)) => config.repulsion_impulse_scale = v,
        ("SmallWindowReferenceDim", ParamValue::Number(v)) => config.small_window_reference_dim = v,
        ("MaxSmallWindowRepulsionBoost", ParamValue::Number(v)) => {
            config.max_small_window_repulsion_boost = v
        }
        ("PairSeparationBase", ParamValue::Number(v)) => config.pair_separation_base = v,
        ("PairSeparationOverlapScale", ParamValue::Number(v)) => {
            config.pair_separation_overlap_scale = v
        }
        ("PairSmallWindowBoost", ParamValue::Number(v)) => config.pair_small_window_boost = v,
        ("SmallWindowThresholdW", ParamValue::Number(v)) => config.small_window_threshold_w = v,
        ("SmallWindowThresholdH", ParamValue::Number(v)) => config.small_window_threshold_h = v,
        ("UserMoveTimeout", ParamValue::Number(v)) => {
            config.user_move_timeout_ms = v.round() as u64
        }
        ("ManualLockDuration", ParamValue::Number(v)) => {
            config.manual_lock_duration_ms = v.round() as u64
        }
        ("ResizeDelay", ParamValue::Number(v)) => config.resize_delay_ms = v.round() as u64,
        ("TooltipDuration", ParamValue::Number(v)) => config.tooltip_duration_ms = v.round() as u64,
        ("ParameterHelpTooltipDuration", ParamValue::Number(v)) => {
            config.parameter_help_tooltip_duration_ms = v.round() as u64
        }
        ("MultimonitorExpanse", ParamValue::Bool(v)) => config.multimonitor_expanse = v,
        ("Damping", ParamValue::Number(v)) => config.damping = v,
        ("MaxSpeed", ParamValue::Number(v)) => config.max_speed = v,
        ("PhysicsTimeStep", ParamValue::Number(v)) => {
            config.physics_time_step_ms = v.round() as u64
        }
        ("VisualTimeStep", ParamValue::Number(v)) => config.visual_time_step_ms = v.round() as u64,
        ("Smoothing", ParamValue::Number(v)) => config.smoothing = v,
        ("ManualWindowAlpha", ParamValue::Number(v)) => {
            config.manual_window_alpha = v.round() as u8
        }
        ("NoiseScale", ParamValue::Number(v)) => config.noise_scale = v,
        ("NoiseInfluence", ParamValue::Number(v)) => config.noise_influence = v,
        ("AnimationDuration", ParamValue::Number(v)) => {
            config.animation_duration_ms = v.round() as u64
        }
        ("PhysicsUpdateInterval", ParamValue::Number(v)) => {
            config.physics_update_interval_ms = v.round() as u64
        }
        ("ManualRepulsionMultiplier", ParamValue::Number(v)) => {
            config.manual_repulsion_multiplier = v
        }
        ("Stabilization.MinSpeedThreshold", ParamValue::Number(v)) => {
            config.stabilization.min_speed_threshold = v
        }
        ("Stabilization.EnergyThreshold", ParamValue::Number(v)) => {
            config.stabilization.energy_threshold = v
        }
        ("Stabilization.DampingBoost", ParamValue::Number(v)) => {
            config.stabilization.damping_boost = v
        }
        ("Stabilization.OverlapTolerance", ParamValue::Number(v)) => {
            config.stabilization.overlap_tolerance = v
        }
        _ => return false,
    }
    true
}

pub fn get_decimal_places(value: f64) -> u32 {
    let rendered = format!("{value:.6}")
        .trim_end_matches('0')
        .trim_end_matches('.')
        .to_string();
    rendered
        .split('.')
        .nth(1)
        .map(|fraction| fraction.len() as u32)
        .unwrap_or(0)
}

pub fn should_treat_as_boolean(path: &str) -> bool {
    matches!(path, "MultimonitorExpanse")
}

pub fn should_skip_parameter_path(path: &str) -> bool {
    matches!(path, "FloatStyles")
}

pub fn build_numeric_param_spec(path: &str, default_value: f64) -> ParamSpec {
    let is_int = (default_value.round() - default_value).abs() < f64::EPSILON;
    let (decimals, scale, min, max) = if is_int {
        let max = if default_value >= 0.0 {
            (default_value * 2.5).ceil().max(10.0)
        } else {
            default_value.abs().mul_add(2.5, 0.0).ceil().max(10.0)
        };
        let min = if default_value >= 0.0 { 0.0 } else { -max };
        (0, 1.0, min, max)
    } else {
        let decimals = get_decimal_places(default_value)
            .saturating_add(1)
            .clamp(2, 6);
        let scale = 10f64.powi(decimals as i32);
        let max = if default_value >= 0.0 {
            (default_value * 2.5).max(default_value + 0.05)
        } else {
            default_value
                .abs()
                .mul_add(2.5, 0.0)
                .max(default_value.abs() + 0.05)
        };
        let min = if default_value >= 0.0 { 0.0 } else { -max };
        (decimals, scale, min, max)
    };

    apply_numeric_spec_overrides(ParamSpec {
        path: path.to_string(),
        label: path.replace('.', " - "),
        kind: ParamType::Number,
        default_value: ParamValue::Number(default_value),
        decimals,
        scale,
        min,
        max,
    })
}

pub fn apply_numeric_spec_overrides(mut spec: ParamSpec) -> ParamSpec {
    let overrides: BTreeMap<&str, (f64, f64, u32)> = BTreeMap::from([
        ("AttractionForce", (0.0, 0.002, 6)),
        ("RepulsionForce", (0.05, 5.0, 3)),
        ("EdgeRepulsionForce", (0.05, 5.0, 3)),
        ("RepulsionRangeMultiplier", (0.5, 4.0, 3)),
        ("RepulsionImpulseScale", (0.05, 2.5, 3)),
        ("PairSeparationBase", (0.001, 0.08, 4)),
        ("PairSeparationOverlapScale", (0.1, 8.0, 3)),
        ("PairSmallWindowBoost", (1.0, 3.0, 3)),
        ("MaxSmallWindowRepulsionBoost", (1.0, 4.0, 3)),
        ("SmallWindowReferenceDim", (80.0, 1200.0, 0)),
        ("CollisionOverlapThreshold", (0.0, 20.0, 0)),
        ("SmallWindowThresholdW", (80.0, 1200.0, 0)),
        ("SmallWindowThresholdH", (60.0, 900.0, 0)),
        ("Damping", (0.0001, 1.0, 4)),
        ("MaxSpeed", (1.0, 60.0, 2)),
        ("PhysicsTimeStep", (1.0, 33.0, 0)),
        ("VisualTimeStep", (1.0, 100.0, 0)),
        ("Smoothing", (0.0, 0.999, 3)),
        ("ParameterHelpTooltipDuration", (300.0, 10_000.0, 0)),
        ("ManualRepulsionMultiplier", (0.1, 6.0, 3)),
        ("Stabilization.MinSpeedThreshold", (0.0, 2.0, 3)),
        ("Stabilization.EnergyThreshold", (0.0, 2.0, 3)),
        ("Stabilization.DampingBoost", (0.0, 1.0, 3)),
        ("Stabilization.OverlapTolerance", (0.0, 50.0, 0)),
    ]);

    if let Some((min, max, decimals)) = overrides.get(spec.path.as_str()).copied() {
        spec.decimals = decimals;
        spec.scale = 10f64.powi(decimals as i32);
        spec.min = min;
        spec.max = max;
    }
    if spec.max <= spec.min {
        spec.max = spec.min + 1.0;
    }
    spec
}

pub fn collect_parameter_specs_recursive(config: &LegacyConfig) -> Vec<ParamSpec> {
    let mut specs = Vec::new();
    let fields = [
        "MinMargin",
        "MinGap",
        "SeedDiagonalStep",
        "SeedDiagonalMaxSteps",
        "SeedJitterRange",
        "ManualGapBonus",
        "AttractionForce",
        "RepulsionForce",
        "EdgeRepulsionForce",
        "CollisionOverlapThreshold",
        "RepulsionRangeMultiplier",
        "RepulsionImpulseScale",
        "SmallWindowReferenceDim",
        "MaxSmallWindowRepulsionBoost",
        "PairSeparationBase",
        "PairSeparationOverlapScale",
        "PairSmallWindowBoost",
        "SmallWindowThresholdW",
        "SmallWindowThresholdH",
        "UserMoveTimeout",
        "ManualLockDuration",
        "ResizeDelay",
        "TooltipDuration",
        "ParameterHelpTooltipDuration",
        "MultimonitorExpanse",
        "Damping",
        "MaxSpeed",
        "PhysicsTimeStep",
        "VisualTimeStep",
        "Smoothing",
        "ManualWindowAlpha",
        "NoiseScale",
        "NoiseInfluence",
        "AnimationDuration",
        "PhysicsUpdateInterval",
        "ManualRepulsionMultiplier",
        "Stabilization.MinSpeedThreshold",
        "Stabilization.EnergyThreshold",
        "Stabilization.DampingBoost",
        "Stabilization.OverlapTolerance",
    ];

    for path in fields {
        if should_skip_parameter_path(path) {
            continue;
        }
        if should_treat_as_boolean(path) {
            if let Some(ParamValue::Bool(value)) = get_map_value_by_path(config, path) {
                specs.push(ParamSpec {
                    path: path.to_string(),
                    label: path.replace('.', " - "),
                    kind: ParamType::Bool,
                    default_value: ParamValue::Bool(value),
                    decimals: 0,
                    scale: 1.0,
                    min: 0.0,
                    max: 1.0,
                });
            }
        } else if let Some(ParamValue::Number(value)) = get_map_value_by_path(config, path) {
            specs.push(build_numeric_param_spec(path, value));
        }
    }

    specs
}

pub fn ensure_parameter_specs(config: &LegacyConfig) -> Vec<ParamSpec> {
    collect_parameter_specs_recursive(config)
}

pub fn format_param_display(spec: &ParamSpec, value: &ParamValue) -> String {
    match (&spec.kind, value) {
        (ParamType::Bool, ParamValue::Bool(v)) => {
            if *v {
                "On".to_string()
            } else {
                "Off".to_string()
            }
        }
        (ParamType::Number, ParamValue::Number(v)) if spec.decimals == 0 => format!("{v:.0}"),
        (ParamType::Number, ParamValue::Number(v)) => format!("{:.*}", spec.decimals as usize, v),
        (_, ParamValue::Text(v)) => v.clone(),
        _ => String::new(),
    }
}

pub fn normalize_slider_from_config(spec: &ParamSpec, value: f64) -> f64 {
    value * spec.scale
}

pub fn normalize_config_from_slider(spec: &ParamSpec, slider_value: f64) -> f64 {
    let numeric = slider_value / spec.scale;
    if spec.decimals == 0 {
        numeric.round()
    } else {
        let factor = 10f64.powi(spec.decimals as i32);
        (numeric * factor).round() / factor
    }
}

pub fn get_slider_default_marker_x(slider_x: f64, slider_width: f64, spec: &ParamSpec) -> f64 {
    let ParamValue::Number(default_value) = spec.default_value.clone() else {
        return slider_x;
    };
    let default_slider = normalize_slider_from_config(spec, default_value)
        .clamp(spec.min * spec.scale, spec.max * spec.scale);
    let span = ((spec.max - spec.min) * spec.scale).max(1.0);
    let ratio = (default_slider - spec.min * spec.scale) / span;
    slider_x + ratio * slider_width
}

pub fn escape_json_string(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\r', "\\r")
        .replace('\n', "\\n")
        .replace('\t', "\\t")
}

pub fn to_json_scalar(value: &ParamValue) -> String {
    match value {
        ParamValue::Number(v) => format!("{v:.10}"),
        ParamValue::Bool(v) => v.to_string(),
        ParamValue::Text(v) => format!("\"{}\"", escape_json_string(v)),
    }
}

pub fn escape_regex_literal(text: &str) -> String {
    text.replace('.', "\\.")
        .replace('^', "\\^")
        .replace('$', "\\$")
        .replace('|', "\\|")
        .replace('(', "\\(")
        .replace(')', "\\)")
        .replace('[', "\\[")
        .replace(']', "\\]")
        .replace('{', "\\{")
        .replace('}', "\\}")
        .replace('*', "\\*")
        .replace('+', "\\+")
        .replace('?', "\\?")
        .replace('-', "\\-")
}

pub fn parse_json_scalar(text: &str) -> ParamValue {
    let trimmed = text.trim();
    if trimmed == "true" {
        return ParamValue::Bool(true);
    }
    if trimmed == "false" {
        return ParamValue::Bool(false);
    }
    if let Ok(number) = trimmed.trim_matches('"').parse::<f64>() {
        return ParamValue::Number(number);
    }
    ParamValue::Text(trimmed.trim_matches('"').to_string())
}

pub fn load_user_parameter_settings(
    path: &Path,
    config: &mut LegacyConfig,
) -> std::io::Result<usize> {
    let content = fs::read_to_string(path)?;
    let specs = ensure_parameter_specs(config);
    let mut changes = 0;

    for spec in specs {
        let key = format!("\"{}\":", spec.path);
        if let Some(start) = content.find(&key) {
            let slice = &content[start + key.len()..];
            let raw = slice
                .lines()
                .next()
                .unwrap_or("")
                .trim()
                .trim_end_matches(',');
            let value = parse_json_scalar(raw);
            if set_map_value_by_path(config, &spec.path, value) {
                changes += 1;
            }
        }
    }

    Ok(changes)
}

pub fn save_user_parameter_settings(path: &Path, config: &LegacyConfig) -> std::io::Result<()> {
    let specs = ensure_parameter_specs(config);
    let mut lines = vec![
        "{".to_string(),
        "  \"_metadata\": {".to_string(),
        "    \"application\": \"FWDE\",".to_string(),
        "    \"format\": \"flat-path-v1\"".to_string(),
        "  },".to_string(),
    ];

    for (index, spec) in specs.iter().enumerate() {
        let value =
            get_map_value_by_path(config, &spec.path).unwrap_or(ParamValue::Text(String::new()));
        let trailing = if index + 1 == specs.len() { "" } else { "," };
        lines.push(format!(
            "  \"{}\": {}{}",
            escape_json_string(&spec.path),
            to_json_scalar(&value),
            trailing
        ));
    }
    lines.push("}".to_string());
    fs::write(path, lines.join("\n"))
}

pub fn apply_single_parameter_default(
    config: &mut LegacyConfig,
    defaults: &LegacyConfig,
    path: &str,
) -> bool {
    if let Some(value) = get_map_value_by_path(defaults, path) {
        set_map_value_by_path(config, path, value)
    } else {
        false
    }
}

pub fn apply_all_parameter_defaults(config: &mut LegacyConfig, defaults: &LegacyConfig) {
    *config = defaults.clone();
}

pub fn on_parameter_slider_change(
    config: &mut LegacyConfig,
    spec: &ParamSpec,
    slider_value: f64,
) -> bool {
    set_map_value_by_path(
        config,
        &spec.path,
        ParamValue::Number(normalize_config_from_slider(spec, slider_value)),
    )
}

pub fn on_parameter_checkbox_change(config: &mut LegacyConfig, path: &str, checked: bool) -> bool {
    set_map_value_by_path(config, path, ParamValue::Bool(checked))
}

pub fn on_parameter_slider_double_click(
    config: &mut LegacyConfig,
    defaults: &LegacyConfig,
    path: &str,
) -> bool {
    apply_single_parameter_default(config, defaults, path)
}

pub fn hide_parameter_hover_tooltip() -> &'static str {
    "hide-parameter-hover-tooltip"
}

pub fn register_parameter_hover_control(control_id: u64, path: &str) -> (u64, String) {
    (control_id, path.to_string())
}

pub fn get_parameter_description(path: &str) -> String {
    match path {
        "AttractionForce" => {
            "Controls how strongly windows drift back toward equilibrium.".to_string()
        }
        "RepulsionForce" => "Controls how strongly overlapping windows push apart.".to_string(),
        "Damping" => "Controls how quickly window momentum dissipates.".to_string(),
        _ => "Runtime tuning parameter for FWDE window behavior.".to_string(),
    }
}

pub fn show_parameter_hover_tooltip(path: &str, config: &LegacyConfig) -> Option<String> {
    let specs = ensure_parameter_specs(config);
    let spec = specs.into_iter().find(|spec| spec.path == path)?;
    let current = get_map_value_by_path(config, path)?;
    Some(format!(
        "{}\n{}\nCurrent: {}   Default: {}",
        spec.label,
        get_parameter_description(path),
        format_param_display(&spec, &current),
        format_param_display(&spec, &spec.default_value)
    ))
}

pub fn on_parameter_hover_mouse_move(path: &str, config: &LegacyConfig) -> Option<String> {
    show_parameter_hover_tooltip(path, config)
}

pub fn show_parameter_settings_window(config: &LegacyConfig) -> Vec<ParamSpec> {
    ensure_parameter_specs(config)
}

#[allow(dead_code)]
fn _stabilization_clone(config: &StabilizationConfig) -> StabilizationConfig {
    config.clone()
}
