
--local mash       = {"cmd", "alt", "ctrl"}
--local mash_shift = {"cmd", "alt", "ctrl", "shift"}
local mash       = {"cmd", "ctrl"}
local mash_shift = {"cmd", "ctrl", "shift"}

local tickers  = { "AVGO", "NVDA", "TSLA", "INTC", "QCOM" }
local intrinio = "https://api.intrinio.com/data_point?identifier=" .. table.concat(tickers,",") .. "&item=last_price,change,percent_change"

local curl    = "/usr/bin/curl"
local menubar = hs.menubar.new()
local stocks  = nil

local log = hs.logger.new('stocks','debug')

local STOCKS_UPDATE_TIMER = 30 -- minutes

local function fslurp(path)
    local f = io.open(path, "r")
    local s = f:read("*all")
    f:close()
    return s
end

local config = hs.json.decode(fslurp("intrinio.json"))

local function stocksUpdate(exitCode, stdOut, stdErr)
    if exitCode ~= 0 then
        --hs.alert("Stock update failed!")
        return
    end

    local data = hs.json.decode(stdOut)

    local font = { name = "Hack", size = 12 }

    local ticker_value = function(ticker, item)
        for i = 1, #data.data, 1 do
            if data.data[i].identifier == ticker and
               data.data[i].item == item then
               return data.data[i].value
           end
        end
    end

    local ticker_up = function(ticker)
        local change = ticker_value(ticker, "change")
        if change ~= "na" and change >= 0 then
            return true
        end
        return false
    end

    local ticker_text = function(ticker)
        local color = hs.drawing.color.x11.red
        local prfx = ""
        if ticker_up(ticker) then
            color = hs.drawing.color.x11.green
            prfx  = "+"
        end

        return
        hs.styledtext.new(ticker .. ": ",
                          {
                            font  = font,
                            color = hs.drawing.color.x11.deepskyblue
                          }) ..
        hs.styledtext.new(ticker_value(ticker, "last_price") .. " " ..
                          prfx .. ticker_value(ticker, "change") .. " " ..
                          prfx .. (ticker_value(ticker, "percent_change") * 100) .. "%",
                          {
                            font  = font,
                            color = color
                          })
    end

    menubar:setTitle(hs.styledtext.new("[",
                                       {
                                         font  = font,
                                         color = hs.drawing.color.x11.white
                                       }) ..
                     ticker_text(tickers[1]) ..
                     hs.styledtext.new("]",
                                       {
                                         font  = font,
                                         color = hs.drawing.color.x11.white
                                       })
                    )

    if #tickers > 1 then
        local submenu = { }
        for i = 2, #tickers, 1 do
            table.insert(submenu, { title = ticker_text(tickers[i]) })
        end
        menubar:setMenu(submenu)
    end

    --hs.alert("Stock quotes updated!")
end

local function doUpdate()
    local curl_args = { "-s", intrinio, "-u", config.user .. ":" .. config.pass }
    if not stocks or not stocks:isRunning() then
        stocks = hs.task.new(curl, stocksUpdate, curl_args )
        stocks:start()
    end
end

-- XXX only execute the timer when the market is open (6am-1pm PST)
local stockUpdateTimer = hs.timer.doEvery((STOCKS_UPDATE_TIMER * 60), doUpdate)
doUpdate()

hs.hotkey.bind(mash_shift, "q", function()
    doUpdate()
end)

