local mod = get_mod("ServerPing")

local VIEW_NAME = "server_ping_view"
local HISTORY_VIEW_NAME = "server_ping_history_view"
local RESULT_VIEW_NAME = "server_ping_result_view"
local ENDPOINT_VIEW_NAME = "server_ping_endpoint_view"
local HISTORY_SETTING = "server_ping_history"
local AGGREGATE_SETTING = "server_ping_aggregate"
local AGGREGATE_VERSION = 2
local MAX_HISTORY_ENTRIES = 10
local os = Mods.lua.os
local ping_guard = mod:persistent_table("ping_guard")
local history_state = mod:persistent_table("history_state")

ping_guard.next_allowed_at = ping_guard.next_allowed_at or 0
ping_guard.pending = ping_guard.pending or false
history_state.generation = history_state.generation or 0

local function main_time()
    local time_manager = Managers.time

    return time_manager and time_manager:time("main") or 0
end

local function is_hub()
    local game_mode = Managers.state and Managers.state.game_mode

    return game_mode and game_mode:game_mode_name() == "hub"
end

local function is_matchmaking()
    local party_manager = Managers.party_immaterium

    return party_manager and party_manager:is_in_matchmaking() or false
end

local function close_view()
    local ui = Managers.ui

    if not ui then
        return
    end

    local view_names = {
        ENDPOINT_VIEW_NAME,
        RESULT_VIEW_NAME,
        HISTORY_VIEW_NAME,
        VIEW_NAME,
    }

    for i = 1, #view_names do
        local view_name = view_names[i]
        if ui:view_active(view_name) and not ui:is_view_closing(view_name) then
            ui:close_view(view_name, true)
        end
    end
end

local function any_server_ping_view_active(ui)
    return ui:view_active(VIEW_NAME)
        or ui:view_active(HISTORY_VIEW_NAME)
        or ui:view_active(RESULT_VIEW_NAME)
        or ui:view_active(ENDPOINT_VIEW_NAME)
end

