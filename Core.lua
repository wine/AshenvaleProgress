---@class AshenvaleProgress : AceAddon, AceComm-3.0, AceConsole-3.0, AceEvent-3.0, AceSerializer-3.0
---@field Version string
---@field CommPrefix string
---@field SharedState SharedState
local AshenvaleProgress = LibStub("AceAddon-3.0"):NewAddon(
    "AshenvaleProgress",
    "AceComm-3.0",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceSerializer-3.0"
)

function AshenvaleProgress:OnInitialize()
    AshenvaleProgress.Version = C_AddOns.GetAddOnMetadata(AshenvaleProgress:GetName(), "Version")

    self.CommPrefix = "AP"

    self.SharedState = {
        AddOnPlayers = { self:GetLocalPlayerNameOrError() },
        AllianceProgress = 0,
        HordeProgress = 0,
        Timestamp = 0,
        Reporter = self:GetLocalPlayerNameOrError(),
    }
end

function AshenvaleProgress:OnEnable()
    self:RegisterComm(self.CommPrefix)
    self:SendPingPacket()

    self:RegisterChatCommand("ashenvale", "OnAshenvaleCommand")

    self:RegisterEvent("CHAT_MSG_GUILD", "OnChatMessageGuild")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("UPDATE_UI_WIDGET", "OnUpdateUiWidget")
end

function AshenvaleProgress:OnDisable()
    self:SendByePacket()
end

function AshenvaleProgress:CheckVersionCompatibility(sender, version)
    if self.Version ~= version then
        self:Print("Version mismatch with '" .. sender .. "'! You may encounter bugs.")
        self:Print("Local version:", self.Version)
        self:Print(sender, "version:", version)
    end
end

---@return string
function AshenvaleProgress:GetLocalPlayerNameOrError()
    local playerName, _ = UnitName("player")
    if playerName == nil then
        error("Missing UnitName for local player", 0)
    end

    return playerName
end

---@param target string
---@return boolean
function AshenvaleProgress:HasAddOnPlayer(target)
    for _, addOnPlayer in ipairs(self.SharedState.AddOnPlayers) do
        if addOnPlayer == target then
            return true
        end
    end

    return false
end

---@param target string
function AshenvaleProgress:InsertAddOnPlayer(target)
    if self:HasAddOnPlayer(target) then
        return
    end

    table.insert(self.SharedState.AddOnPlayers, target)
    table.sort(self.SharedState.AddOnPlayers)
end

---@param target string
function AshenvaleProgress:RemoveAddOnPlayer(target)
    for index, addOnPlayer in ipairs(self.SharedState.AddOnPlayers) do
        if addOnPlayer == target then
            table.remove(self.SharedState.AddOnPlayers, index)
        end
    end
end

---@return string[]
function AshenvaleProgress:CreateResponseLines()
    local deltaTimestamp = GetServerTime() - self.SharedState.Timestamp
    return {
        "Last known Battle for Ashenvale progress (" .. deltaTimestamp .. " seconds ago)",
        "Reported by: " .. self.SharedState.Reporter,
        "Alliance: " .. self.SharedState.AllianceProgress .. "%",
        "Horde: " .. self.SharedState.HordeProgress .. "%"
    }
end

---@param ... any
function AshenvaleProgress:SendPacket(...)
    self:SendCommMessage(self.CommPrefix, self:Serialize(...), "GUILD")
end

function AshenvaleProgress:SendPingPacket()
    ---@type PingPacket
    local packet = {
        Id = PacketId.Ping,
        Version = self.Version,
    }

    self:SendPacket(packet)
end

function AshenvaleProgress:SendPongPacket()
    ---@type PongPacket
    local packet = {
        Id = PacketId.Pong,
        Version = self.Version,
        SharedState = self.SharedState,
    }

    self:SendPacket(packet)
end

function AshenvaleProgress:SendProgressPacket()
    ---@type ProgressPacket
    local packet = {
        Id = PacketId.Progress,
        SharedState = self.SharedState,
    }

    self:SendPacket(packet)
end

function AshenvaleProgress:SendByePacket()
    ---@type ByePacket
    local packet = {
        Id = PacketId.Bye,
    }

    self:SendPacket(packet)
end

---@param prefix string
---@param message string
---@param distribution string
---@param sender string
function AshenvaleProgress:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= self.CommPrefix then
        return
    end

    if sender == self:GetLocalPlayerNameOrError() then
        return
    end

    ---@type boolean, Packet
    local success, packet = self:Deserialize(message)
    if success ~= true then
        return
    end

    self["On" .. packet.Id .. "Packet"](self, sender, packet)
end

---@param sender string
---@param packet PingPacket
function AshenvaleProgress:OnPingPacket(sender, packet)
    self:CheckVersionCompatibility(sender, packet.Version)

    self:InsertAddOnPlayer(sender)

    self:SendPongPacket()
end

---@param sender string
---@param packet PongPacket
function AshenvaleProgress:OnPongPacket(sender, packet)
    self:CheckVersionCompatibility(sender, packet.Version)

    if packet.SharedState.Timestamp > self.SharedState.Timestamp then
        self.SharedState = packet.SharedState
    end
end

---@param sender string
---@param packet ProgressPacket
function AshenvaleProgress:OnProgressPacket(sender, packet)
    if packet.SharedState.Timestamp > self.SharedState.Timestamp then
        self.SharedState = packet.SharedState
    end
end

---@param sender string
---@param packet ByePacket
function AshenvaleProgress:OnByePacket(sender, packet)
    AshenvaleProgress:RemoveAddOnPlayer(sender)
end

---@param input string?
function AshenvaleProgress:OnAshenvaleCommand(input)
    local responseLines = self:CreateResponseLines()
    for _, responseLine in ipairs(responseLines) do
        self:Print(responseLine)
    end
end

---@param event string
---@param text string
---@param sender string
function AshenvaleProgress:OnChatMessageGuild(event, text, sender)
    local responder = self.SharedState.AddOnPlayers[1]
    if responder ~= self:GetLocalPlayerNameOrError() then
        return
    end

    if text ~= "!ashenvale" then
        return
    end

    local responseLines = self:CreateResponseLines()
    for _, responseLine in ipairs(responseLines) do
        SendChatMessage(responseLine, "GUILD")
    end
end

---@param event string
---@param canRequestRosterUpdate boolean
function AshenvaleProgress:OnGuildRosterUpdate(event, canRequestRosterUpdate)
    local guildMemberCount = GetNumGuildMembers()
    for index = 1, guildMemberCount do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(index)
        if online == false then
            AshenvaleProgress:RemoveAddOnPlayer(name)
        end
    end
end

---@param event string
---@param widget UIWidgetInfo
function AshenvaleProgress:OnUpdateUiWidget(event, widget)
    local widgetVisualization = C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo(widget.widgetID)
    if widgetVisualization == nil then
        return
    end

    if widgetVisualization.dynamicTooltip:find("Kill Progress") == nil then
        return
    end

    local progress = tonumber(widgetVisualization.text:sub(1, -2))
    if progress == nil then
        return
    end

    if widgetVisualization.dynamicTooltip:find("Alliance") then
        self.SharedState.AllianceProgress = progress
    elseif widgetVisualization.dynamicTooltip:find("Horde") then
        self.SharedState.HordeProgress = progress
    else
        error("Unknown kill progress widget: '" .. widgetVisualization.dynamicTooltip .. "'", 0)
        return
    end

    self.SharedState.Timestamp = GetServerTime()
    self.SharedState.Reporter = self:GetLocalPlayerNameOrError()

    self:SendProgressPacket()
end
