local mod = get_mod("ServerPing")

local RegionLocalizationMappings = require("scripts/settings/backend/region_localization")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local ServerPingEndpointView = class("ServerPingEndpointView", "BaseView")

local BASE_Z = 100
local VIEW_WIDTH = 1040
local VIEW_HEIGHT = 640
local MAX_ROWS = 10
local ROW_HEIGHT = 36
local ROW_TOP = 142

local COLORS = {
    overlay = { 185, 0, 0, 0 },
    panel = { 252, 7, 13, 13 },
    frame = { 220, 55, 96, 84 },
    header = { 255, 190, 220, 205 },
    text = { 255, 215, 226, 220 },
    dim = { 185, 125, 145, 138 },
    row = { 215, 12, 22, 20 },
    row_alt = { 230, 16, 29, 26 },
    bad = { 255, 240, 91, 77 },
    button = { 245, 34, 84, 70 },
    button_hover = { 255, 52, 125, 101 },
    button_disabled = { 150, 32, 42, 39 },
    button_selected = { 255, 62, 135, 109 },
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
    local color = index % 2 == 0 and COLORS.row_alt or COLORS.row

    return UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                offset = { 24, y, BASE_Z + 2 },
                size = { VIEW_WIDTH - 48, ROW_HEIGHT - 2 },
                color = color,
            },
        },
        text_pass("endpoint", "", 38, y, 250, ROW_HEIGHT, 16, COLORS.text),
        text_pass("measure", "", 292, y, 100, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("average", "", 398, y, 100, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("minimum", "", 504, y, 90, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("maximum", "", 600, y, 90, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("jitter", "", 696, y, 100, ROW_HEIGHT, 16, COLORS.text, "center"),
        text_pass("loss", "", 802, y, 200, ROW_HEIGHT, 16, COLORS.text, "center"),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT })
end

local function button_definition(value_id, text, x, width)
    width = width or 130

    return UIWidget.create_definition({
        {
            pass_type = "hotspot",
            content_id = "hotspot",
            style = { offset = { x, 530, BASE_Z + 5 }, size = { width, 40 } },
        },
        {
            pass_type = "rect",
            style_id = "background",
            style = { offset = { x, 530, BASE_Z + 4 }, size = { width, 40 }, color = COLORS.button },
            change_function = function(content, style)
                local color = content.selected and COLORS.button_selected
                    or content.hotspot.disabled and COLORS.button_disabled
                    or content.hotspot.is_hover and COLORS.button_hover or COLORS.button
                style.color[1], style.color[2], style.color[3], style.color[4] = color[1], color[2], color[3], color[4]
            end,
        },
        text_pass(value_id, text, x, 530, width, 40, 14, COLORS.text, "center", BASE_Z + 7),
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
        text_pass("title", "", 36, 22, VIEW_WIDTH - 72, 38, 30, COLORS.header),
        text_pass("subtitle", "", 38, 60, VIEW_WIDTH - 76, 28, 15, COLORS.dim),
        { pass_type = "rect", style = { offset = { 24, 102, BASE_Z + 2 }, size = { VIEW_WIDTH - 48, 2 }, color = COLORS.frame } },
        text_pass("endpoint_header", mod:localize("endpoint_name"), 38, 108, 250, 28, 13, COLORS.dim),
        text_pass("measure_header", "", 292, 108, 100, 28, 13, COLORS.dim, "center"),
        text_pass("average_header", mod:localize("header_average"), 398, 108, 100, 28, 13, COLORS.dim, "center"),
        text_pass("minimum_header", mod:localize("header_minimum"), 504, 108, 90, 28, 13, COLORS.dim, "center"),
        text_pass("maximum_header", mod:localize("header_maximum"), 600, 108, 90, 28, 13, COLORS.dim, "center"),
        text_pass("jitter_header", mod:localize("header_jitter"), 696, 108, 100, 28, 13, COLORS.dim, "center"),
        text_pass("loss_header", mod:localize("header_loss"), 802, 108, 200, 28, 13, COLORS.dim, "center"),
        text_pass("empty", "", 38, 270, VIEW_WIDTH - 76, 44, 18, COLORS.dim, "center"),
        text_pass("footer", mod:localize("footer_hint"), 38, 594, VIEW_WIDTH - 76, 28, 14, COLORS.dim),
    }, "panel", nil, { VIEW_WIDTH, VIEW_HEIGHT }),
    select_region_button = button_definition("label", mod:localize("use_this_region"), 38, 220),
    previous_button = button_definition("label", mod:localize("previous_page"), 746),
    next_button = button_definition("label", mod:localize("next_page"), 884),
}

for i = 1, MAX_ROWS do
    widget_definitions["endpoint_row_" .. i] = row_definition(i)
end

local definitions = {
    scenegraph_definition = scenegraph_definition,
    widget_definitions = widget_definitions,
}

local function contains_reef(reefs, reef)
    for i = 1, type(reefs) == "table" and #reefs or 0 do
        if reefs[i] == reef then
            return true
        end
    end

    return false
end

local function latency_text(value)
    value = tonumber(value)
    return value and value >= 0 and string.format("%d ms", value) or mod:localize("result_none")
end

function ServerPingEndpointView:init(settings, context)
    ServerPingEndpointView.super.init(self, definitions, settings, context or {})
    self._context = context or {}
    self._allow_close_hotkey = true
    self._pass_draw = false
    self._pass_input = false
end

function ServerPingEndpointView:on_enter()
    ServerPingEndpointView.super.on_enter(self)
    self._widgets_by_name.previous_button.content.hotspot.pressed_callback = function()
        self._page = math.max(1, self._page - 1)
        self:_render_page()
    end
    self._widgets_by_name.next_button.content.hotspot.pressed_callback = function()
        self._page = math.min(self._page_count, self._page + 1)
        self:_render_page()
    end
    self._widgets_by_name.select_region_button.content.hotspot.pressed_callback = function()
        mod.select_server_ping_region(self._context.reef)
        self:_update_selected_region()
    end
    self:_populate()
    if mod.server_ping_history_clear_pending(Managers.time:time("main")) then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    end
end

function ServerPingEndpointView:_populate()
    local context = self._context
    local reef = context.reef or "?"
    local localization_key = RegionLocalizationMappings[reef]
    local region_name = localization_key and Localize(localization_key) or reef
    local panel = self._widgets_by_name.panel
    local rows = {}

    panel.content.title = mod:localize("endpoint_title", string.upper(region_name))

    if type(context.aggregate_region) == "table" then
        panel.content.subtitle = context.endpoint_history_complete == false
            and mod:localize("endpoint_partial_subtitle", tonumber(context.endpoint_total_tests) or 0)
            or mod:localize("endpoint_aggregate_subtitle")
        panel.content.measure_header = mod:localize("endpoint_tests")

        for endpoint_name, data in pairs(context.aggregate_region.endpoints or {}) do
            if type(data) == "table" then
                local successful = tonumber(data.successful) or 0
                rows[#rows + 1] = {
                    endpoint = endpoint_name,
                    measure = tostring(tonumber(data.tests) or 0),
                    average = successful > 0 and (tonumber(data.weighted_average) or 0) / successful or -1,
                    minimum = tonumber(data.min) or -1,
                    maximum = tonumber(data.max) or -1,
                    jitter = successful > 0 and (tonumber(data.weighted_jitter) or 0) / successful or -1,
                    sent = tonumber(data.sent) or 0,
                    lost = tonumber(data.lost) or 0,
                }
            end
        end
    else
        panel.content.subtitle = mod:localize("endpoint_live_subtitle")
        panel.content.measure_header = mod:localize("header_median")

        local region_latencies = type(context.result) == "table" and context.result.region_latencies or {}
        for i = 1, type(region_latencies) == "table" and #region_latencies or 0 do
            local entry = region_latencies[i]
            if type(entry) == "table" and contains_reef(entry.reefs, reef) then
                local stats = type(entry.stats) == "table" and entry.stats or {}
                rows[#rows + 1] = {
                    endpoint = entry.region or "?",
                    measure = latency_text(entry.latency),
                    average = tonumber(stats.avg) or -1,
                    minimum = tonumber(stats.min) or -1,
                    maximum = tonumber(stats.max) or -1,
                    jitter = tonumber(stats.jitter) or -1,
                    sent = tonumber(stats.sent) or 0,
                    lost = tonumber(stats.lost) or 0,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        local a_average = a.average >= 0 and a.average or math.huge
        local b_average = b.average >= 0 and b.average or math.huge
        return a_average == b_average and a.endpoint < b.endpoint or a_average < b_average
    end)

    self._rows = rows
    self._page = 1
    self._page_count = math.max(1, math.ceil(#rows / MAX_ROWS))
    self:_render_page()
    self:_update_selected_region()
end

function ServerPingEndpointView:_update_selected_region()
    local reef = self._context.reef
    local selected = type(reef) == "string" and reef == mod.server_ping_selected_region()
    local button = self._widgets_by_name.select_region_button

    button.content.selected = selected
    button.content.hotspot.disabled = selected or type(reef) ~= "string"
    button.content.label = mod:localize(selected and "region_selected" or "use_this_region")
end

function ServerPingEndpointView:_render_page()
    local rows = self._rows or {}
    local panel = self._widgets_by_name.panel
    local first_index = (self._page - 1) * MAX_ROWS + 1

    panel.content.empty = #rows == 0 and mod:localize("history_aggregate_empty") or ""

    for i = 1, MAX_ROWS do
        local widget = self._widgets_by_name["endpoint_row_" .. i]
        local entry = rows[first_index + i - 1]
        widget.visible = entry ~= nil

        if entry then
            local loss_percent = entry.sent > 0 and math.floor(entry.lost * 100 / entry.sent + 0.5) or 0
            widget.content.endpoint = entry.endpoint
            widget.content.measure = entry.measure
            widget.content.average = latency_text(math.floor(entry.average + 0.5))
            widget.content.minimum = latency_text(entry.minimum)
            widget.content.maximum = latency_text(entry.maximum)
            widget.content.jitter = latency_text(math.floor(entry.jitter + 0.5))
            widget.content.loss = string.format("%d/%d (%d%%)", entry.lost, entry.sent, loss_percent)
            widget.style.loss.text_color = entry.lost > 0 and COLORS.bad or COLORS.text
        end
    end

    local previous_button = self._widgets_by_name.previous_button
    local next_button = self._widgets_by_name.next_button
    previous_button.visible = self._page_count > 1
    next_button.visible = self._page_count > 1
    previous_button.content.hotspot.disabled = self._page <= 1
    next_button.content.hotspot.disabled = self._page >= self._page_count
end

function ServerPingEndpointView:update(dt, t, input_service)
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

    self:_update_selected_region()

    local clear_pending = mod.server_ping_history_clear_pending(t)
    if clear_pending and not self._showing_clear_confirmation then
        self._showing_clear_confirmation = true
        self._widgets_by_name.panel.content.footer = mod:localize("clear_history_confirm")
    elseif self._showing_clear_confirmation and not clear_pending then
        self._showing_clear_confirmation = nil
        self._widgets_by_name.panel.content.footer = mod:localize("footer_hint")
    end

    return ServerPingEndpointView.super.update(self, dt, t, input_service)
end

function ServerPingEndpointView:_handle_clear_history(t)
    local panel = self._widgets_by_name.panel

    if mod.request_server_ping_history_clear(t) then
        self._showing_clear_confirmation = nil
        if self._context.aggregate_region then
            self._context.aggregate_region = { endpoints = {} }
            self._context.endpoint_history_complete = true
            self._context.endpoint_total_tests = 0
            self:_populate()
        end
        panel.content.footer = mod:localize("clear_history_done")
    else
        self._showing_clear_confirmation = true
        panel.content.footer = mod:localize("clear_history_confirm")
    end
end

function ServerPingEndpointView:dialogue_system()
    return nil
end

return ServerPingEndpointView
