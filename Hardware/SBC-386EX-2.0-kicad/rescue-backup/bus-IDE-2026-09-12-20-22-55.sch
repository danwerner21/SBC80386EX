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
Sheet 11 11
Title "SBC-386EX-2"
Date "2018-01-19"
Rev "002"
Comp "RetroBrew Computer Group"
Comment1 "Licensed for hobbyist use only."
Comment2 "Copyright (C) 2017 John R Coffman.  All rights  reserved."
Comment3 ""
Comment4 ""
$EndDescr
Text Notes 4750 1250 0    60   ~ 0
IDE connector supports 8-bit data transfers only\nThis is good for CF cards, but not most Hard Disk drives
Text Label 5550 3100 2    60   ~ 0
INTRQ
Text Label 5550 3000 2    60   ~ 0
/IDMACK
Text Label 5550 2900 2    60   ~ 0
IORDY
Text Label 5200 1600 0    60   ~ 0
/RESET
Wire Wire Line
	4500 2800 5550 2800
Wire Wire Line
	5550 4250 5550 3500
Wire Wire Line
	1500 4850 1500 2500
Connection ~ 7350 2900
Wire Wire Line
	7350 2900 6050 2900
Wire Wire Line
	5550 1600 4950 1600
Connection ~ 7350 3500
Wire Wire Line
	7350 3500 6050 3500
Connection ~ 7350 2700
Wire Wire Line
	7350 2700 6050 2700
Wire Wire Line
	7350 1600 7350 5050
Wire Wire Line
	7350 1600 6050 1600
Wire Wire Line
	9350 3150 9350 3300
Wire Wire Line
	6050 2600 7350 2600
Connection ~ 7350 2600
Wire Wire Line
	7350 2800 6050 2800
Connection ~ 7350 2800
Wire Wire Line
	1500 4850 7350 4850
Connection ~ 7350 4850
Wire Wire Line
	1500 2500 5550 2500
Wire Wire Line
	7350 3000 6050 3000
Connection ~ 7350 3000
Wire Wire Line
	6050 2500 9150 2500
Wire Wire Line
	9150 2500 9150 3300
Wire Wire Line
	5550 1700 5150 1700
Wire Wire Line
	5550 1800 5150 1800
Wire Wire Line
	5550 2000 5150 2000
Wire Wire Line
	5550 1900 5150 1900
Wire Wire Line
	5550 2300 5150 2300
Wire Wire Line
	5550 2400 5150 2400
Wire Wire Line
	5550 2200 5150 2200
Wire Wire Line
	5550 2100 5150 2100
Wire Wire Line
	5050 2700 5550 2700
$Comp
L CONN_2 P4
U 1 1 5269566D
P 9250 3650
F 0 "P4" V 9200 3650 50  0000 C CNN
F 1 "CONN_2" V 9300 3650 40  0000 C CNN
F 2 "pin_array:PIN_ARRAY_2X1" H 9250 3650 60  0001 C CNN
F 3 "" H 9250 3650 60  0001 C CNN
	1    9250 3650
	0    1    1    0   
$EndComp
Text Label 5550 2700 2    60   ~ 0
/IWR
Text Label 5550 2800 2    60   ~ 0
/IRD
Text GLabel 4500 2800 0    60   Input ~ 0
~IDE-RD
Text GLabel 5050 2700 0    60   Input ~ 0
~IDE-WR
Text GLabel 5550 3400 0    60   Input ~ 0
~CS-IDE0
Text GLabel 6050 3400 2    60   Input ~ 0
~CS-IDE1
Text GLabel 5150 2100 0    60   BiDi ~ 0
D3
Text GLabel 5150 2200 0    60   BiDi ~ 0
D2
Text GLabel 5150 2400 0    60   BiDi ~ 0
D0
Text GLabel 5150 2300 0    60   BiDi ~ 0
D1
Text GLabel 5150 1900 0    60   BiDi ~ 0
D5
Text GLabel 5150 2000 0    60   BiDi ~ 0
D4
Text GLabel 5150 1800 0    60   BiDi ~ 0
D6
Text GLabel 5150 1700 0    60   BiDi ~ 0
D7
Text GLabel 6050 3300 2    60   Input ~ 0
A2
Text GLabel 5550 3300 0    60   Input ~ 0
~BLE
Text GLabel 5550 3200 0    60   Input ~ 0
A1
Text Label 5550 4100 1    60   ~ 0
/IACTIVE
Text Label 6050 3200 0    60   ~ 0
PDIAG
NoConn ~ 6050 3200
NoConn ~ 6050 3100
Text Label 6050 3100 0    60   ~ 0
IOCS16
Text Label 6050 2900 0    60   ~ 0
/CABLE_SELECT
Text Label 6050 2500 0    60   ~ 0
IDE-PIN20
NoConn ~ 5550 2900
Text Label 5550 2600 2    60   ~ 0
IDREQ
$Comp
L GND #PWR035
U 1 1 5261D50A
P 7350 5050
F 0 "#PWR035" H 7350 5050 30  0001 C CNN
F 1 "GND" H 7350 4980 30  0001 C CNN
F 2 "" H 7350 5050 60  0001 C CNN
F 3 "" H 7350 5050 60  0001 C CNN
	1    7350 5050
	1    0    0    -1  
