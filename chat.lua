-- client.lua
-- uses rednet for communication; menu numbers 1..8

local function try_open_rednet()
  local sides = {"back","top","bottom","left","right","front"}
  for _,s in ipairs(sides) do
    local ok, typ = pcall(peripheral.getType, s)
    if ok and typ and tostring(typ):lower():find("modem") then
      local o = pcall(rednet.open, s)
      if o then return s end
    end
  end
  pcall(rednet.open, "back")
  return "back"
end

local rednetSide = try_open_rednet()

local cfgDir = "/testchat_client/"
fs.makeDir(cfgDir)
local serverFile = cfgDir.."server.cfg"
local function saveServer(s) local f=fs.open(serverFile,"w"); f.write(s); f.close() end
local function loadServer() if not fs.exists(serverFile) then return nil end; local f=fs.open(serverFile,"r"); local s=f.readAll(); f.close(); return s end

local server = loadServer()
local user, pass = nil, nil

local function recv(timeout)
  local id,msg = rednet.receive(timeout)
  if not msg then return nil end
  local ok, d = pcall(textutils.unserialize, msg)
  if ok and type(d)=="table" then return d end
  return nil
end

local function send(obj)
  rednet.broadcast(textutils.serialize(obj))
end

local function pingServers(timeout)
  local found = {}
  send({action="ping"})
  local t = os.startTimer(timeout or 2)
  while true do
    local e,a,b = os.pullEvent()
    if e == "timer" and b == t then break end
    if e == "rednet_message" then
      local ok, data = pcall(textutils.unserialize, select(3,a,b))
      if ok and type(data)=="table" and data.type=="pong" and data.server then
        found[data.server] = true
      end
    end
  end
  local list = {}
  for k,_ in pairs(found) do table.insert(list,k) end
  table.sort(list)
  return list
end

local function drawMain()
  term.clear()
  term.setCursorPos(1,1)
  print("=====================================")
  print("           WELCOME TO TESTCHAT")
  print("=====================================")
  print("[0] Select server")
  print("[1] Join chat by code")
  print("[2] Create chat")
  print("[3] Direct messages")
  print("[4] Register / Login")
  print("[5] Help & Commands")
  print("[6] Exit")
  print("-------------------------------------")
  print("Server: "..(server or "None"))
  print("User: "..(user or "None"))
  print("=====================================")
  write("Select: ")
end

local function chooseServer()
  term.clear(); print("Searching for servers...")
  local list = pingServers(2)
  term.clear(); print("Available servers:")
  if #list == 0 then
    print("No servers found. Type server code to set manually or press Enter to cancel.")
    write("Server code: "); local s = read()
    if s and s ~= "" then server = s; saveServer(server) end
    return
  end
  for i=1,#list do print(i..") "..list[i]) end
  print("n) Enter custom server code")
  write("Select: ")
  local sel = read()
  if sel == "n" then
    write("Enter server code: ")
    local s = read()
    if s ~= "" then server = s; saveServer(server) end
  else
    local idx = tonumber(sel)
    if idx and list[idx] then server = list[idx]; saveServer(server) end
  end
end

local function registerLogin()
  term.clear()
  print("Register/Login")
  write("Register (r) or Login (l): ")
  local c = read()
  write("Username: "); local u = read()
  write("Password: "); local p = read("*")
  if c == "r" then
    send({action="register", user=u, pass=p})
  else
    send({action="login", user=u, pass=p})
  end
  local r = recv(3)
  if r and r.type == "register" and r.ok then user=u; pass=p; print("Registered and logged in") 
  elseif r and r.type == "login" and r.ok then user=u; pass=p; print("Login ok")
  else print("Failed") end
  sleep(1.2)
end

local function createRoom()
  if not server then print("Select server first"); sleep(1.2); return end
  if not user then print("Login first"); sleep(1.2); return end
  write("Enter new room code: "); local room = read()
  send({action="create_room", room=room})
  local r = recv(2)
  if r and r.type=="create_room" and r.ok then print("Room created") else print("Create failed") end
  sleep(1)
