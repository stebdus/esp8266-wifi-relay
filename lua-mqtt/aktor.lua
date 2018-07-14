print("New version - stebDus")
mqtt_connected = 0
mqqt_clientID = "KitchenBlind"
mqtt_topic_R1 = "wifiRelay/KitchenBlind-Up"
mqtt_topic_R2 = "wifiRelay/KitchenBlind-Down"

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
local function mqtt_start()
    mqtt = mqtt.Client(mqqt_clientID, 120, "steb", "!!Ebe81ner")

    mqtt:on("connect", function(con)
      print ("MQTT connected!")
    end)
    mqtt:on("offline", function(con)
      print ("MQTT reconnecting...")
      mqtt_connected = 0
      print(node.heap())
      tmr.alarm(2, 2000, 0, function()
        mqtt:connect("192.168.0.117", 1883, 0)
        mqtt_connected = 1
      end)
    end)

    mqtt:connect("192.168.0.117", 1883, 0, function(conn)
      print("MQTT connected!")
      mqtt_connected = 1
      -- subscribe topic with qos = 0
      mqtt:subscribe(mqtt_topic_R1,0, function(conn)
        -- publish a message with data = my_message, QoS = 0, retain = 0
        mqtt:publish(mqtt_topic_R1, "Hello Msg", 0, 0, function(conn)
        end)
      end)
      mqtt:subscribe(mqtt_topic_R2,0, function(conn)
        -- publish a message with data = my_message, QoS = 0, retain = 0
        mqtt:publish(mqtt_topic_R2, "Hello Msg", 0, 0, function(conn)
        end)
      end)
    end)

    mqtt:on("message", function(conn, topic, data)
      print("MSG rec -> topic: "..topic..": ")
      if data ~= nil then
        print("data: "..data)
        if(topic == mqtt_topic_R1) then
          if (data == "ON") then
            print(mqtt_topic_R1..":"..data)
            if (relay1_state == RELAY_STATE_OFF) then
              relay1_state = RELAY_STATE_ON
            end
          end
          if (data == "OFF") then
            print(mqtt_topic_R1..":"..data)
            if (relay1_state == RELAY_STATE_ON) then
              relay1_state = RELAY_STATE_OFF
            end
          end
        elseif(topic == mqtt_topic_R2) then
          if (data == "ON") then
            print(mqtt_topic_R2..":"..data)
            if (relay2_state == RELAY_STATE_OFF) then
              relay2_state = RELAY_STATE_ON
            end
          end
          if (data == "OFF") then
            print(mqtt_topic_R2..":"..data)
            if (relay2_state == RELAY_STATE_ON) then
              relay2_state = RELAY_STATE_OFF
            end
          end
        end
      end
    end)
end

local function wifi_wait_ip()
  if wifi.sta.getip()== nil then
    print("IP unavailable, Waiting..."..count)
    count = count + 1
    if (count == 50) then
      node.restart()
    end
  else
    tmr.stop(1)
    print("\n====================================")
    print("ESP8266 mode is: " .. wifi.getmode())
    print("Chip ID "..node.chipid());
    print("MAC address is: " .. wifi.ap.getmac())
    print("IP is "..wifi.sta.getip())
    print("====================================")
    print("mqtt start")
    mqtt_start()
  end
end

-- wlan verbinden
wifi.sta.config("54MbitEssen", "ABDEFACD9876234561917256DC")
wifi.sta.connect()
print("Connecting to wifi...")
tmr.alarm(1, 2500, 1, wifi_wait_ip)



function init_delay_timers()
  tmr.register(TMR_RELAY1_DELAY_ID, RELAY1_DELAY_TIME_IN_SEC*1000, tmr.ALARM_SEMI, function()
    if(DELAY_TIMER_ENABLED == true) then
      relay1_state = RELAY_STATE_OFF
    end
  end)

  tmr.register(TMR_RELAY2_DELAY_ID, RELAY2_DELAY_TIME_IN_SEC*1000, tmr.ALARM_SEMI, function()
    if(DELAY_TIMER_ENABLED == true) then
      relay2_state = RELAY_STATE_OFF
    end
  end)
end


function send_to_visu(sid, cmd)
  local switch
  if (cmd == 1) then
    switch = "ON"
  elseif (cmd == 0) then
    switch = "OFF"
  end
  if(mqtt_connected == 1) then
    mqtt:publish(sid,switch, 0, 0, function(conn)
        print("Msg: "..sid..":"..switch.." (SEND)")
    end)
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
      send_to_visu(mqtt_topic_R1, relay1_gpio_state)

    elseif (relay1_state == RELAY_STATE_ON) then
      relay1_state = RELAY_STATE_OFF
      --print("relay1_state = 0")
      send_to_visu(mqtt_topic_R1, relay1_gpio_state)
    end
  elseif (switch1_gpio_state == SWITCH_STATE_OPEN and switch1_prev_state ~= switch1_gpio_state) then
    switch1_prev_state = SWITCH_STATE_OPEN
    --print("debug if 2")
    if (relay1_state == RELAY_STATE_OFF) then
      relay1_state = RELAY_STATE_ON
      -- print("relay1_state = 1")
      send_to_visu(mqtt_topic_R1, relay1_gpio_state)
    elseif (relay1_state == RELAY_STATE_ON) then
      relay1_state = RELAY_STATE_OFF
      --print("relay1_state = 0")
      send_to_visu(mqtt_topic_R1, relay1_gpio_state)
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
      send_to_visu(mqtt_topic_R2, relay2_gpio_state)
    elseif (relay2_state == RELAY_STATE_ON) then
      relay2_state = RELAY_STATE_OFF
      -- print("relay2_state = 0")
      send_to_visu(mqtt_topic_R2, relay2_gpio_state)
    end
  elseif (switch2_gpio_state == SWITCH_STATE_OPEN and switch2_prev_state ~= switch2_gpio_state) then
    switch2_prev_state = SWITCH_STATE_OPEN
    --print("debug2 if 2")
    if (relay2_state == RELAY_STATE_OFF) then
      relay2_state = RELAY_STATE_ON
      --print("relay2_state = 1")
      send_to_visu(mqtt_topic_R2, relay2_gpio_state)
    elseif (relay2_state == RELAY_STATE_ON) then
      relay2_state = RELAY_STATE_OFF
      -- print("relay2_state = 0")
      send_to_visu(mqtt_topic_R2, relay2_gpio_state)
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
