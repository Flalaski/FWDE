# FWDE AHK Transliteration Map

This file records where the original FWDE.ahk function surface was transliterated in the Linux rewrite.

## Runtime and window helpers

- `IsDropdownOrMenuWindow` -> `fwde_core::legacy_runtime::is_dropdown_or_menu_window`
- `GetOpenDropdownMenuParent` -> `fwde_core::legacy_runtime::get_open_dropdown_menu_parent`
- `AcquireHighResTimer` -> `fwde_core::legacy_runtime::acquire_high_res_timer`
- `ReleaseHighResTimer` -> `fwde_core::legacy_runtime::release_high_res_timer`
- `GetDraggedManagedWindow` -> `fwde_core::legacy_runtime::get_dragged_managed_window`
- `SafeWinExist` -> `fwde_core::legacy_runtime::safe_win_exist`
- `SafeMonitorGet` -> `fwde_core::legacy_runtime::safe_monitor_get`
- `SafeMonitorGetWorkArea` -> `fwde_core::legacy_runtime::safe_monitor_get_work_area`
- `IsFullscreenWindow` -> `fwde_core::legacy_runtime::is_fullscreen_window`
- `IsWindowValid` -> `fwde_core::legacy_runtime::is_window_valid`
- `ShowTooltip` -> `fwde_core::legacy_runtime::show_tooltip`
- `GetCurrentMonitorInfo` -> `fwde_core::legacy_runtime::get_current_monitor_info`
- `MonitorGetFromPoint` -> `fwde_core::legacy_runtime::monitor_get_from_point`
- `GetPrimaryMonitorCoordinates` -> `fwde_core::legacy_runtime::get_primary_monitor_coordinates`
- `GetVirtualDesktopBounds` -> `fwde_core::legacy_runtime::get_virtual_desktop_bounds`
- `FindNonOverlappingPosition` -> `fwde_core::legacy_runtime::find_non_overlapping_position`
- `CreateBlurBehindStruct` -> `fwde_core::legacy_runtime::create_blur_behind_struct`
- `ApplyStabilization` -> `fwde_core::legacy_runtime::apply_stabilization`
- `Bezier3` -> `fwde_core::legacy_runtime::bezier3`
- `SmoothStep` -> `fwde_core::legacy_runtime::smooth_step`
- `CalculateFutureOverlap` -> `fwde_core::legacy_runtime::calculate_future_overlap`
- `Atan2` -> `fwde_core::legacy_runtime::atan2`
- `ResolveCollisions` -> `fwde_core::legacy_runtime::resolve_collisions`
- `AddManualWindowBorder` -> `fwde_core::legacy_runtime::add_manual_window_border`
- `RemoveManualWindowBorder` -> `fwde_core::legacy_runtime::remove_manual_window_border`
- `UpdateManualBorders` -> `fwde_core::legacy_runtime::update_manual_borders`
- `ClearManualFlags` -> `fwde_core::legacy_runtime::clear_manual_flags`
- `DragWindow` -> `fwde_core::legacy_runtime::drag_window`
- `WindowMoveHandler` -> `fwde_core::legacy_runtime::window_move_handler`
- `WindowSizeHandler` -> `fwde_core::legacy_runtime::window_size_handler`
- `UpdateWindowStates` -> `fwde_core::legacy_runtime::update_window_states`
- `MoveWindowAPI` -> `fwde_core::legacy_runtime::move_window_api`
- `PartitionWindows` -> `fwde_core::legacy_runtime::partition_windows`
- `Clamp` -> `fwde_core::legacy_rules::clamp`
- `IsDAWPlugin` -> `fwde_core::legacy_runtime::is_daw_plugin`
- `IsElectronApp` -> `fwde_core::legacy_runtime::is_electron_app`

## Physics and layout

- `Lerp` -> `fwde_core::legacy_rules::lerp`
- `EaseOutCubic` -> `fwde_core::legacy_rules::ease_out_cubic`
- `GetWindowPlacementSeed` -> `fwde_core::legacy_rules::get_window_placement_seed`
- `GetSeededDiagonalOffset` -> `fwde_core::legacy_rules::get_seeded_diagonal_offset`
- `GetSeededPairDirection` -> `fwde_core::legacy_rules::get_seeded_pair_direction`
- `IsOverlapping` -> `fwde_core::legacy_rules::is_overlapping`
- `IsPluginWindow` -> `fwde_core::legacy_rules::is_plugin_window`
- `IsWindowFloating` -> `fwde_core::legacy_rules::is_window_floating`
- `CalculateSpaceSeekingForce` -> `fwde_core::legacy_rules::calculate_space_seeking_force`
- `FindLeastCrowdedDirection` -> `fwde_core::legacy_rules::find_least_crowded_direction`
- `CalculateDensityAtPoint` -> `fwde_core::legacy_rules::calculate_density_at_point`
- `GeneratePositionCandidates` -> `fwde_core::legacy_rules::generate_position_candidates`
- `FindBestPosition` -> `fwde_core::legacy_rules::find_best_position`
- `ScorePosition` -> `fwde_core::legacy_rules::score_position`
- `PackWindowsOptimally` -> `fwde_core::legacy_rules::pack_windows_optimally`
- `CalculateWindowForces` -> `fwde_core::legacy_engine::calculate_dynamic_layout` and internal `calculate_window_forces`
- `ApplyWindowMovements` -> `fwde_core::legacy_engine::apply_window_movements`
- `CalculateDynamicLayout` -> `fwde_core::legacy_engine::calculate_dynamic_layout`
- `ResolveFloatingCollisions` -> `fwde_core::legacy_engine::resolve_floating_collisions`
- `OptimizeWindowPositions` -> `fwde_core::legacy_engine::optimize_window_positions`