function mod.server_ping_history()
    local stored = mod:get(HISTORY_SETTING)
    if type(stored) ~= "table" then
        return {}
    end

    local history = {}
    for i = 1, #stored do
        local entry = stored[i]
        local result = type(entry) == "table" and entry.result
        local region_latencies = type(result) == "table" and result.region_latencies

        if type(region_latencies) == "table" then
            local valid = true
            for j = 1, #region_latencies do
                if type(region_latencies[j]) ~= "table" then
                    valid = false
                    break
                end
            end

            if valid then
                history[#history + 1] = entry
            end
        end
    end

    return history
end

local function new_aggregate()
    return {
        version = AGGREGATE_VERSION,
        total_tests = 0,
        quick_tests = 0,
        detailed_tests = 0,
        endpoint_total_tests = 0,
        endpoint_history_complete = true,
        regions = {},
    }
end

function mod.server_ping_aggregate()
    local aggregate = mod:get(AGGREGATE_SETTING)

    if type(aggregate) ~= "table" or aggregate.version ~= AGGREGATE_VERSION
        or type(aggregate.regions) ~= "table" then
        return new_aggregate()
    end

    aggregate.endpoint_total_tests = tonumber(aggregate.endpoint_total_tests)
        or tonumber(aggregate.total_tests) or 0
    aggregate.endpoint_history_complete = aggregate.endpoint_history_complete ~= false

    return aggregate
end

local function add_stats(target, stats, successful)
    local minimum = tonumber(stats.min)
    local maximum = tonumber(stats.max)
    local average = tonumber(stats.avg) or 0
    local jitter = tonumber(stats.jitter) or 0

    target.sent = (tonumber(target.sent) or 0) + (tonumber(stats.sent) or 0)
    target.lost = (tonumber(target.lost) or 0) + (tonumber(stats.lost) or 0)

    if minimum and minimum >= 0 then
        local current_min = tonumber(target.min) or -1
        target.min = current_min < 0 and minimum or math.min(current_min, minimum)
    end

    if maximum and maximum >= 0 then
        target.max = math.max(tonumber(target.max) or -1, maximum)
    end

    if successful > 0 then
        target.successful = (tonumber(target.successful) or 0) + successful
        target.weighted_average = (tonumber(target.weighted_average) or 0)
            + math.max(0, average) * successful
        target.weighted_jitter = (tonumber(target.weighted_jitter) or 0)
            + math.max(0, jitter) * successful
    end
end

local function update_server_ping_aggregate(test_id, result, timestamp, date, target_aggregate, defer_save)
    local aggregate = target_aggregate or mod.server_ping_aggregate()
    local regions = aggregate.regions
    local touched_regions = {}

    aggregate.total_tests = (tonumber(aggregate.total_tests) or 0) + 1
    aggregate.quick_tests = (tonumber(aggregate.quick_tests) or 0) + (test_id == "quick" and 1 or 0)
    aggregate.detailed_tests = (tonumber(aggregate.detailed_tests) or 0) + (test_id == "detailed" and 1 or 0)
    aggregate.endpoint_total_tests = (tonumber(aggregate.endpoint_total_tests) or 0) + 1
    aggregate.first_timestamp = aggregate.first_timestamp or timestamp
    aggregate.first_date = aggregate.first_date or date
    aggregate.last_timestamp = timestamp
    aggregate.last_date = date

    local region_latencies = result.region_latencies or {}
    for i = 1, #region_latencies do
        local entry = region_latencies[i]
        local stats = type(entry.stats) == "table" and entry.stats or {}
        local successful = math.max(0, (tonumber(stats.sent) or 0) - (tonumber(stats.lost) or 0))
        local reefs = type(entry.reefs) == "table" and entry.reefs or {}

        for j = 1, #reefs do
            local reef = reefs[j]
            local region = type(reef) == "string" and regions[reef]

            if type(reef) == "string" and type(region) ~= "table" then
                region = {
                    tests = 0,
                    quick_tests = 0,
                    detailed_tests = 0,
                    sent = 0,
                    lost = 0,
                    successful = 0,
                    weighted_average = 0,
                    weighted_jitter = 0,
                    min = -1,
                    max = -1,
                    endpoints = {},
                }
                regions[reef] = region
            end

            if type(reef) == "string" then
                region.endpoints = type(region.endpoints) == "table" and region.endpoints or {}

                if not touched_regions[reef] then
                    region.tests = (tonumber(region.tests) or 0) + 1
                    region.quick_tests = (tonumber(region.quick_tests) or 0) + (test_id == "quick" and 1 or 0)
                    region.detailed_tests = (tonumber(region.detailed_tests) or 0) + (test_id == "detailed" and 1 or 0)
                    touched_regions[reef] = true
                end

                add_stats(region, stats, successful)

                local endpoint_name = type(entry.region) == "string" and entry.region or "unknown"
                local endpoint = region.endpoints[endpoint_name]
                if type(endpoint) ~= "table" then
                    endpoint = {
                        tests = 0,
                        quick_tests = 0,
                        detailed_tests = 0,
                        sent = 0,
                        lost = 0,
                        successful = 0,
                        weighted_average = 0,
                        weighted_jitter = 0,
                        min = -1,
                        max = -1,
                    }
                    region.endpoints[endpoint_name] = endpoint
                end

                endpoint.tests = (tonumber(endpoint.tests) or 0) + 1
                endpoint.quick_tests = (tonumber(endpoint.quick_tests) or 0) + (test_id == "quick" and 1 or 0)
                endpoint.detailed_tests = (tonumber(endpoint.detailed_tests) or 0) + (test_id == "detailed" and 1 or 0)
                add_stats(endpoint, stats, successful)
            end
        end
    end

    if not defer_save then
        mod:set(AGGREGATE_SETTING, aggregate, false)
    end

    return aggregate
end


local function ensure_server_ping_aggregate()
    local stored = mod:get(AGGREGATE_SETTING)
    if type(stored) == "table" and stored.version == AGGREGATE_VERSION
        and type(stored.regions) == "table" then
        return
    end

    local history = mod.server_ping_history()
    local recent_aggregate = new_aggregate()

    for i = #history, 1, -1 do
        local entry = history[i]
        recent_aggregate = update_server_ping_aggregate(entry.test_id, entry.result, entry.timestamp,
            entry.date, recent_aggregate, true)
    end

    local stored_total = type(stored) == "table" and tonumber(stored.total_tests) or 0
    local aggregate = recent_aggregate

    if type(stored) == "table" and type(stored.regions) == "table" and stored_total > #history then
        aggregate = stored
        aggregate.version = AGGREGATE_VERSION
        aggregate.endpoint_total_tests = recent_aggregate.endpoint_total_tests
        aggregate.endpoint_history_complete = false

        for _, region in pairs(aggregate.regions) do
            if type(region) == "table" then
                region.endpoints = {}
            end
        end

        for reef, recent_region in pairs(recent_aggregate.regions) do
            local region = aggregate.regions[reef]
            if type(region) == "table" then
                region.endpoints = recent_region.endpoints
            else
                aggregate.regions[reef] = recent_region
            end
        end
    end

    mod:set(AGGREGATE_SETTING, aggregate, false)
end

function mod.save_server_ping_history(test_id, samples, result)
    local history = mod.server_ping_history()
    local timestamp = os.time()
    local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)

    table.insert(history, 1, {
        timestamp = timestamp,
        date = date,
        test_id = test_id,
        samples = samples,
        result = table.clone(result),
    })

    while #history > MAX_HISTORY_ENTRIES do
        table.remove(history)
    end

    mod:set(HISTORY_SETTING, history, false)
    update_server_ping_aggregate(test_id, result, timestamp, date)
