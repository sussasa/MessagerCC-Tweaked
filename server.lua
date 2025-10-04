local users = {}
local chats = {}
local side = "back"

rednet.open(side)

print("TESTCHAT SERVER started")

while true do
    local id, msg = rednet.receive()
    if type(msg) == "table" then
        if msg.type == "register" then
            if users[msg.nick] then
                rednet.send(id, {type="register", success=false, reason="Nickname already exists"})
            else
                users[msg.nick] = {password=msg.password}
                rednet.send(id, {type="register", success=true})
            end
        elseif msg.type == "login" then
            if users[msg.nick] and users[msg.nick].password == msg.password then
                rednet.send(id, {type="login", success=true})
            else
                rednet.send(id, {type="login", success=false, reason="Wrong nick or password"})
            end
        elseif msg.type == "create_chat" then
            if chats[msg.chat] then
                rednet.send(id, {type="create_chat", success=false, reason="Chat code already exists"})
            else
                chats[msg.chat] = {}
                rednet.send(id, {type="create_chat", success=true})
            end
        elseif msg.type == "send_message" then
            if chats[msg.chat] then
                table.insert(chats[msg.chat], msg.nick..": "..msg.text)
                rednet.broadcast({type="new_message", chat=msg.chat, text=msg.nick..": "..msg.text})
            end
        elseif msg.type == "history" then
            if chats[msg.chat] then
                rednet.send(id, {type="history", chat=msg.chat, messages=chats[msg.chat]})
            else
                rednet.send(id, {type="history", chat=msg.chat, messages={}})
            end
        end
    end
end

