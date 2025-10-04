rednet.open("back")

local usersFile = "users.db"
local users = {}
local chats = {}

local function loadUsers()
    if fs.exists(usersFile) then
        local f = fs.open(usersFile, "r")
        users = textutils.unserialize(f.readAll()) or {}
        f.close()
    end
end

local function saveUsers()
    local f = fs.open(usersFile, "w")
    f.write(textutils.serialize(users))
    f.close()
end

loadUsers()

while true do
    local id, msg = rednet.receive()
    local data = textutils.unserialize(msg)
    if data then
        if data.type == "register" then
            if users[data.user] then
                rednet.send(id, textutils.serialize({ok=false, reason="user_exists"}))
            else
                users[data.user] = {password=data.password}
                saveUsers()
                rednet.send(id, textutils.serialize({ok=true}))
            end
        elseif data.type == "login" then
            local u = users[data.user]
            if u and u.password == data.password then
                rednet.send(id, textutils.serialize({ok=true}))
            else
                rednet.send(id, textutils.serialize({ok=false}))
            end
        elseif data.type == "message" then
            chats[data.chat] = chats[data.chat] or {}
            table.insert(chats[data.chat], {user=data.user, text=data.text, time=data.time})
            rednet.broadcast(textutils.serialize({
                type="new_message",
                chat=data.chat,
                user=data.user,
                text=data.text,
                time=data.time
            }))
        elseif data.type == "whisper" then
            for pid,_ in pairs(rednet.lookup("user", data.to) or {}) do
                rednet.send(pid, textutils.serialize(data))
            end
        end
    end
end
