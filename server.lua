term.clear()
term.setCursorPos(1,1)
print("TESTCHAT server setup")
write("Enter server ID (press Enter for DEFAULT): ")
local serverCode = read()
if serverCode == "" then serverCode = "DEFAULT" end
write("Enter encryption key (number, press Enter for 0): ")
local key_input = read()
local ENC_KEY = tonumber(key_input) or 0

local function bxor(a,b)
  if bit and bit.bxor then return bit.bxor(a,b) end
  if bit32 and bit32.bxor then return bit32.bxor(a,b) end
  local res, bitv = 0, 1
  while a>0 or b>0 do
    local aa = a % 2
    local bb = b % 2
    if (aa ~= bb) then res = res + bitv end
    a = math.floor(a/2)
    b = math.floor(b/2)
    bitv = bitv * 2
  end
  return res
end

local function xor_bytes(s,key)
  if key == 0 then return s end
  local out = {}
  local k = key % 256
  for i=1,#s do
    local c = string.byte(s,i)
    out[i] = string.char(bxor(c, k))
  end
  return table.concat(out)
end

local function to_hex(s)
  local t = {}
  for i=1,#s do t[#t+1] = string.format("%02X", string.byte(s,i)) end
  return table.concat(t)
end

local function from_hex(h)
  local t = {}
  for i=1,#h,2 do
    local byte = tonumber(h:sub(i,i+1),16) or 0
    t[#t+1] = string.char(byte)
  end
  return table.concat(t)
end

local function encrypt_text(plain)
  return to_hex(xor_bytes(plain, ENC_KEY))
end

local function decrypt_text(hex)
  return xor_bytes(from_hex(hex), ENC_KEY)
end

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

local base = "/testchat/"..serverCode.."/"
fs.makeDir(base)
fs.makeDir(base.."rooms/")
fs.makeDir(base.."dms/")
local usersFile = base.."users.db"
local logsFile = base.."logs.txt"

local function loadFile(path)
  if not fs.exists(path) then return {} end
  local f = fs.open(path,"r")
  local ok, t = pcall(textutils.unserialize, f.readAll())
  f.close()
  if ok and type(t) == "table" then return t end
  return {}
end

local function saveFile(path, tbl)
  local f = fs.open(path,"w")
  f.write(textutils.serialize(tbl))
  f.close()
end

local function log(msg)
  local f = fs.open(logsFile,"a")
  f.write(os.date("%Y-%m-%d %H:%M:%S").." | "..msg.."\n")
  f.close()
end

local users = loadFile(usersFile)
log("Server "..serverCode.." started on side "..tostring(rednetSide).." (enc key set)")

local chats = {} -- in-memory cache (file-backed)
local dms = {}

local function save_room_msg(room, user, text)
  local path = base.."rooms/"..room..".db"
  local msgs = loadFile(path)
  local enc = encrypt_text(text)
  table.insert(msgs, {user=user, text=enc, time=os.time()})
  saveFile(path, msgs)
end

local function get_room_history_decrypted(room)
  local path = base.."rooms/"..room..".db"
  local stored = loadFile(path)
  local out = {}
  for i=1,#stored do
    local m = stored[i]
    local dec = ""
    if m.text then dec = decrypt_text(m.text) end
    out[#out+1] = "["..(m.time and textutils.formatTime(m.time,true) or "").."] "..(m.user or "")..": "..dec
  end
  return out
end

local function save_dm(from,to,text)
  local a,b = from,to
  if a > b then a,b = b,a end
  local path = base.."dms/dm_"..a.."_"..b..".db"
  local msgs = loadFile(path)
  local enc = encrypt_text(text)
  table.insert(msgs, {from=from, to=to, text=enc, time=os.time()})
  saveFile(path, msgs)
end

local function get_dm_history(from,to)
  local a,b = from,to
  if a > b then a,b = b,a end
  local path = base.."dms/dm_"..a.."_"..b..".db"
  local stored = loadFile(path)
  local out = {}
  for i=1,#stored do
    local m = stored[i]
    local dec = ""
    if m.text then dec = decrypt_text(m.text) end
    out[#out+1] = "["..(m.time and textutils.formatTime(m.time,true) or "").."] "..(m.from or "")..": "..dec
  end
  return out
end

while true do
  local sender, raw = rednet.receive()
  local ok, data = pcall(textutils.unserialize, raw)
  if not ok or type(data) ~= "table" then
    rednet.send(sender, textutils.serialize({type="error", reason="bad_message"}))
  else
    local a = data.action
    if a == "register" then
      local u = data.user or ""; local p = data.pass or ""
      if users[u] then
        rednet.send(sender, textutils.serialize({type="register", ok=false, reason="exists"}))
      else
        users[u] = p
        saveFile(usersFile, users)
        rednet.send(sender, textutils.serialize({type="register", ok=true}))
        log("User registered: "..u)
      end

    elseif a == "login" then
      local u = data.user or ""; local p = data.pass or ""
      if users[u] and users[u] == p then
        rednet.send(sender, textutils.serialize({type="login", ok=true}))
        log("User login: "..u)
      else
        rednet.send(sender, textutils.serialize({type="login", ok=false}))
      end

    elseif a == "create_room" then
      local room = data.room or ""
      local path = base.."rooms/"..room..".db"
      if fs.exists(path) then
        rednet.send(sender, textutils.serialize({type="create_room", ok=false, reason="exists"}))
      else
        saveFile(path, {})
        rednet.send(sender, textutils.serialize({type="create_room", ok=true}))
        log("Room created: "..room)
      end

    elseif a == "history" then
      local room = data.room or ""
      local hist = get_room_history_decrypted(room)
      rednet.send(sender, textutils.serialize({type="history", room=room, messages=hist}))
      log("History requested: "..room)

    elseif a == "send_room" then
      local room = data.room or ""; local user = data.user or ""; local text = data.text or ""
      save_room_msg(room,user,text)
      log("Message stored in room "..room.." by "..user)
      rednet.broadcast(textutils.serialize({type="new_room_msg", room=room, user=user, time=textutils.formatTime(os.time(), true)}))

    elseif a == "dm_history" then
      local from = data.user or ""; local to = data.to or ""
      local hist = get_dm_history(from,to)
      rednet.send(sender, textutils.serialize({type="dm_history", a=from, b=to, messages=hist}))
      log("DM history requested "..from.." <-> "..to)

    elseif a == "send_dm" then
      local from = data.user or ""; local to = data.to or ""; local text = data.text or ""
      save_dm(from,to,text)
      log("DM stored "..from.." -> "..to)
      rednet.broadcast(textutils.serialize({type="new_dm", from=from, to=to, time=textutils.formatTime(os.time(), true)}))

    elseif a == "ping" then
      rednet.send(sender, textutils.serialize({type="pong", server=serverCode}))

    elseif a == "connect" then
      log("Client connected (id "..tostring(sender)..")")
      rednet.send(sender, textutils.serialize({type="ok"}))
    end
  end
end