$EndComp
Text Label 6050 2400 0    60   ~ 0
ID15
Text Label 6050 2300 0    60   ~ 0
ID14
Text Label 6050 2200 0    60   ~ 0
ID13
Text Label 6050 2100 0    60   ~ 0
ID12
Text Label 6050 2000 0    60   ~ 0
ID11
Text Label 6050 1900 0    60   ~ 0
ID10
Text Label 6050 1800 0    60   ~ 0
ID9
Text Label 6050 1700 0    60   ~ 0
ID8
Text Label 5550 1700 2    60   ~ 0
ID7
Text Label 5550 1800 2    60   ~ 0
ID6
Text Label 5550 1900 2    60   ~ 0
ID5
Text Label 5550 2000 2    60   ~ 0
ID4
Text Label 5550 2100 2    60   ~ 0
ID3
Text Label 5550 2200 2    60   ~ 0
ID2
Text Label 5550 2300 2    60   ~ 0
ID1
Text Label 5550 2400 2    60   ~ 0
ID0
$Comp
L VCC #PWR036
U 1 1 5261C849
P 9350 3150
F 0 "#PWR036" H 9350 3250 30  0001 C CNN
F 1 "VCC" H 9350 3250 30  0000 C CNN
F 2 "" H 9350 3150 60  0001 C CNN
F 3 "" H 9350 3150 60  0001 C CNN
	1    9350 3150
	1    0    0    -1  
$EndComp
Text Label 9150 3200 1    60   ~ 0
IDE-PIN20
$Comp
L Conn_02x20_Odd_Even P3
U 1 1 5A5BD462
P 5750 2500
F 0 "P3" H 5800 3550 60  0000 C CNN
F 1 "Conn_02x20_Odd_Even" H 5800 1400 50  0000 C CNN
F 2 "Kicad:SHROUDED_20X2" H 5750 2500 50  0001 C CNN
F 3 "" H 5750 2500 50  0001 C CNN
	1    5750 2500
	1    0    0    -1  
$EndComp
Wire Wire Line
	6050 1700 6450 1700
Wire Wire Line
	6050 1800 6450 1800
Wire Wire Line
	6050 2000 6450 2000
Wire Wire Line
	6050 1900 6450 1900
Wire Wire Line
	6050 2300 6450 2300
Wire Wire Line
	6050 2400 6450 2400
Wire Wire Line
	6050 2200 6450 2200
Wire Wire Line
	6050 2100 6450 2100
Text GLabel 6450 2100 2    60   BiDi ~ 0
D12
Text GLabel 6450 2200 2    60   BiDi ~ 0
D13
Text GLabel 6450 2400 2    60   BiDi ~ 0
D15
Text GLabel 6450 2300 2    60   BiDi ~ 0
D14
Text GLabel 6450 1900 2    60   BiDi ~ 0
D10
Text GLabel 6450 2000 2    60   BiDi ~ 0
D11
Text GLabel 6450 1800 2    60   BiDi ~ 0
D9
Text GLabel 6450 1700 2    60   BiDi ~ 0
D8
Text GLabel 4950 1600 0    60   Input ~ 0
~RESET
Text GLabel 4500 2600 0    60   Output ~ 0
DREQ1
Wire Wire Line
	4500 2600 5550 2600
Wire Wire Line
	5550 3000 5050 3000
Text GLabel 5050 3000 0    60   Input ~ 0
~DACK1
Text GLabel 4500 3100 0    60   Output ~ 0
IDE-IR14
Wire Wire Line
	4500 3100 5550 3100
NoConn ~ 5550 4250
$EndSCHEMATC
