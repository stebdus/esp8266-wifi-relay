-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- User changeable values
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

-- Enter the SSID (name) of the WiFi network for 'ssid', and enter the matching
--	 password for 'pwd'
wifi.setmode(wifi.STATION)
wifi.sta.config(
	{
		ssid = "xxx",
		pwd = "xxx",
	}
)

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --
-- End of user changeable values, start of program
--   Don't change anything below this line
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --

node.compile("aktor.lua")

-- Initiate aktor script
--local AKTOR = require("aktor")
-- Initiate WebIDE script
local IDE = require("OnlineIDE")

function handleStuff()
	srv=net.createServer(net.TCP)
	srv:listen(43333, function(conn)

		conn:on("receive", function(sck, payload)
        print("Init.lua :: RECEIVE")
				IDE.receive(sck, payload)
		end)

		conn:on("sent", function(sck)
        print("Init.lua :: SENT")
		    IDE.sent(sck)
	  	end)
	end)

  -- load aktor script for handling mqtt
  --dofile("aktor.lua")
end

function connected()
    print("Connected to WiFi")
    local ip, nm, gw = wifi.sta.getip()
    --print("\n====================================")
    --print("ESP8266 mode is: " .. wifi.getmode())
    --print("Chip ID "..node.chipid());
    --print("MAC address is: " .. wifi.ap.getmac())
    print("IP: "..tostring(ip))
    --print("Subnet Mask: "..tostring(nm))
    --print("Gateway: "..tostring(gw))
    --print("====================================")
    --print("mqtt start")
    require("aktor")
end

-- If an IP is assigned, print the çontents of the 'connected' function, and create the server.
--	 Otherwise, register a callback for when an IP is assigned, and then execute those actions.
if (wifi.sta.status() == wifi.STA_GOTIP) then
    connected()
    handleStuff()
else
    print("Connecting to WiFi...")
    wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function()
        wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
        connected()
        handleStuff()
    end)
end
