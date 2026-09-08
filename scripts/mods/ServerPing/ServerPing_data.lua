local mod = get_mod("ServerPing")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "open_server_ping",
                type = "keybind",
                default_value = { "f6" },
                title = "open_server_ping",
                tooltip = "open_server_ping_tooltip",
                keybind_trigger = "pressed",
                keybind_type = "function_call",
                function_name = "open_server_ping",
            },
        },
    },
}
