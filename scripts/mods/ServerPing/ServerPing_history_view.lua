local mod = get_mod("ServerPing")

local RegionLocalizationMappings = require("scripts/settings/backend/region_localization")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local ServerPingHistoryView = class("ServerPingHistoryView", "BaseView")

local BASE_Z = 100
local VIEW_WIDTH = 960
local VIEW_HEIGHT = 680
local MAX_ENTRIES = 10
local ENTRY_HEIGHT = 48
local ENTRY_TOP = 132

local COLORS = {
    overlay = { 170, 0, 0, 0 },
    panel = { 248, 7, 13, 13 },
    frame = { 220, 55, 96, 84 },
    header = { 255, 190, 220, 205 },
    text = { 255, 215, 226, 220 },
    dim = { 185, 125, 145, 138 },
    row = { 215, 12, 22, 20 },
    row_alt = { 230, 16, 29, 26 },
    hover = { 255, 40, 94, 78 },
    button = { 245, 34, 84, 70 },
    button_hover = { 255, 52, 125, 101 },
    button_selected = { 255, 62, 135, 109 },
    button_text = { 255, 245, 250, 247 },
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

local function entry_definition(index)
    local y = ENTRY_TOP + (index - 1) * ENTRY_HEIGHT
    local color = index % 2 == 0 and COLORS.row_alt or COLORS.row

    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { 28, y, BASE_Z + 5 }, size = { VIEW_WIDTH - 56, ENTRY_HEIGHT - 3 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                offset = { 28, y, BASE_Z + 2 },
                size = { VIEW_WIDTH - 56, ENTRY_HEIGHT - 3 },
                color = { color[1], color[2], color[3], color[4] },
            },
            change_function = function(content, style)
                local target = content.hotspot.is_hover and COLORS.hover or color
                style.color[1] = target[1]
                style.color[2] = target[2]
                style.color[3] = target[3]
                style.color[4] = target[4]
            end,
        },
        text_pass("date", "", 48, y, 250, ENTRY_HEIGHT - 3, 16, COLORS.text, nil, BASE_Z + 7),
        text_pass("type", "", 310, y, 120, ENTRY_HEIGHT - 3, 16, COLORS.header, nil, BASE_Z + 7),
        text_pass("summary", "", 440, y, 470, ENTRY_HEIGHT - 3, 13, COLORS.dim, nil, BASE_Z + 7),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT })
end

local function tab_definition(label, x, width)
    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { x, 24, BASE_Z + 6 }, size = { width, 36 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = { offset = { x, 24, BASE_Z + 5 }, size = { width, 36 }, color = COLORS.button },
            change_function = function(content, style)
                local target = content.selected and COLORS.button_selected
                    or content.hotspot.is_hover and COLORS.button_hover
                    or COLORS.button

                style.color[1] = target[1]
                style.color[2] = target[2]
                style.color[3] = target[3]
                style.color[4] = target[4]
            end,
        },
        text_pass("label", label, x, 24, width, 36, 14, COLORS.button_text, "center", BASE_Z + 8),
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
        text_pass("title", mod:localize("history_title"), 36, 22, 570, 38, 30, COLORS.header),
        text_pass("subtitle", mod:localize("history_subtitle"), 38, 60, VIEW_WIDTH - 76, 28, 15, COLORS.dim),
        { pass_type = "rect", style = { offset = { 28, 100, BASE_Z + 2 }, size = { VIEW_WIDTH - 56, 2 }, color = COLORS.frame } },
        text_pass("date_header", mod:localize("history_date"), 48, 104, 250, 24, 13, COLORS.dim),
        text_pass("type_header", mod:localize("history_type"), 310, 104, 120, 24, 13, COLORS.dim),
        text_pass("summary_header", mod:localize("history_summary"), 440, 104, 470, 24, 13, COLORS.dim),
        text_pass("empty", "", 38, 250, VIEW_WIDTH - 76, 44, 18, COLORS.dim, "center"),
        text_pass("footer", mod:localize("footer_hint"), 38, 634, VIEW_WIDTH - 76, 28, 14, COLORS.dim),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
    recent_tab = tab_definition(mod:localize("history_tab_recent"), 650, 125),
    accumulated_tab = tab_definition(mod:localize("history_tab_accumulated"), 785, 145),
}

for i = 1, MAX_ENTRIES do
    widget_definitions["history_entry_" .. i] = entry_definition(i)
end

local definitions = {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
}

function ServerPingHistoryView:init(settings, context)
    ServerPingHistoryView.super.init(self, definitions, settings, context or {})
    self._allow_close_hotkey = true
    self._pass_draw = false
    self._pass_input = false
    self._active_tab = "recent"
end

function ServerPingHistoryView:on_enter()
    ServerPingHistoryView.super.on_enter(self)

    self._widgets_by_name.recent_tab.content.hotspot.pressed_callback = function()
        self:_set_tab("recent")
    end
    self._widgets_by_name.accumulated_tab.content.hotspot.pressed_callback = function()
        self:_set_tab("accumulated")
    end

    self._history_generation = mod.server_ping_history_generation()
    if mod.server_ping_history_clear_pending(Managers.time:time("main")) then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    end
    self:_set_tab("recent", true)
end

function ServerPingHistoryView:_set_tab(tab, force)
    if not force and self._active_tab == tab then
        return
    end

    self._active_tab = tab
    self._widgets_by_name.recent_tab.content.selected = tab == "recent"
    self._widgets_by_name.accumulated_tab.content.selected = tab == "accumulated"

    if tab == "recent" then
        self:_populate_recent()
    else
        self:_populate_accumulated()
    end
