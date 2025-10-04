local side = "back"
rednet.open(side)

local nick = nil
local password = nil
local currentChat = nil

function mainMenu()
    term.clear()
    term.setCursorPos(1,1)
    print("Welcome to TESTCHAT")
    print("1. Register")
    print("2. Login")
    print("3. Join chat")
    print("4. Create chat")
    print("5. Exit")
    print("")
    print("--- Commands Guide ---")
    print("/exit   - go to main menu")
    print("/w <nick> <message> - private message")
    print("/switch <code> - switch chat")
    print("/history - show full history")
    print("-----------------------")
    print("VERSION 1")
    write("> ")
end

function register()
    term.clear()
    print("Register")
    write("Enter nickname: ")
    local n = read()
    write("Enter password: ")
    local p = read("*")
    rednet.broadcast({type="register", nick=n, password=p})
    local _, response = rednet.receive(2)
    if response and response.type=="register" and response.success then
        print("Registration successful!")
    else
        print("Registration failed: "..(response and response.reason or "No server"))
    end
    sleep(2)
end

function login()
    term.clear()
    print("Login")
    write("Enter nickname: ")
    local n = read()
    write("Enter password: ")
    local p = read("*")
    rednet.broadcast({type="login", nick=n, password=p})
    local _, response = rednet.receive(2)
    if response and response.type=="login" and response.success then
        nick = n
        password = p
        print("Login successful!")
    else
        print("Login failed: "..(response and response.reason or "No server"))
    end
    sleep(2)
end

function joinChat()
    if not nick then
        print("You must login first!")
        sleep(2)
        return
    end
    term.clear()
    write("Enter chat code: ")
    local c = read()
    currentChat = c
    chatLoop()
end

function createChat()
    if not nick then
        print("You must login first!")
        sleep(2)
        return
    end
    term.clear()
    write("Enter new chat code: ")
    local c = read()
    rednet.broadcast({type="create_chat", chat=c})
    local _, response = rednet.receive(2)
    if response and response.type=="create_chat" and response.success then
        print("Chat created!")
        currentChat = c
        sleep(1)
        chatLoop()
    else
        print("Chat creation failed: "..(response and response.reason or "No server"))
        sleep(2)
    end
end

function chatLoop()
    term.clear()
    print("Your nickname: "..nick)
    print("Chat code: "..currentChat)
    print("-----------------------------")
    while true do
        parallel.waitForAny(
            function()
                local id, msg = rednet.receive()
                if msg.type=="new_message" and msg.chat==currentChat then
                    print(msg.text)
                elseif msg.type=="history" and msg.chat==currentChat then
                    print("Chat history:")
                    for _,m in ipairs(msg.messages) do
                        print(m)
                    end
                end
            end,
            function()
                write("> ")
                local text = read()
                if text=="/exit" then return end
                if text=="/history" then
                    rednet.broadcast({type="history", chat=currentChat})
                else
                    rednet.broadcast({type="send_message", chat=currentChat, nick=nick, text=text})
                end
            end
        )
    end
end

while true do
    mainMenu()
    local choice = read()
    if choice=="1" then
        register()
    elseif choice=="2" then
        login()
    elseif choice=="3" then
        joinChat()
    elseif choice=="4" then
        createChat()
    elseif choice=="5" then
        break
    end
end