end

function mod.clear_server_ping_history()
    mod:set(HISTORY_SETTING, {}, false)
    mod:set(AGGREGATE_SETTING, new_aggregate(), false)
    history_state.generation = history_state.generation + 1
end

function mod.request_server_ping_history_clear(t)
    if history_state.clear_confirm_until and t <= history_state.clear_confirm_until then
        history_state.clear_confirm_until = nil
        mod.clear_server_ping_history()
        return true
    end

    history_state.clear_confirm_until = t + 5
    return false
end

function mod.server_ping_history_clear_pending(t)
    if history_state.clear_confirm_until and t <= history_state.clear_confirm_until then
        return true
    end

    history_state.clear_confirm_until = nil
    return false
end

function mod.server_ping_history_generation()
    return history_state.generation
end

function mod.server_ping_selected_region()
    local data_service = Managers.data_service
    ---@type RegionLatencyService?
    local region_latency = data_service and data_service.region_latency

    return region_latency and region_latency:get_prefered_mission_region() or nil
end

function mod.select_server_ping_region(reef)
    if type(reef) ~= "string" or reef == "" then
        return false
    end

    local data_service = Managers.data_service
    ---@type RegionLatencyService?
    local region_latency = data_service and data_service.region_latency

    if not region_latency then
        return false
    end

    region_latency:set_prefered_mission_region(reef)

    return region_latency:get_prefered_mission_region() == reef
end

function mod.server_ping_cooldown_remaining()
    return math.max(0, math.ceil(ping_guard.next_allowed_at - main_time()))
end

function mod.server_ping_pending()
    return ping_guard.pending
end

function mod.begin_server_ping(cooldown)
    local remaining = mod.server_ping_cooldown_remaining()

    if ping_guard.pending then
        return false, math.max(1, remaining)
    end

    if remaining > 0 then
        return false, remaining
    end

    ping_guard.pending = true
    ping_guard.pending_cooldown = cooldown

    return true, cooldown
end

