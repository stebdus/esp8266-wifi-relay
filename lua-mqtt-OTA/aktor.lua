mqtt_topic_state = "wifiRelay/TestRoomBlind/state"
mqtt_connected = 0
----------------

-- constants
ACTUATOR_VERSION = "0.4.0"
TMR_ACTUATOR_ID = 0
TMR_ACTUATOR_INTERVAL_IN_MS = 150
TMR_RELAY1_DELAY_ID = 6
TMR_RELAY2_DELAY_ID = 5
RELAY_STATE_OFF = 0
RELAY_STATE_ON = 1
SWITCH_STATE_CLOSED = gpio.LOW -- is 0
SWITCH_STATE_OPEN = gpio.HIGH -- is 1

-- user defined options
INTERLOCK_ENABLED = true -- if active, only one relay can be on at the same time
DELAY_TIMER_ENABLED = false -- timer to switch off relays after a specified time
RELAY1_DELAY_TIME_IN_SEC = 10 -- delay time to switch off in seconds for relay 1
RELAY2_DELAY_TIME_IN_SEC = 10 -- delay time to switch off in seconds for relay 2

-- config gpios
RELAY1_PIN = 4 -- GPIO2
RELAY2_PIN = 5 -- GPIO14
gpio.mode(RELAY1_PIN, gpio.OUTPUT)
gpio.mode(RELAY2_PIN, gpio.OUTPUT)
SWITCH1_PIN = 6 -- GPIO 12
SWITCH2_PIN = 7 -- GPIO 13
gpio.mode(SWITCH1_PIN, gpio.INPUT, gpio.PULLUP)
gpio.mode(SWITCH2_PIN, gpio.INPUT, gpio.PULLUP)

-- init variables with default values
relay1_state = 0 -- 0 is off
relay2_state = 0 -- 0 is off
switch1_prev_state = SWITCH_STATE_OPEN
switch2_prev_state = SWITCH_STATE_OPEN

-----------------------------------------------
function relay1_switchOff()
  gpio.write(RELAY1_PIN, gpio.HIGH) -- NC version: HIGH is off
end

function relay1_switchOn()
  gpio.write(RELAY1_PIN, gpio.LOW) -- NC version: LOW is on
end

function relay2_switchOff()
  gpio.write(RELAY2_PIN, gpio.HIGH) -- NC version: HIGH is off
end

function relay2_switchOn()
  gpio.write(RELAY2_PIN, gpio.LOW) -- NC version: LOW is on
end

