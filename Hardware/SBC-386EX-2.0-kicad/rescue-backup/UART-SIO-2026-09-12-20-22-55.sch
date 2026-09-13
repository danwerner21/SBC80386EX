EESchema Schematic File Version 2
LIBS:KISS68030-cache
LIBS:00N8VEM
LIBS:01RetroBrew
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
LIBS:SBC-188
LIBS:SBC-386EX-2-cache
EELAYER 25 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 4 11
Title "SBC-386EX-2"
Date "2018-01-19"
Rev "002"
Comp "RetroBrew Computer Group"
Comment1 "Licensed for hobbyist use only."
Comment2 "Copyright (C) 2017 John R Coffman.  All rights  reserved."
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L MAX233 U7
U 1 1 59DC3D2A
P 4100 2200
F 0 "U7" H 4100 2300 70  0000 C CNN
F 1 "MAX233" H 4100 2100 70  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 4100 2200 60  0001 C CNN
F 3 "" H 4100 2200 60  0000 C CNN
	1    4100 2200
	1    0    0    -1  
$EndComp
$Comp
L Conn_02x05_Odd_Even J2
U 1 1 59DC3D9B
P 7400 2700
F 0 "J2" H 7450 3000 50  0000 C CNN
F 1 "Conn_02x05_Odd_Even" H 7450 2400 50  0000 C CNN
F 2 "01N8VEM:SHROUDED_5x2" H 7400 2700 50  0001 C CNN
F 3 "" H 7400 2700 50  0001 C CNN
	1    7400 2700
	1    0    0    -1  
$EndComp
Text GLabel 2600 2600 0    60   Input ~ 0
T_TXD0
Text GLabel 3050 2700 0    60   Input ~ 0
~T_RTS0
Text GLabel 2600 2800 0    60   Output ~ 0
T_RXD0
Text GLabel 3050 2900 0    60   Output ~ 0
~T_CTS0
Wire Wire Line
	2600 2600 3300 2600
Wire Wire Line
	3050 2700 3300 2700
Wire Wire Line
	3300 2000 3300 2100
Wire Wire Line
	3300 1750 3300 1850
Wire Wire Line
	4900 1900 4900 2000
Wire Wire Line
	2600 2800 3300 2800
Wire Wire Line
	3050 2900 3300 2900
Wire Wire Line
	7200 2600 5750 2600
Wire Wire Line
	5750 2600 5750 2800
Wire Wire Line
	5750 2800 4900 2800
Text Label 6250 2600 0    60   ~ 0
R_RXD
Wire Wire Line
	7200 2700 5500 2700
Wire Wire Line
	5500 2700 5500 2600
Wire Wire Line
	5500 2600 4900 2600
Text Label 6250 2700 0    60   ~ 0
R_TXD
Text Label 6250 2500 0    60   ~ 0
~R_DCD
NoConn ~ 7200 2500
Wire Wire Line
	6250 2500 7200 2500
$Comp
L GND #PWR07
U 1 1 59DC4018
P 6500 3100
F 0 "#PWR07" H 6500 3100 30  0001 C CNN
F 1 "GND" H 6500 3030 30  0001 C CNN
F 2 "" H 6500 3100 60  0000 C CNN
F 3 "" H 6500 3100 60  0000 C CNN
	1    6500 3100
	1    0    0    -1  
$EndComp
Wire Wire Line
	6500 3100 6500 2900
Wire Wire Line
	6500 2900 7200 2900
Wire Wire Line
	7700 2600 8400 2600
Wire Wire Line
	8400 2600 8400 2200
Wire Wire Line
	8400 2200 5200 2200
Wire Wire Line
	5200 2200 5200 2700
Wire Wire Line
	5200 2700 4900 2700
Text Label 8150 2600 2    60   ~ 0
~R_RTS
Wire Wire Line
	7200 2800 6700 2800
Wire Wire Line
	6700 2800 6700 2200
Connection ~ 6700 2200
Text Label 7100 2800 2    60   ~ 0
~R_DTR
Wire Wire Line
	7700 2800 8200 2800
Text Label 8150 2800 2    60   ~ 0
~R_RI
NoConn ~ 7700 2800
$Comp
L Conn_01x03 J3
U 1 1 59DC41CE
P 9300 2600
F 0 "J3" H 9300 2800 50  0000 C CNN
F 1 "Conn_01x03" H 9300 2400 50  0000 C CNN
F 2 "pin_array:PIN_ARRAY_3X1" H 9300 2600 50  0001 C CNN
F 3 "" H 9300 2600 50  0001 C CNN
	1    9300 2600
	1    0    0    1   
$EndComp
Wire Wire Line
	7700 2500 9100 2500
Wire Wire Line
	7700 2700 9100 2700
Text Label 8150 2700 2    60   ~ 0
~R_CTS
Text Label 8150 2500 2    60   ~ 0
~R_DSR
Wire Wire Line
	9100 2600 8800 2600
Wire Wire Line
	8800 2600 8800 3500
Wire Wire Line
	8800 3500 5200 3500
Wire Wire Line
	5200 3500 5200 2900
Wire Wire Line
	5200 2900 4900 2900
Text Notes 1250 3750 0    90   ~ 0
Programming will always use RTS/CTS \nprotocol, despite J2 selection of the \nactual Terminal protocol
Text Notes 9050 3600 0    90   ~ 0
Terminal protocol selection:\n    1-2  RTS/CTS\n    2-3  DTR/DSR\nProgramming protocol is\nalways RTS/CTS
Text Notes 6300 1850 0    90   ~ 0
Connector looks like a Terminal, so it\nmust connect to a terminal console \nthrough a Null Modem.
$Comp
L VCC #PWR08
U 1 1 59DC481D
P 5200 1300
F 0 "#PWR08" H 5200 1400 30  0001 C CNN
F 1 "VCC" H 5200 1400 30  0000 C CNN
F 2 "" H 5200 1300 60  0000 C CNN
F 3 "" H 5200 1300 60  0000 C CNN
	1    5200 1300
	1    0    0    -1  
$EndComp
Wire Wire Line
	5200 1300 5200 1500
Wire Wire Line
	5200 1500 4900 1500
NoConn ~ 4900 1750
NoConn ~ 7700 2900
$EndSCHEMATC
