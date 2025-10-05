local modem = peripheral.find("modem")
if not modem then print("No modem found!") return end
modem.open(1)

local servers = {}
local chats = {}

local function encrypt(text, key)
    local out = {}
    for i = 1, #text do
        local c = string.byte(text, i)
        table.insert(out, string.char(bit.bxor(c, key)))
    end
    return table.concat(out)
end

local function decrypt(text, key)
    return encrypt(text, key)
end

local function broadcastServerList()
    local list = {}
    for id, data in pairs(servers) do
        table.insert(list, { id = id, connections = #data.clients })
    end
    for id, data in pairs(servers) do
        modem.transmit(data.port, 1, { type = "server_list", list = list })
    end
end

while true do
    local _, _, channel, replyChannel, msg = os.pullEvent("modem_message")
    if type(msg) == "table" then
        if msg.type == "register_server" then
            servers[msg.server_id] = { port = msg.port, clients = {}, key = tonumber(msg.key) or 0 }
            print("New server:", msg.server_id, "Key:", msg.key)
            broadcastServerList()
        elseif msg.type == "connect_server" then
            local srv = servers[msg.server_id]
            if srv then
                table.insert(srv.clients, replyChannel)
                modem.transmit(replyChannel, 1, { type = "connect_ok" })
                broadcastServerList()
            else
                modem.transmit(replyChannel, 1, { type = "connect_fail" })
            end
        elseif msg.type == "send_chat" then
            local chatKey = msg.server_id .. ":" .. msg.chat_id
            chats[chatKey] = chats[chatKey] or {}
            local srv = servers[msg.server_id]
            local encText = encrypt(msg.text, srv.key)
            table.insert(chats[chatKey], { user = msg.user, text = encText, time = os.time() })
            for _, client in ipairs(srv.clients) do
                local decMsgs = {}
                for _, m in ipairs(chats[chatKey]) do
                    table.insert(decMsgs, { user = m.user, text = decrypt(m.text, srv.key), time = m.time })
                end
                modem.transmit(client, 1, { type = "chat_update", chat_id = msg.chat_id, messages = decMsgs })
            end
            print("Msg in", chatKey)
        elseif msg.type == "get_chat" then
            local chatKey = msg.server_id .. ":" .. msg.chat_id
            local srv = servers[msg.server_id]
            local decMsgs = {}
            for _, m in ipairs(chats[chatKey] or {}) do
                table.insert(decMsgs, { user = m.user, text = decrypt(m.text, srv.key), time = m.time })
            end
            modem.transmit(replyChannel, 1, { type = "chat_update", chat_id = msg.chat_id, messages = decMsgs })
        elseif msg.type == "list_servers" then
            broadcastServerList()
        end
    end
end