## Control flow and toggles

- `ToggleArrangement` -> `fwde_core::legacy_engine::toggle_arrangement`
- `TogglePhysics` -> `fwde_core::legacy_engine::toggle_physics`
- `ToggleMultimonitorExpanse` -> `fwde_core::legacy_engine::toggle_multimonitor_expanse`
- `ToggleWindowLock` -> `fwde_core::legacy_engine::toggle_window_lock`

## Parameter/settings system

- `GetMapValueByPath` -> `fwde_core::legacy_params::get_map_value_by_path`
- `SetMapValueByPath` -> `fwde_core::legacy_params::set_map_value_by_path`
- `GetDecimalPlaces` -> `fwde_core::legacy_params::get_decimal_places`
- `ShouldTreatAsBoolean` -> `fwde_core::legacy_params::should_treat_as_boolean`
- `ShouldSkipParameterPath` -> `fwde_core::legacy_params::should_skip_parameter_path`
- `BuildNumericParamSpec` -> `fwde_core::legacy_params::build_numeric_param_spec`
- `ApplyNumericSpecOverrides` -> `fwde_core::legacy_params::apply_numeric_spec_overrides`
- `CollectParameterSpecsRecursive` -> `fwde_core::legacy_params::collect_parameter_specs_recursive`
- `EnsureParameterSpecs` -> `fwde_core::legacy_params::ensure_parameter_specs`
- `FormatParamDisplay` -> `fwde_core::legacy_params::format_param_display`
- `NormalizeSliderFromConfig` -> `fwde_core::legacy_params::normalize_slider_from_config`
- `NormalizeConfigFromSlider` -> `fwde_core::legacy_params::normalize_config_from_slider`
- `GetSliderDefaultMarkerX` -> `fwde_core::legacy_params::get_slider_default_marker_x`
- `EscapeJsonString` -> `fwde_core::legacy_params::escape_json_string`
- `ToJsonScalar` -> `fwde_core::legacy_params::to_json_scalar`
- `EscapeRegexLiteral` -> `fwde_core::legacy_params::escape_regex_literal`
- `ParseJsonScalar` -> `fwde_core::legacy_params::parse_json_scalar`
- `LoadUserParameterSettings` -> `fwde_core::legacy_params::load_user_parameter_settings`
- `SaveUserParameterSettings` -> `fwde_core::legacy_params::save_user_parameter_settings`
- `ApplySingleParameterDefault` -> `fwde_core::legacy_params::apply_single_parameter_default`
- `ApplyAllParameterDefaults` -> `fwde_core::legacy_params::apply_all_parameter_defaults`
- `OnParameterSliderChange` -> `fwde_core::legacy_params::on_parameter_slider_change`
- `OnParameterCheckboxChange` -> `fwde_core::legacy_params::on_parameter_checkbox_change`
- `OnParameterSliderDoubleClick` -> `fwde_core::legacy_params::on_parameter_slider_double_click`
- `HideParameterHoverTooltip` -> `fwde_core::legacy_params::hide_parameter_hover_tooltip`
- `RegisterParameterHoverControl` -> `fwde_core::legacy_params::register_parameter_hover_control`
- `GetParameterDescription` -> `fwde_core::legacy_params::get_parameter_description`
- `ShowParameterHoverTooltip` -> `fwde_core::legacy_params::show_parameter_hover_tooltip`
- `OnParameterHoverMouseMove` -> `fwde_core::legacy_params::on_parameter_hover_mouse_move`
- `ShowParameterSettingsWindow` -> `fwde_core::legacy_params::show_parameter_settings_window`

## Menus and debugging

- `StatusText` -> `fwde_core::legacy_debug::status_text`
- `GetWindowLockStatusText` -> `fwde_core::legacy_debug::get_window_lock_status_text`
- `BuildFWDEMenus` -> `fwde_core::legacy_debug::build_fwde_menus`
- `RestartFWDE` -> `fwde_core::legacy_debug::restart_fwde`
- `ShowTaskbarMenu` -> `fwde_core::legacy_debug::show_taskbar_menu`
- `GetTaskbarRect` -> `fwde_core::legacy_debug::get_taskbar_rect`
- `ToggleDebugMode` -> `fwde_core::legacy_debug::toggle_debug_mode`
- `DebugWindowInfo` -> `fwde_core::legacy_debug::debug_window_info`
- `ForceAddActiveWindow` -> `fwde_core::legacy_debug::force_add_active_window`
- `DebugActiveWindow` -> `fwde_core::legacy_debug::debug_active_window`
- `OnExit` -> `fwde_core::legacy_debug::on_exit`

## Support helpers

- `CloneMapDeep` -> `fwde_core::legacy_support::clone_map_deep`

## Notes

This is a cold transliteration layer, not a completed Linux-native backend. The structure and behavior names now exist in the Linux fileset so the next phase can replace placeholders with real X11 or compositor integration.