end

function ServerPingHistoryView:_populate_recent()
    local panel = self._widgets_by_name.panel
    local history = mod.server_ping_history()

    panel.content.subtitle = mod:localize("history_subtitle")
    panel.content.date_header = mod:localize("history_date")
    panel.content.type_header = mod:localize("history_type")
    panel.content.summary_header = mod:localize("history_summary")
    panel.content.empty = #history == 0 and mod:localize("history_empty") or ""

    for i = 1, MAX_ENTRIES do
        local widget = self._widgets_by_name["history_entry_" .. i]
        local entry = history[i]

        widget.visible = entry ~= nil
        widget.content.hotspot.disabled = entry == nil

        if entry then
            widget.content.date = entry.date or "?"
            widget.content.type = mod:localize(entry.test_id == "detailed" and "history_detailed" or "history_quick")
            widget.content.summary = mod:localize("history_samples", entry.samples or 0)
            widget.content.hotspot.pressed_callback = function()
                mod.open_server_ping_result(entry)
            end
        else
            widget.content.hotspot.pressed_callback = nil
        end
    end
end

function ServerPingHistoryView:_populate_accumulated()
    local panel = self._widgets_by_name.panel
    local aggregate = mod.server_ping_aggregate()
    local rows = {}

    for reef, data in pairs(aggregate.regions or {}) do
        if type(data) == "table" then
            local successful = tonumber(data.successful) or 0
            local average = successful > 0 and math.floor((tonumber(data.weighted_average) or 0) / successful + 0.5) or -1
            local jitter = successful > 0 and math.floor((tonumber(data.weighted_jitter) or 0) / successful + 0.5) or -1

            rows[#rows + 1] = {
                reef = reef,
                aggregate_region = data,
                endpoint_history_complete = aggregate.endpoint_history_complete ~= false,
                endpoint_total_tests = tonumber(aggregate.endpoint_total_tests) or 0,
                tests = tonumber(data.tests) or 0,
                quick_tests = tonumber(data.quick_tests) or 0,
                detailed_tests = tonumber(data.detailed_tests) or 0,
                average = average,
                jitter = jitter,
                min = tonumber(data.min) or -1,
                max = tonumber(data.max) or -1,
                sent = tonumber(data.sent) or 0,
                lost = tonumber(data.lost) or 0,
            }
        end
    end

    table.sort(rows, function(a, b)
        local a_average = a.average >= 0 and a.average or math.huge
        local b_average = b.average >= 0 and b.average or math.huge

        if a_average == b_average then
            return a.reef < b.reef
        end

        return a_average < b_average
    end)

    local total_tests = tonumber(aggregate.total_tests) or 0
    local first_date = aggregate.first_date or "?"
    local last_date = aggregate.last_date or "?"
    panel.content.subtitle = total_tests > 0
        and mod:localize("history_aggregate_subtitle", total_tests, first_date, last_date)
        or mod:localize("history_subtitle")
    panel.content.date_header = mod:localize("history_region")
    panel.content.type_header = mod:localize("history_tests")
    panel.content.summary_header = mod:localize("history_network_totals")
    panel.content.empty = #rows == 0 and mod:localize("history_aggregate_empty") or ""

    for i = 1, MAX_ENTRIES do
        local widget = self._widgets_by_name["history_entry_" .. i]
        local entry = rows[i]

        widget.visible = entry ~= nil
        widget.content.hotspot.disabled = entry == nil
        widget.content.hotspot.pressed_callback = nil

        if entry then
            local localization_key = RegionLocalizationMappings[entry.reef]
            local region_name = localization_key and Localize(localization_key) or entry.reef
            local loss_percent = entry.sent > 0 and entry.lost * 100 / entry.sent or 0

            widget.content.date = region_name
            widget.content.type = string.format("%d (%dQ/%dD)", entry.tests, entry.quick_tests, entry.detailed_tests)
            widget.content.summary = mod:localize("history_aggregate_row", entry.average, entry.min, entry.max,
                entry.jitter, entry.lost, entry.sent, loss_percent)
            widget.content.hotspot.pressed_callback = function()
                mod.open_server_ping_endpoints({
                    reef = entry.reef,
                    aggregate_region = entry.aggregate_region,
                    endpoint_history_complete = entry.endpoint_history_complete,
                    endpoint_total_tests = entry.endpoint_total_tests,
                })
            end
        end
    end
end

function ServerPingHistoryView:update(dt, t, input_service)
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

    local generation = mod.server_ping_history_generation()
    if generation ~= self._history_generation then
        self._history_generation = generation
        self:_set_tab(self._active_tab, true)
    end

    local clear_pending = mod.server_ping_history_clear_pending(t)
    if clear_pending and not self._showing_clear_confirmation then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    elseif self._showing_clear_confirmation and not clear_pending then
        self._showing_clear_confirmation = nil
        self._widgets_by_name.panel.content.footer = mod:localize("footer_hint")
    end

    return ServerPingHistoryView.super.update(self, dt, t, input_service)
end

function ServerPingHistoryView:_handle_clear_history(t)
    local panel = self._widgets_by_name.panel

    if mod.request_server_ping_history_clear(t) then
        self._showing_clear_confirmation = nil
        self._history_generation = mod.server_ping_history_generation()
        self:_set_tab(self._active_tab, true)
        panel.content.footer = mod:localize("clear_history_done")
    else
        self._showing_clear_confirmation = true
        panel.content.footer = mod:localize("clear_history_confirm")
    end
end

function ServerPingHistoryView:dialogue_system()
    return nil
end

return ServerPingHistoryView
