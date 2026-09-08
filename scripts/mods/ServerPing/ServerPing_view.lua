local mod = get_mod("ServerPing")

local RegionLatency = require("scripts/backend/region_latency")
local RegionLocalizationMappings = require("scripts/settings/backend/region_localization")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local ServerPingView = class("ServerPingView", "BaseView")

local BASE_Z = 100
local VIEW_WIDTH = 1120
local VIEW_HEIGHT = 700
local MAX_ROWS = 12
local ROW_HEIGHT = 34
local ROW_TOP = 152
local TESTS = {
    quick = { rounds = 1, samples = 10, cooldown = 60, label = "ping_servers" },
    detailed = { rounds = 3, samples = 30, cooldown = 300, label = "detailed_test" },
}

local COLORS = {
    overlay = { 170, 0, 0, 0 },
    panel = { 248, 7, 13, 13 },
    frame = { 220, 55, 96, 84 },
    header = { 255, 190, 220, 205 },
    text = { 255, 215, 226, 220 },
    dim = { 185, 125, 145, 138 },
    row = { 195, 12, 22, 20 },
    row_alt = { 215, 16, 29, 26 },
    button = { 245, 34, 84, 70 },
    button_hover = { 255, 52, 125, 101 },
    button_disabled = { 150, 32, 42, 39 },
    button_text = { 255, 245, 250, 247 },
    good = { 255, 92, 220, 130 },
    warning = { 255, 240, 190, 75 },
    bad = { 255, 240, 91, 77 },
    recommended = { 255, 114, 224, 190 },
}

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    panel = {
        horizontal_alignment = "center",
        parent = "screen",
        vertical_alignment = "center",
        size = { VIEW_WIDTH, VIEW_HEIGHT },
        position = { 0, 0, BASE_Z },
    },
}

local function text_pass(value_id, text, x, y, width, height, font_size, color, alignment, z)
    return {
        pass_type = "text",
        value_id = value_id,
        value = text,
        style_id = value_id,
        style = {
            font_size = font_size,
            font_type = "machine_medium",
            offset = { x, y, z or BASE_Z + 4 },
            size = { width, height },
            text_horizontal_alignment = alignment or "left",
            text_vertical_alignment = "center",
            text_color = color,
        },
    }
end