function mod.finish_server_ping()
    local cooldown = ping_guard.pending_cooldown

    ping_guard.pending = false
    ping_guard.pending_cooldown = nil

    if cooldown then
        ping_guard.next_allowed_at = main_time() + cooldown
    end
end

function mod.open_server_ping()
    local ui = Managers.ui

    if not ui then
        return
    end

    if any_server_ping_view_active(ui) then
        close_view()
        return
    end

    if not is_hub() then
        mod:echo(mod:localize("status_hub_only"))
        return
    end

    if is_matchmaking() or ui:view_active("mission_board_view") then
        mod:echo(mod:localize("status_busy"))
        return
    end

    ui:open_view(VIEW_NAME, nil, false, false, nil, {}, { use_transition_ui = false })
end

function mod.open_server_ping_history()
    local ui = Managers.ui

    if ui and not ui:view_active(HISTORY_VIEW_NAME) then
        ui:open_view(HISTORY_VIEW_NAME, nil, false, false, nil, {}, { use_transition_ui = false })
    end
end

function mod.open_server_ping_result(history_entry)
    local ui = Managers.ui

    if ui and not ui:view_active(RESULT_VIEW_NAME) then
        ui:open_view(RESULT_VIEW_NAME, nil, false, false, nil, {
            history_entry = history_entry,
        }, { use_transition_ui = false })
    end
end

function mod.open_server_ping_endpoints(context)
    local ui = Managers.ui

    if ui and not ui:view_active(ENDPOINT_VIEW_NAME) then
        ui:open_view(ENDPOINT_VIEW_NAME, nil, false, false, nil, context or {}, { use_transition_ui = false })
    end
end

function mod.on_all_mods_loaded()
    local view_path = "ServerPing/scripts/mods/ServerPing/ServerPing_view"
    local history_view_path = "ServerPing/scripts/mods/ServerPing/ServerPing_history_view"
    local result_view_path = "ServerPing/scripts/mods/ServerPing/ServerPing_result_view"
    local endpoint_view_path = "ServerPing/scripts/mods/ServerPing/ServerPing_endpoint_view"

    ensure_server_ping_aggregate()

    mod:add_require_path(view_path)
    mod:add_require_path(history_view_path)
    mod:add_require_path(result_view_path)
    mod:add_require_path(endpoint_view_path)
    mod:register_view({
        view_name = VIEW_NAME,
        view_settings = {
            init_view_function = function()
                return true
            end,
            class = "ServerPingView",
            disable_game_world = false,
            display_name = "view_title",
            game_world_blur = 0.8,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = view_path,
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
        },
    })
    mod:io_dofile(view_path)

    mod:register_view({
        view_name = RESULT_VIEW_NAME,
        view_settings = {
            init_view_function = function()
                return true
            end,
            class = "ServerPingResultView",
            disable_game_world = false,
            display_name = "view_title",
            game_world_blur = 0.8,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = result_view_path,
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
        },
    })
    mod:io_dofile(result_view_path)

    mod:register_view({
        view_name = HISTORY_VIEW_NAME,
        view_settings = {
            init_view_function = function()
                return true
            end,
            class = "ServerPingHistoryView",
            disable_game_world = false,
            display_name = "history_title",
            game_world_blur = 0.8,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = history_view_path,
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
        },
    })
    mod:io_dofile(history_view_path)

    mod:register_view({
        view_name = ENDPOINT_VIEW_NAME,
        view_settings = {
            init_view_function = function()
                return true
            end,
            class = "ServerPingEndpointView",
            disable_game_world = false,
            display_name = "view_title",
            game_world_blur = 0.8,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = endpoint_view_path,
            state_bound = false,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
            wwise_states = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
        },
    })
    mod:io_dofile(endpoint_view_path)
end

function mod.on_disabled()
    close_view()
end

function mod.on_game_state_changed(status, state_name)
    if status == "exit" and state_name == "StateGameplay" then
        close_view()
    end
end

function mod.on_unload()
    close_view()
end
