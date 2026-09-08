return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ServerPing` failed loading DMF.")
        new_mod("ServerPing", {
            mod_script = "ServerPing/scripts/mods/ServerPing/ServerPing",
            mod_data = "ServerPing/scripts/mods/ServerPing/ServerPing_data",
            mod_localization = "ServerPing/scripts/mods/ServerPing/ServerPing_localization",
        })
    end,
    packages = {},
}
