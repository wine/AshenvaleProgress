---@enum PacketId
PacketId = {
    Ping = "Ping",
    Pong = "Pong",
    Progress = "Progress",
    Bye = "Bye",
}

---@class Packet
---@field Id PacketId

---@class PingPacket : Packet
---@field Version string

---@class PongPacket : Packet
---@field Version string
---@field SharedState SharedState

---@class ProgressPacket : Packet
---@field SharedState SharedState

---@class ByePacket : Packet
