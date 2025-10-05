local modem = peripheral.find("modem")
if not modem then print("No modem found!") return end
modem.open(1)

local nickname = ""
local server_id = nil
local chat_id = nil
local messages = {}

local function clear()
    term.clear()
    term.setCursorPos(1,1)
end

local function waitKey()
    os.pullEvent("key")
end

local function showMainMenu()
    clear()
    print("Welcome to TESTCHAT")
    print("-------------------")
    print("1. Register / Login")
    print("2. Choose Server")
    print("3. Join Chat")
    print("4. Private Messages")
    print("5. Create Chat")
    print("6. Create Server")
    print("7. Server List")
    print("8. Exit")
    print("-------------------")
    if server_id then
        print("Selected Server: " .. server_id)
    else
        print("Selected Server: none")
    end
    print("VERSION 1")
end

local function registerLogin()
    clear()
    write("Enter your nickname: ")
    nickname = read()
end

local function chooseServer()
    clear()
    print("Getting server list...")
    modem.transmit(1, 1, { type = "list_servers" })
    local _, _, _, _, msg = os.pullEvent("modem_message")
    if msg.type == "server_list" then
        local list = msg.list
        if #list == 0 then print("No servers found.") waitKey() return end
        print("Available servers:")
        for i, s in ipairs(list) do
            print(i .. ". " .. s.id .. " (" .. s.connections .. " clients)")
        end
        write("Choose server number: ")
        local num = tonumber(read())
        if num and list[num] then
            server_id = list[num].id
            print("Server selected: " .. server_id)
        else
            print("Invalid choice")
        end
        sleep(1)
    end
end

local function createServer()
    clear()
    write("Enter new server ID: ")
    local id = read()
    write("Enter encryption key (number): ")
    local key = tonumber(read())
    local port = math.random(1000, 9999)
    modem.transmit(1, 1, { type = "register_server", server_id = id, port = port, key = key })
    print("Server created: " .. id)
    sleep(1)
end

local function createChat()
    clear()
    write("Enter new chat ID: ")
    chat_id = read()
    print("Chat created:", chat_id)
    sleep(1)
end

local function chatMenu()
    if not server_id then print("Select server first!") sleep(1) return end
    clear()
    write("Enter chat ID: ")
    chat_id = read()
    modem.transmit(1, 1, { type = "get_chat", server_id = server_id, chat_id = chat_id })
    while true do
        local _, _, _, _, msg = os.pullEvent("modem_message")
        if msg.type == "chat_update" and msg.chat_id == chat_id then
            messages = msg.messages
            clear()
            print("Nick: " .. nickname)
            print("Server: " .. server_id)
            print("Chat: " .. chat_id)
            print("-------------------")
            for i = math.max(1, #messages - 10), #messages do
                local m = messages[i]
                print("["..textutils.formatTime(m.time, true).."] " .. m.user .. ": " .. m.text)
            end
            print("-------------------")
            write("Message (or 'exit'): ")
            local text = read()
            if text == "exit" then break end
            modem.transmit(1, 1, { type = "send_chat", server_id = server_id, chat_id = chat_id, user = nickname, text = text })
        end
    end
end

while true do
    showMainMenu()
    write("Select option: ")
    local opt = read()
    if opt == "1" then registerLogin()
    elseif opt == "2" then chooseServer()
    elseif opt == "3" then chatMenu()
    elseif opt == "5" then createChat()
    elseif opt == "6" then createServer()
    elseif opt == "8" then clear() print("Goodbye!") break
    else print("Invalid option.") sleep(1)
    end
end

