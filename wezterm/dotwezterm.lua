-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices
-- For example, changing the color scheme:
config.color_scheme = "Catppuccin Frappe"
-- for i3 usage, cleaner
config.window_background_opacity = 0.95
config.enable_tab_bar = false -- remove tab bar
config.window_decorations = "RESIZE" -- this removes title bar
-- remove paddings to remove odd border
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
-- config.front_end = "Software"
config.mux_enable_ssh_agent = false
-- config.debug_key_events = true

-- and finally, return the configuration to wezterm
return config