end

local function loadHistory(room)
  send({action="history", room=room})
  local start = os.clock()
  while os.clock() - start < 2 do
    local r = recv(0.5)
    if r and r.type=="history" and r.room==room then return r.messages end
  end
  return {}
end

local function chatRoom(room)
  local messages = loadHistory(room)
  local scroll = 0
  local function redraw()
    term.clear()
    print("User: "..(user or "None").." | Server: "..(server or "None").." | Room: "..room)
    print("------------------------------------------------")
    local h = 12
    local start = math.max(1, #messages - h + 1 - scroll)
    for i = start, math.min(#messages, start + h - 1) do print(messages[i]) end
    print("------------------------------------------------")
    write("> ")
  end
  redraw()
  while true do
    parallel.waitForAny(
      function()
        local r = recv(nil)
        if r and r.type=="new_room_msg" and r.room==room then
          table.insert(messages, "["..(r.time or "").."] "..(r.user or "")..": message sent")
          scroll = 0; redraw()
        end
      end,
      function()
        write("> "); local txt = read()
        if txt == "/exit" then return end
        send({action="send_room", room=room, user=user, text=txt})
      end,
      function()
        while true do
          local e,k = os.pullEvent("key")
          if k == keys.up then if scroll < #messages - 1 then scroll = scroll + 1; redraw() end
          elseif k == keys.down then if scroll > 0 then scroll = scroll - 1; redraw() end
          end
        end
      end
    )
  end
end

local function dmRoom(target)
  local messages = {}
  send({action="dm_history", user=user, to=target})
  local start = os.clock()
  while os.clock() - start < 2 do
    local r = recv(0.5)
    if r and r.type=="dm_history" then messages = r.messages; break end
  end
  local scroll = 0
  local function redraw()
    term.clear()
    print("DM: "..user.." <-> "..target.." | Server: "..(server or "None"))
    print("------------------------------------------------")
    local h = 12
    local start = math.max(1, #messages - h + 1 - scroll)
    for i = start, math.min(#messages, start + h - 1) do print(messages[i]) end
    print("------------------------------------------------")
    write("> ")
  end
  redraw()
  while true do
    parallel.waitForAny(
      function()
        local r = recv(nil)
        if r and r.type=="new_dm" then
          -- new_dm contains from/to/time (server broadcasts)
          if (r.a == user and r.b == target) or (r.a == target and r.b == user) then
            table.insert(messages, "["..(r.time or "").."] "..(r.a or "")..": message sent")
            scroll = 0; redraw()
          end
        end
      end,
      function()
        write("> "); local txt = read()
        if txt == "/exit" then return end
        send({action="send_dm", user=user, to=target, text=txt})
      end,
      function()
        while true do
          local e,k = os.pullEvent("key")
          if k == keys.up then if scroll < #messages - 1 then scroll = scroll + 1; redraw() end
          elseif k == keys.down then if scroll > 0 then scroll = scroll - 1; redraw() end
          end
        end
      end
    )
  end
end

while true do
  drawMain()
  local c = read()
  if c == "0" then chooseServer()
  elseif c == "1" then registerLogin()
  elseif c == "2" then
    if not server then print("Select server first"); sleep(1) else write("Room code: "); local r=read(); chatRoom(r) end
  elseif c == "3" then
    if not server then print("Select server first"); sleep(1) else write("Target user: "); local t=read(); dmRoom(t) end
  elseif c == "4" then registerLogin()
  elseif c == "5" then
    term.clear(); print("Commands: /exit - return; /history - reload; arrow keys to scroll"); os.pullEvent("key")
  elseif c == "6" then
    if user then send({action="disconnect"}) end
    break
  else
    print("Invalid option."); sleep(0.8)
  end
end