local function row_definition(index)
    local y = ROW_TOP + (index - 1) * ROW_HEIGHT
    local background = index % 2 == 0 and COLORS.row_alt or COLORS.row

    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = {
                offset = { 24, y, BASE_Z + 5 },
                size = { 880, ROW_HEIGHT - 2 },
            },
        },
        {
            pass_type = "hotspot",
            content_id = "select_hotspot",
            style = {
                offset = { 914, y + 3, BASE_Z + 6 },
                size = { 170, ROW_HEIGHT - 8 },
            },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                offset = { 24, y, BASE_Z + 2 },
                size = { VIEW_WIDTH - 48, ROW_HEIGHT - 2 },
                color = { background[1], background[2], background[3], background[4] },
            },
            change_function = function(content, style)
                local target = content.hotspot.is_hover and COLORS.button_hover or background
                style.color[1] = target[1]
                style.color[2] = target[2]
                style.color[3] = target[3]
                style.color[4] = target[4]
            end,
        },
        {
            pass_type = "rect",
            style_id = "select_background",
            style = {
                offset = { 914, y + 3, BASE_Z + 4 },
                size = { 170, ROW_HEIGHT - 8 },
                color = { COLORS.button[1], COLORS.button[2], COLORS.button[3], COLORS.button[4] },
            },
            change_function = function(content, style)
                local target = content.selected and COLORS.recommended
                    or content.select_hotspot.is_hover and COLORS.button_hover
                    or COLORS.button
                style.color[1] = target[1]
                style.color[2] = target[2]
                style.color[3] = target[3]
                style.color[4] = target[4]
            end,
        },
        text_pass("region", "", 38, y, 236, ROW_HEIGHT, 16, COLORS.text),
        text_pass("median", "", 280, y, 96, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("average", "", 382, y, 96, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("minimum", "", 484, y, 88, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("maximum", "", 578, y, 88, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("jitter", "", 672, y, 96, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("loss", "", 774, y, 130, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("note", "", 914, y, 170, ROW_HEIGHT, 13, COLORS.button_text, "center", BASE_Z + 7),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT })
end

local widget_definitions = {
    overlay = UIWidget.create_definition({
        { pass_type = "rect", style = { color = COLORS.overlay } },
    }, "screen"),
    panel = UIWidget.create_definition({
        {
            pass_type = "texture",
            value = "content/ui/materials/backgrounds/default_square",
            style = { hdr = true, color = COLORS.panel },
        },
        {
            pass_type = "texture",
            value = "content/ui/materials/frames/frame_tile_2px",
            style = { hdr = true, color = COLORS.frame, scale_to_material = true, offset = { 0, 0, 2 } },
        },
        text_pass("title", mod:localize("view_title"), 36, 22, VIEW_WIDTH - 72, 38, 30, COLORS.header),
        text_pass("subtitle", mod:localize("view_subtitle"), 38, 60, VIEW_WIDTH - 76, 28, 15, COLORS.dim),
        { pass_type = "rect", style = { offset = { 24, 108, BASE_Z + 2 }, size = { VIEW_WIDTH - 48, 2 }, color = COLORS.frame } },
        text_pass("region_header", mod:localize("header_region"), 38, 116, 236, 28, 13, COLORS.dim),
        text_pass("median_header", mod:localize("header_median"), 280, 116, 96, 28, 13, COLORS.dim, "center"),
        text_pass("average_header", mod:localize("header_average"), 382, 116, 96, 28, 13, COLORS.dim, "center"),
        text_pass("minimum_header", mod:localize("header_minimum"), 484, 116, 88, 28, 13, COLORS.dim, "center"),
        text_pass("maximum_header", mod:localize("header_maximum"), 578, 116, 88, 28, 13, COLORS.dim, "center"),
        text_pass("jitter_header", mod:localize("header_jitter"), 672, 116, 96, 28, 13, COLORS.dim, "center"),
        text_pass("loss_header", mod:localize("header_loss"), 774, 116, 130, 28, 13, COLORS.dim, "center"),
        text_pass("note_header", mod:localize("header_note"), 914, 116, 170, 28, 13, COLORS.dim, "center"),
        text_pass("status", mod:localize("status_idle"), 38, 574, 460, 36, 16, COLORS.text),
        text_pass("footer", mod:localize("footer_hint"), 38, 650, VIEW_WIDTH - 76, 28, 14, COLORS.dim),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
    ping_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { 710, 570, BASE_Z + 5 }, size = { 180, 48 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = { offset = { 710, 570, BASE_Z + 4 }, size = { 180, 48 }, color = COLORS.button },
            change_function = function(content, style)
                local hotspot = content.hotspot
                local color = hotspot.disabled and COLORS.button_disabled
                    or hotspot.is_hover and COLORS.button_hover
                    or COLORS.button

                style.color[1] = color[1]
                style.color[2] = color[2]
                style.color[3] = color[3]
                style.color[4] = color[4]
            end,
        },
        text_pass("label", mod:localize("ping_servers"), 710, 570, 180, 48, 16, COLORS.button_text, "center", BASE_Z + 7),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
    detailed_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { 900, 570, BASE_Z + 5 }, size = { 184, 48 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = { offset = { 900, 570, BASE_Z + 4 }, size = { 184, 48 }, color = COLORS.button },
            change_function = function(content, style)
                local hotspot = content.hotspot
                local color = hotspot.disabled and COLORS.button_disabled
                    or hotspot.is_hover and COLORS.button_hover
                    or COLORS.button

                style.color[1] = color[1]
                style.color[2] = color[2]
                style.color[3] = color[3]
                style.color[4] = color[4]
            end,
        },
        text_pass("label", mod:localize("detailed_test"), 900, 570, 184, 48, 16, COLORS.button_text, "center", BASE_Z + 7),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
    history_button = UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { 520, 570, BASE_Z + 5 }, size = { 180, 48 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = { offset = { 520, 570, BASE_Z + 4 }, size = { 180, 48 }, color = COLORS.button },
            change_function = function(content, style)
                local hotspot = content.hotspot
                local color = hotspot.disabled and COLORS.button_disabled
                    or hotspot.is_hover and COLORS.button_hover
                    or COLORS.button

                style.color[1] = color[1]
                style.color[2] = color[2]
                style.color[3] = color[3]
                style.color[4] = color[4]
            end,
        },
        text_pass("label", mod:localize("history_button"), 520, 570, 180, 48, 16, COLORS.button_text, "center", BASE_Z + 7),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
}

for i = 1, MAX_ROWS do
    widget_definitions["region_row_" .. i] = row_definition(i)
end

local definitions = {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
}

local function latency_text(value)
    return value and value >= 0 and string.format("%d ms", value) or mod:localize("result_none")
end

local function latency_color(value, timed_out)
    if timed_out or not value or value < 0 then
        return COLORS.bad
    elseif value <= 80 then
        return COLORS.good
    elseif value <= 140 then
        return COLORS.warning
    end

    return COLORS.bad
end

local function contains_reef(reefs, reef_name)
    if not reefs or not reef_name then
        return false
    end

    for i = 1, #reefs do
        if reefs[i] == reef_name then
            return true
        end
    end

    return false
end

local function aggregate_by_reef(region_latencies)
    local groups = {}

    for i = 1, #region_latencies do
        local entry = region_latencies[i]
        local stats = entry.stats or {}
        local reefs = entry.reefs or {}
        local successful = math.max(0, (stats.sent or 0) - (stats.lost or 0))

        for j = 1, #reefs do
            local reef = reefs[j]
            local group = groups[reef]

            if not group then
                group = {
                    region = reef,
                    reefs = { reef },
                    latency = -1,
                    latency_max = -1,
                    stats = {
                        avg = -1,
                        jitter = -1,
                        min = -1,
                        max = -1,
                        sent = 0,
                        lost = 0,
                    },
                    successful = 0,
                    weighted_average = 0,
                    weighted_jitter = 0,
                }
                groups[reef] = group
            end

            if entry.latency and entry.latency >= 0 then
                group.latency = group.latency < 0 and entry.latency or math.min(group.latency, entry.latency)
                group.latency_max = math.max(group.latency_max, entry.latency)
            end

            local group_stats = group.stats
            group_stats.sent = group_stats.sent + (stats.sent or 0)
            group_stats.lost = group_stats.lost + (stats.lost or 0)

            if stats.min and stats.min >= 0 then
                group_stats.min = group_stats.min < 0 and stats.min or math.min(group_stats.min, stats.min)
            end

            if stats.max and stats.max >= 0 then
                group_stats.max = math.max(group_stats.max, stats.max)
            end

            if successful > 0 then
                group.successful = group.successful + successful
                group.weighted_average = group.weighted_average + math.max(0, stats.avg or 0) * successful
                group.weighted_jitter = group.weighted_jitter + math.max(0, stats.jitter or 0) * successful
            end
        end
    end

    local aggregated = {}
    for _, group in pairs(groups) do
        if group.successful > 0 then
            group.stats.avg = math.floor(group.weighted_average / group.successful + 0.5)
            group.stats.jitter = math.floor(group.weighted_jitter / group.successful + 0.5)
        end

        group.successful = nil
        group.weighted_average = nil
        group.weighted_jitter = nil
        aggregated[#aggregated + 1] = group
    end

    return aggregated
end

local function merge_test_results(results)
    if #results == 1 then
        return results[1]
    end

    local merged_by_region = {}

    for i = 1, #results do
        local region_latencies = results[i].region_latencies or {}

        for j = 1, #region_latencies do
            local entry = region_latencies[j]
            local stats = entry.stats or {}
            local successful = math.max(0, (stats.sent or 0) - (stats.lost or 0))
            local merged = merged_by_region[entry.region]

            if not merged then
                merged = {
                    region = entry.region,
                    reefs = entry.reefs,
                    latency = -1,
                    stats = {
                        avg = -1,
                        jitter = -1,
                        min = -1,
                        max = -1,
                        sent = 0,
                        lost = 0,
                    },
                    successful = 0,
                    weighted_latency = 0,
                    weighted_average = 0,
                    weighted_jitter = 0,
                }
                merged_by_region[entry.region] = merged
            end

            local merged_stats = merged.stats
            merged_stats.sent = merged_stats.sent + (stats.sent or 0)
            merged_stats.lost = merged_stats.lost + (stats.lost or 0)

            if stats.min and stats.min >= 0 then
                merged_stats.min = merged_stats.min < 0 and stats.min or math.min(merged_stats.min, stats.min)
            end

            if stats.max and stats.max >= 0 then
                merged_stats.max = math.max(merged_stats.max, stats.max)
            end

            if successful > 0 then
                merged.successful = merged.successful + successful
                merged.weighted_latency = merged.weighted_latency + math.max(0, entry.latency or 0) * successful
                merged.weighted_average = merged.weighted_average + math.max(0, stats.avg or 0) * successful
                merged.weighted_jitter = merged.weighted_jitter + math.max(0, stats.jitter or 0) * successful
            end
        end
    end

    local merged_latencies = {}
    for _, entry in pairs(merged_by_region) do
        if entry.successful > 0 then
            entry.latency = math.floor(entry.weighted_latency / entry.successful + 0.5)
            entry.stats.avg = math.floor(entry.weighted_average / entry.successful + 0.5)
            entry.stats.jitter = math.floor(entry.weighted_jitter / entry.successful + 0.5)
        end

        entry.successful = nil
        entry.weighted_latency = nil
        entry.weighted_average = nil
        entry.weighted_jitter = nil
        merged_latencies[#merged_latencies + 1] = entry
    end

    return {
        region_latencies = merged_latencies,
        preferred_reef = results[#results].preferred_reef,
    }
end

local function run_latency_test(rounds, should_continue)
    local results = {}

    local function run_round()
        ---@type RegionLatency
        local latency_request = RegionLatency:new()

        return latency_request:matchmaker_regions():next(function(result)
            results[#results + 1] = result

            if #results < rounds and should_continue() then
                return run_round()
            end

            local merged = merge_test_results(results)
            merged.completed_rounds = #results

            return merged
        end)
    end

    return run_round()
end

function ServerPingView:init(settings, context)
    ServerPingView.super.init(self, definitions, settings, context or {})
    self._history_entry = context and context.history_entry
    self._allow_close_hotkey = true
    self._pass_draw = not self._history_entry
    self._pass_input = false
    self._request_id = 0
    self._server_ping_active = false
    self._ping_in_progress = false
    self._test_requested = nil
    self._active_test = nil
end

function ServerPingView:on_enter()
    ServerPingView.super.on_enter(self)
    self._server_ping_active = true
    if mod.server_ping_history_clear_pending(Managers.time:time("main")) then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    end

    self._widgets_by_name.ping_button.content.hotspot.pressed_callback = function()
        self._test_requested = "quick"
    end
    self._widgets_by_name.detailed_button.content.hotspot.pressed_callback = function()
        self._test_requested = "detailed"
    end
    self._widgets_by_name.history_button.content.hotspot.pressed_callback = function()
        mod.open_server_ping_history()
    end

    self:_clear_rows()

    if self._history_entry then
        local history_date = self._history_entry.date or "?"
        local history_samples = tonumber(self._history_entry.samples) or 0
        local history_type = self._history_entry.test_id == "detailed" and "history_detailed" or "history_quick"

        self._widgets_by_name.ping_button.visible = false
        self._widgets_by_name.detailed_button.visible = false
        self._widgets_by_name.history_button.visible = false
        self:_show_results(self._history_entry.result, history_samples)
        self:_set_status("history_detail_status", history_date, mod:localize(history_type), history_samples)
    else
        self:_set_ping_in_progress(false)
    end
end

function ServerPingView:on_exit()
    self._server_ping_active = false
    self._test_requested = nil
    self._request_id = self._request_id + 1
    ServerPingView.super.on_exit(self)
end

function ServerPingView:update(dt, t, input_service)
    local game_mode = Managers.state and Managers.state.game_mode

    if game_mode and game_mode:game_mode_name() ~= "hub" then
        local ui = Managers.ui

        if ui and not ui:is_view_closing(self.view_name) then
            ui:close_view(self.view_name, true)
        end

        return false, false
    end

    if input_service and input_service:get("next") then
        self:_handle_clear_history(t)
    end

    self:_update_selected_region_notes()

    local clear_pending = mod.server_ping_history_clear_pending(t)
    if clear_pending and not self._showing_clear_confirmation then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    elseif self._showing_clear_confirmation and not clear_pending then
        self._showing_clear_confirmation = nil
        self._widgets_by_name.panel.content.footer = mod:localize("footer_hint")
    end

    if self._test_requested then
        local test_id = self._test_requested
        self._test_requested = nil
        self:_start_ping(test_id)
    end

    self:_update_cooldown_button()

    return ServerPingView.super.update(self, dt, t, input_service)
end

function ServerPingView:_update_selected_region_notes()
    local selected_reef = mod.server_ping_selected_region()

    if self._selected_region_notes_initialized and selected_reef == self._displayed_selected_reef then
        return
    end

    self._selected_region_notes_initialized = true
    self._displayed_selected_reef = selected_reef

    for i = 1, MAX_ROWS do
        local row = self._widgets_by_name["region_row_" .. i]
        if row.visible then
            local selected = row.content.reef == selected_reef
            row.content.selected = selected
            row.content.select_hotspot.disabled = selected
            row.content.note = mod:localize(selected and "result_selected"
                or row.content.recommended and "select_best_region" or "select_region")
        end
    end
end

function ServerPingView:_handle_clear_history(t)
    if mod.request_server_ping_history_clear(t) then
        self._showing_clear_confirmation = nil
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_done")
    else
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    end
end

function ServerPingView:_clear_rows()
    for i = 1, MAX_ROWS do
        local row = self._widgets_by_name["region_row_" .. i]
        row.visible = false
        row.content.hotspot.pressed_callback = nil
        row.content.select_hotspot.pressed_callback = nil
    end
end

function ServerPingView:_set_status(localization_id, ...)
    self._widgets_by_name.panel.content.status = mod:localize(localization_id, ...)
end

function ServerPingView:_set_ping_in_progress(in_progress)
    self._ping_in_progress = in_progress

    for test_id, test in pairs(TESTS) do
        local button_name = test_id == "quick" and "ping_button" or "detailed_button"
        local button = self._widgets_by_name[button_name]
        button.content.hotspot.disabled = in_progress
        button.content.label = mod:localize(in_progress and self._active_test == test_id
            and "pinging_servers" or test.label)
    end

    if not in_progress then
        self._active_test = nil
        self:_update_cooldown_button()
    end
end

function ServerPingView:_update_cooldown_button()
    if self._ping_in_progress then
        return
    end

    local pending = mod.server_ping_pending()
    local remaining = mod.server_ping_cooldown_remaining()
    local display_state = pending and "pending" or remaining
    if display_state == self._displayed_cooldown then
        return
    end

    self._displayed_cooldown = display_state

    for test_id, test in pairs(TESTS) do
        local button_name = test_id == "quick" and "ping_button" or "detailed_button"
        local button = self._widgets_by_name[button_name]
        button.content.hotspot.disabled = pending or remaining > 0
        button.content.label = pending and mod:localize("pinging_servers")
            or remaining > 0
            and mod:localize("ping_cooldown", remaining)
            or mod:localize(test.label)
    end
end

function ServerPingView:_show_results(result, samples)
    local rows = aggregate_by_reef(result and result.region_latencies or {})
    local preferred_reef = result and result.preferred_reef

    table.sort(rows, function(a, b)
        local a_latency = a.latency and a.latency >= 0 and a.latency or math.huge
        local b_latency = b.latency and b.latency >= 0 and b.latency or math.huge

        if a_latency == b_latency then
            return (a.region or "") < (b.region or "")
        end

        return a_latency < b_latency
    end)

    self:_clear_rows()

    local visible_count = math.min(#rows, MAX_ROWS)
    for i = 1, visible_count do
        local entry = rows[i]
        local stats = entry.stats or {}
        local row = self._widgets_by_name["region_row_" .. i]
        local localization_key = RegionLocalizationMappings[entry.region]
        local region_name = localization_key and Localize(localization_key) or entry.region or "?"
        local timed_out = not entry.latency or entry.latency < 0
        local sent = stats.sent or 0
        local lost = stats.lost or 0
        local loss_percent = sent > 0 and math.floor(lost * 100 / sent + 0.5) or 0
        local color = latency_color(entry.latency, timed_out)

        row.visible = true
        row.content.region = region_name
        row.content.median = timed_out and mod:localize("result_timeout")
            or entry.latency == entry.latency_max and latency_text(entry.latency)
            or string.format("%d-%d ms", entry.latency, entry.latency_max)
        row.content.average = latency_text(stats.avg)
        row.content.minimum = latency_text(stats.min)
        row.content.maximum = latency_text(stats.max)
        row.content.jitter = latency_text(stats.jitter)
        row.content.loss = string.format("%d/%d (%d%%)", lost, sent, loss_percent)
        row.content.reef = entry.region
        row.content.recommended = contains_reef(entry.reefs, preferred_reef)
        row.content.hotspot.pressed_callback = function()
            mod.open_server_ping_endpoints({
                reef = entry.region,
                result = result,
            })
        end
        row.content.select_hotspot.pressed_callback = function()
            mod.select_server_ping_region(entry.region)
            self._selected_region_notes_initialized = false
            self:_update_selected_region_notes()
        end
        row.style.median.text_color = color
        row.style.average.text_color = color
        row.style.loss.text_color = lost > 0 and COLORS.bad or COLORS.text
    end


    self._selected_region_notes_initialized = false
    self:_update_selected_region_notes()

    if #rows > MAX_ROWS then
        self:_set_status("status_truncated", #rows, samples, MAX_ROWS)
    else
        self:_set_status("status_complete", #rows, samples)
    end
end

function ServerPingView:_start_ping(test_id)
    if self._ping_in_progress then
        return
    end

    local party_manager = Managers.party_immaterium
    if not Managers.backend or not Managers.ping
        or party_manager and party_manager:is_in_matchmaking() then
        self:_set_status("status_unavailable")
        return
    end

    local test = TESTS[test_id]
    if not test then
        return
    end

    local allowed, remaining = mod.begin_server_ping(test.cooldown)
    if not allowed then
        self:_set_status("status_cooldown", remaining)
        self:_update_cooldown_button()
        return
    end

    self._request_id = self._request_id + 1
    local request_id = self._request_id

    self:_clear_rows()
    self._active_test = test_id
    self:_set_ping_in_progress(true)
    self:_set_status("status_loading", test_id == "quick" and "quick" or "detailed", test.samples)

    run_latency_test(test.rounds, function()
        return self._server_ping_active and request_id == self._request_id
    end):next(function(result)
        mod.finish_server_ping()

        if result.completed_rounds == test.rounds then
            mod.save_server_ping_history(test_id, test.samples, result)
        end

        if not self._server_ping_active or request_id ~= self._request_id then
            return
        end

        self:_set_ping_in_progress(false)
        self:_show_results(result, test.samples)
    end):catch(function()
        mod.finish_server_ping()

        if not self._server_ping_active or request_id ~= self._request_id then
            return
        end

        self:_set_ping_in_progress(false)
        self:_set_status("status_failed")
    end)
end

function ServerPingView:dialogue_system()
    return nil
end

return ServerPingView
