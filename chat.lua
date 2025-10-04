rednet.open("back")

local nickname, password

local function registerUser()
    term.clear()
    print("=== Регистрация ===")
    write("Введите ник: ")
    local user = read()
    write("Введите пароль: ")
    local pass = read("*")
    rednet.broadcast(textutils.serialize({type="register", user=user, password=pass}))
    local _, reply = rednet.receive(2)
    if reply then
        local res = textutils.unserialize(reply)
        if res.ok then
            print("Регистрация успешна!")
            os.sleep(1)
        else
            print("Пользователь уже существует!")
            os.sleep(1)
        end
    end
end

local function loginUser()
    term.clear()
    print("=== Вход ===")
    write("Ник: ")
    local user = read()
    write("Пароль: ")
    local pass = read("*")
    rednet.broadcast(textutils.serialize({type="login", user=user, password=pass}))
    local _, reply = rednet.receive(2)
    if reply then
        local res = textutils.unserialize(reply)
        if res.ok then
            nickname, password = user, pass
            return true
        else
            print("Неверные данные!")
            os.sleep(1)
        end
    end
    return false
end

local function redraw(title, messages, scroll)
    term.clear()
    term.setCursorPos(1,1)
    print(title)
    print("--------------------------")
    local maxLines = 13
    local startIndex = math.max(1, #messages - maxLines + 1 + scroll)
    local endIndex = math.min(#messages, startIndex + maxLines - 1)
    for i=startIndex, endIndex do
        local msg = messages[i]
        if msg.user == nickname then term.setTextColor(colors.green)
        else term.setTextColor(colors.white) end
        print("["..msg.time.."] "..msg.user..": "..msg.text)
    end
    term.setTextColor(colors.white)
    term.setCursorPos(1, 17)
    term.clearLine()
    write("Введите сообщение: ")
end

local function chatRoom(chatCode, isPrivate, targetUser)
    local messages, scroll = {}, 0
    redraw("Чат: "..chatCode, messages, scroll)
    parallel.waitForAny(
        function()
            while true do
                local _, msg = rednet.receive()
                local data = textutils.unserialize(msg)
                if data then
                    if isPrivate and data.type=="whisper" and 
                       ((data.to==nickname and data.from==targetUser) or (data.from==nickname and data.to==targetUser)) then
                        table.insert(messages, {user=data.from, text=data.text, time=data.time})
                        redraw("ЛС: "..targetUser, messages, scroll)
                    elseif not isPrivate and data.type=="new_message" and data.chat==chatCode then
                        table.insert(messages, {user=data.user, text=data.text, time=data.time})
                        redraw("Чат: "..chatCode, messages, scroll)
                    end
                end
            end
        end,
        function()
            while true do
                term.setCursorPos(1,17)
                term.clearLine()
                write("Введите сообщение: ")
                local text = read()
                if text=="/exit" then return end
                if isPrivate then
                    rednet.broadcast(textutils.serialize({
                        type="whisper",
                        from=nickname,
                        to=targetUser,
                        text=text,
                        time=textutils.formatTime(os.time(), true)
                    }))
                else
                    rednet.broadcast(textutils.serialize({
                        type="message",
                        chat=chatCode,
                        user=nickname,
                        text=text,
                        time=textutils.formatTime(os.time(), true)
                    }))
                end
            end
        end
    )
end

local function mainMenu()
    while true do
        term.clear()
        print("Добро пожаловать в TESTCHAT")
        print()
        print("1. Войти в чат")
        print("2. Личные сообщения")
        print("3. Создать чат")
        print("4. Регистрация")
        print("5. Выйти")
        print()
        print("Команды внутри чата:")
        print("/exit - выйти в меню")
        print()
        write("Ваш выбор: ")
        local choice = read()
        if choice=="1" then
            if not loginUser() then goto continue end
            write("Введите код чата: ")
            local chatCode = read()
            chatRoom(chatCode, false)
        elseif choice=="2" then
            if not loginUser() then goto continue end
            write("Введите ник собеседника: ")
            local target = read()
            chatRoom("ЛС_"..target, true, target)
        elseif choice=="3" then
            if not loginUser() then goto continue end
            write("Введите код нового чата: ")
            local newCode = read()
            chatRoom(newCode, false)
        elseif choice=="4" then
            registerUser()
        elseif choice=="5" then
            return
        end
        ::continue::
    end
end

mainMenu()
