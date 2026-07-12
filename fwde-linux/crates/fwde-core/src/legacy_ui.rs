use crate::{legacy_debug::MenuModel, legacy_params::ParamSpec, legacy_runtime::TooltipMessage};

#[derive(Debug, Clone, PartialEq)]
pub struct ParameterSettingsWindowModel {
    pub specs: Vec<ParamSpec>,
    pub help_tooltip: Option<String>,
}

pub fn build_parameter_settings_window(
    specs: Vec<ParamSpec>,
    help_tooltip: Option<String>,
) -> ParameterSettingsWindowModel {
    ParameterSettingsWindowModel {
        specs,
        help_tooltip,
    }
}

pub fn render_tooltip(message: TooltipMessage) -> String {
    message.text
}

pub fn render_menu(model: &MenuModel) -> usize {
    model.main_items.len() + model.debug_items.len()
}