-------------------------------------------------------------------------------------------------function mqtt_start()
function mqtt_start()
  local timer = require 'timer'
  local mqtt_clientID = "TestRoomBlind"
  local mqtt_topic = "wifiRelay/TestRoomBlind"
  local mqtt_topic_tilt = "wifiRelay/TestRoomBlind/tilt"
  local mqtt_topic_tilt_state = "wifiRelay/TestRoomBlind/tilt/state"
  local mqtt_topic_restart = "wifiRelay/restart"
  local blind_absolute_pos = 0

  mqtt = mqtt.Client(mqtt_clientID, 120, "xxx", "xxx")

  mqtt:on("connect", function(con)
    print ("MQTT connected!")
  end)
  mqtt:on("offline", function(con)
    print ("MQTT reconnecting...")
    mqtt_connected = 0
    print(node.heap())
    tmr.alarm(2, 2000, 0, function()
      mqtt:connect("192.168.0.xxx", 1883, 0)
      mqtt_connected = 1
    end)
  end)

  mqtt:connect("192.168.0.117", 1883, 0, function(conn)
    print("MQTT connected!")
    mqtt_connected = 1
    -- subscribe topic with qos = 0
    mqtt:subscribe(mqtt_topic, 0, function(conn)
      -- publish a message with data = my_message, QoS = 0, retain = 0
       mqtt:publish(mqtt_topic, "Hello, I'm "..mqtt_clientID, 0, 0)
    end)
    mqtt:subscribe(mqtt_topic_tilt, 0, function(conn)
      -- publish a message with data = my_message, QoS = 0, retain = 0
       mqtt:publish(mqtt_topic_tilt, "Hello tilt, I'm "..mqtt_clientID, 0, 0)
    end)
  end)

  -- MQTT msg: wifiRelay/SleepingRoomBlind-Down
  -- MQTT payload: ON,2000,1000 [command, ms to execute command]

  mqtt:on("message", function(conn, topic, data)
    print("MSG rec -> topic: "..topic..": ")

      if(topic == mqtt_topic) then
        if data ~= nil then
          print("data: "..data)
          tok1 = string.find(data, ',')
          if tok1 ~= nil then
            local numbers = {}
            for num in string.gmatch(data, "%d+") do
              numbers[#numbers + 1] = num
            end

            cmd_data = string.sub(data, 0, tok1 - 1)
            if numbers[1] ~= nil then
              timer1 = tonumber(numbers[1])
            end
            if numbers[2] ~= nil then
              timer2 = tonumber(numbers[2])
            end

            if (cmd_data == "UP") then
              -- msg recieved to open blinds: trigger relay1 for x seconds and release relay1
              print("Open Blinds")
              relay1_state = RELAY_STATE_ON
              local re1_timer = timer.setTimeout(function ()
                relay1_state = RELAY_STATE_OFF
              end, timer1)

              blind_absolute_pos = 0
              mqtt:publish(mqtt_topic_state, "open", 0, 0)
            elseif (cmd_data == "DOWN") then
              -- msg recieved to clode blinds: trigger relay2 for x seconds, release relay2, triger relay 1 for x seconds for slits
              print("Close Blinds")
              relay2_state = RELAY_STATE_ON
              local re2_timer = timer.setTimeout(function ()
                relay2_state = RELAY_STATE_OFF
              end, timer1)
              local re3_timer = timer.setTimeout(function ()
                relay1_state = RELAY_STATE_ON
              end, timer1 + 500)
              local re4_timer = timer.setTimeout(function ()
                relay1_state = RELAY_STATE_OFF
              end, timer1 + timer2 + 500)

              blind_absolute_pos = timer1
              mqtt:publish(mqtt_topic_state, "closed", 0, 0)
            end
            mqtt:publish(mqtt_topic_tilt_state, blind_absolute_pos, 0, 0)
          end
        end
      elseif (topic == mqtt_topic_tilt) then
        -- mqtt payload contains value between 0 - (time to close blinds)
        if data ~= nil then

          local numbers = {}
          for num in string.gmatch(data, "%d+") do
            numbers[#numbers + 1] = num
          end

          if (numbers[1] ~= nil) then
            local blind_new_pos = tonumber(numbers[1])

            print("PrePos/NewPos ["..blind_absolute_pos.."/"..blind_new_pos.."]")

            if (blind_absolute_pos < blind_new_pos) then
              -- going down
              calc_move = blind_new_pos - blind_absolute_pos
              blind_absolute_pos = blind_new_pos
              print("-> "..calc_move)
              -- go down for x sec
              print("Close Blinds")
              relay2_state = RELAY_STATE_ON
              local re5_timer = timer.setTimeout(function ()
                relay2_state = RELAY_STATE_OFF
              end, calc_move)
              mqtt:publish(mqtt_topic_state, "closed", 0, 0)
            elseif (blind_absolute_pos > blind_new_pos) then
              -- going up
              calc_move = blind_absolute_pos - blind_new_pos
              blind_absolute_pos = blind_new_pos

              print("-> "..calc_move)
              print("Open Blinds")
              relay1_state = RELAY_STATE_ON
              local re6_timer = timer.setTimeout(function ()
                relay1_state = RELAY_STATE_OFF
              end, calc_move)
              mqtt:publish(mqtt_topic_state, "open", 0, 0)
            else
              -- do nothing
              print("Same position was send!")
            end
            mqtt:publish(mqtt_topic_tilt_state, blind_new_pos, 0, 0)
          end
        end
      elseif (topic == mqtt_topic_restart) then
        mqtt:publish(mqtt_topic, "Restart node", 0, 0)
        print("Restart ESP8266... ")
        node.restart()
      else
        print("Unkown topic!")
      end

  end)
end


if wifi.sta.getip() ~= nil then
  print("mqtt start")
  mqtt_start()
end


function init_delay_timers()
  tmr.register(TMR_RELAY1_DELAY_ID, RELAY1_DELAY_TIME_IN_SEC * 1000, tmr.ALARM_SEMI, function()
    if(DELAY_TIMER_ENABLED == true) then
    relay1_state = RELAY_STATE_OFF
  end
end)

tmr.register(TMR_RELAY2_DELAY_ID, RELAY2_DELAY_TIME_IN_SEC * 1000, tmr.ALARM_SEMI, function()
  if(DELAY_TIMER_ENABLED == true) then
  relay2_state = RELAY_STATE_OFF
end
end)
end

function send_to_visu(sid, cmd)
-- zusaetzliche intelligence
  local switch
  if (cmd == "relay1") then
    switch = "open"
  elseif (cmd == "relay2") then
    switch = "closed"
  end
  if(mqtt_connected == 1) then
    mqtt:publish(sid, switch, 0, 0)
  else
    print("MQTT not yet started!")
    print("Msg: "..sid..":"..switch.." (NOT SEND)")
  end
end

-- start actuator
print("Actuator starting...")
init_delay_timers()

-- begin actuator timer to handle switches and relays
tmr.alarm(TMR_ACTUATOR_ID, TMR_ACTUATOR_INTERVAL_IN_MS, tmr.ALARM_AUTO, function()

-- read gpio states from switches and relays
local switch1_gpio_state = gpio.read(SWITCH1_PIN)
local switch2_gpio_state = gpio.read(SWITCH2_PIN)
local relay1_gpio_state = gpio.read(RELAY1_PIN)
local relay2_gpio_state = gpio.read(RELAY2_PIN)

-- begin switch1
if (switch1_gpio_state == SWITCH_STATE_CLOSED and switch1_prev_state ~= switch1_gpio_state) then
switch1_prev_state = SWITCH_STATE_CLOSED
--print("debug if 1")
if (relay1_state == RELAY_STATE_OFF) then
  relay1_state = RELAY_STATE_ON
  --print("relay1_state = 1")
  --send_to_visu(mqtt_topic_state, relay1_gpio_state)
  send_to_visu(mqtt_topic_state, "relay1")

elseif (relay1_state == RELAY_STATE_ON) then
  relay1_state = RELAY_STATE_OFF
  --print("relay1_state = 0")
  --, relay1_gpio_state)
  send_to_visu(mqtt_topic_state, "relay1")
end
elseif (switch1_gpio_state == SWITCH_STATE_OPEN and switch1_prev_state ~= switch1_gpio_state) then
switch1_prev_state = SWITCH_STATE_OPEN
--print("debug if 2")
if (relay1_state == RELAY_STATE_OFF) then
  relay1_state = RELAY_STATE_ON
  -- print("relay1_state = 1")
  --send_to_visu(mqtt_topic_state, relay1_gpio_state)
  send_to_visu(mqtt_topic_state, "relay1")
elseif (relay1_state == RELAY_STATE_ON) then
  relay1_state = RELAY_STATE_OFF
  --print("relay1_state = 0")
  --send_to_visu(mqtt_topic_state, relay1_gpio_state)
  send_to_visu(mqtt_topic_state, "relay1")
end
end
-- end switch1

-- begin switch2
if (switch2_gpio_state == SWITCH_STATE_CLOSED and switch2_prev_state ~= switch2_gpio_state) then
switch2_prev_state = SWITCH_STATE_CLOSED
--print("debug2 if 1")
if (relay2_state == RELAY_STATE_OFF) then
  relay2_state = RELAY_STATE_ON
  --print("relay2_state = 1")
  --send_to_visu(mqtt_topic_state, relay2_gpio_state)
  send_to_visu(mqtt_topic_state, "relay2")
elseif (relay2_state == RELAY_STATE_ON) then
  relay2_state = RELAY_STATE_OFF
  -- print("relay2_state = 0")
  --send_to_visu(mqtt_topic_state, relay2_gpio_state)
  send_to_visu(mqtt_topic_state, "relay2")
end
elseif (switch2_gpio_state == SWITCH_STATE_OPEN and switch2_prev_state ~= switch2_gpio_state) then
switch2_prev_state = SWITCH_STATE_OPEN
--print("debug2 if 2")
if (relay2_state == RELAY_STATE_OFF) then
  relay2_state = RELAY_STATE_ON
  --print("relay2_state = 1")
  --send_to_visu(mqtt_topic_state, relay2_gpio_state)
  send_to_visu(mqtt_topic_state, "relay2")
elseif (relay2_state == RELAY_STATE_ON) then
  relay2_state = RELAY_STATE_OFF
  -- print("relay2_state = 0")
  --send_to_visu(mqtt_topic_state, relay2_gpio_state)
  send_to_visu(mqtt_topic_state, "relay2")
end
end
-- end switch2

-- begin switching relays
if (relay1_state == RELAY_STATE_ON) then
if(INTERLOCK_ENABLED == true) then
  relay2_state = RELAY_STATE_OFF
end
if(DELAY_TIMER_ENABLED == true) then
  tmr.start(TMR_RELAY1_DELAY_ID)
end
relay1_switchOn()
--print("switch relay1 on")
end
if (relay1_state == RELAY_STATE_OFF) then
relay1_switchOff()
--print("switch relay1 off")
end

if (relay2_state == RELAY_STATE_ON) then
if(INTERLOCK_ENABLED == true) then
  relay1_state = RELAY_STATE_OFF
end
if(DELAY_TIMER_ENABLED == true) then
  tmr.start(TMR_RELAY2_DELAY_ID)
end
relay2_switchOn()
--print("switch relay2 on")
end
if (relay2_state == RELAY_STATE_OFF) then
relay2_switchOff()
--print("switch relay2 off")
end
-- end switching relays

end) -- end actuator timer function
