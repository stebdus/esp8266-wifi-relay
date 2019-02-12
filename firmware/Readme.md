## Frmware update process:
1) Connect USB-UART
2) Connect GPIO0 with GND
3) Connect 5v and GND to USB-UART
4) Connect data cable (TX -> RX, RX -> TX)
5) sudo python ./esptool.py --port /dev/ttyUSB0 erase_flash (alternative ttyUSB1)
6) Redo step 3 and 4
7) sudo python ./esptool.py --port /dev/ttyUSB0 write_flash -fm=dio -fs=4MB 0x000000 nodemcu-master-10-modules-2019-02-11-19-38-22-float.bin 0x3fc000 esp_init_data_default_v08.bin

**Note:** The old firmware runs on a baudrate of 9600. The newer one on 115200.


Nodemcu [firmware builder](https://nodemcu-build.com/) to individually confiugure modules: 

If you need to customize init data then first download the [Espressif SDK 2.2.0](https://github.com/espressif/ESP8266_NONOS_SDK/archive/v2.2.0.zip) and extract esp_init_data_default.bin. Then flash that file just like you'd flash the firmware. The correct address for the init data depends on the capacity of the flash chip.
0x7c000 for 512 kB, modules like most ESP-01, -03, -07 etc.
0xfc000 for 1 MB, modules like ESP8285, PSF-A85, some ESP-01, -03 etc.
0x1fc000 for 2 MB
0x3fc000 for 4 MB, modules like ESP-12E, NodeMCU devkit 1.0, WeMos D1 mini
0x7fc000 for 8 MB
0xffc000 for 16 MB, modules like WeMos D1 mini pro

**nodemcu-master-12-modules-2016-01-20-21-33-33-float.bin**
NodeMCU custom build by frightanic.com
    branch: master
    commit: c8037568571edb5c568c2f8231e4f8ce0683b883
    SSL: false
    **modules: node,file,gpio,wifi,net,tmr,uart,ow,mqtt,cjson,dht,enduser_setup**
 build  built on: 2016-01-20 21:33
 powered by Lua 5.1.4 on SDK 1.4.0
