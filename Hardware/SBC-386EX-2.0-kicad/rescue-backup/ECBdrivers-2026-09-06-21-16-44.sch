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
Sheet 6 11
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
L 74LS245 U10
U 1 1 59F9024B
P 2200 1800
F 0 "U10" H 2150 2050 60  0000 L BNN
F 1 "74LS245" H 2300 1450 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 2200 1800 50  0001 C CNN
F 3 "" H 2200 1800 50  0000 C CNN
	1    2200 1800
	1    0    0    -1  
$EndComp
Text GLabel 1300 1300 0    50   BiDi ~ 0
D0
Wire Wire Line
	1300 1300 1500 1300
Text GLabel 3100 1300 2    50   BiDi ~ 0
B_D0
Wire Wire Line
	3100 1300 2900 1300
Text GLabel 1300 1400 0    50   BiDi ~ 0
D1
Wire Wire Line
	1300 1400 1500 1400
Text GLabel 1300 1500 0    50   BiDi ~ 0
D2
Wire Wire Line
	1300 1500 1500 1500
Text GLabel 1300 1600 0    50   BiDi ~ 0
D3
Wire Wire Line
	1300 1600 1500 1600
Text GLabel 1300 1700 0    50   BiDi ~ 0
D4
Wire Wire Line
	1300 1700 1500 1700
Text GLabel 1300 1800 0    50   BiDi ~ 0
D5
Wire Wire Line
	1300 1800 1500 1800
Text GLabel 1300 1900 0    50   BiDi ~ 0
D6
Wire Wire Line
	1300 1900 1500 1900
Text GLabel 1300 2000 0    50   BiDi ~ 0
D7
Wire Wire Line
	1300 2000 1500 2000
Text GLabel 3100 1400 2    50   BiDi ~ 0
B_D1
Wire Wire Line
	3100 1400 2900 1400
Text GLabel 3100 1500 2    50   BiDi ~ 0
B_D2
Wire Wire Line
	3100 1500 2900 1500
Text GLabel 3100 1600 2    50   BiDi ~ 0
B_D3
Wire Wire Line
	3100 1600 2900 1600
Text GLabel 3100 1700 2    50   BiDi ~ 0
B_D4
Wire Wire Line
	3100 1700 2900 1700
Text GLabel 3100 1800 2    50   BiDi ~ 0
B_D5
Wire Wire Line
	3100 1800 2900 1800
Text GLabel 3100 1900 2    50   BiDi ~ 0
B_D6
Wire Wire Line
	3100 1900 2900 1900
Text GLabel 3100 2000 2    50   BiDi ~ 0
B_D7
Wire Wire Line
	3100 2000 2900 2000
Text GLabel 1300 2200 0    50   Input ~ 0
DT_~R
Text GLabel 1300 2300 0    50   Input ~ 0
~DAT_EN
Wire Wire Line
	1300 2200 1500 2200
Wire Wire Line
	1300 2300 1500 2300
$Comp
L 74LS244 U11
U 1 1 59F90948
P 2200 3300
F 0 "U11" H 2250 3100 60  0000 C CNN
F 1 "74ALS244" H 2300 2900 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 2200 3300 60  0001 C CNN
F 3 "" H 2200 3300 60  0000 C CNN
	1    2200 3300
	1    0    0    -1  
$EndComp
Wire Wire Line
	3100 2800 2900 2800
Wire Wire Line
	3100 2900 2900 2900
Wire Wire Line
	3100 3000 2900 3000
Wire Wire Line
	3100 3100 2900 3100
Wire Wire Line
	3100 3200 2900 3200
Wire Wire Line
	3100 3300 2900 3300
Wire Wire Line
	3100 3400 2900 3400
Wire Wire Line
	3100 3500 2900 3500
Text GLabel 3100 2800 2    50   Output ~ 0
B_A0
Text GLabel 3100 2900 2    50   Output ~ 0
B_A1
Text GLabel 3100 3000 2    50   Output ~ 0
B_A2
Text GLabel 3100 3100 2    50   Output ~ 0
B_A3
Text GLabel 3100 3200 2    50   Output ~ 0
B_A4
Text GLabel 3100 3300 2    50   Output ~ 0
B_A5
Text GLabel 3100 3400 2    50   Output ~ 0
B_A6
Text GLabel 3100 3500 2    50   Output ~ 0
B_A7
Wire Wire Line
	1300 2800 1500 2800
Wire Wire Line
	1300 2900 1500 2900
Wire Wire Line
	1300 3000 1500 3000
Wire Wire Line
	1300 3100 1500 3100
Wire Wire Line
	1300 3200 1500 3200
Wire Wire Line
	1300 3300 1500 3300
Wire Wire Line
	1300 3400 1500 3400
Wire Wire Line
	1300 3500 1500 3500
Text GLabel 1300 2800 0    50   Input ~ 0
~BLE
Text GLabel 1300 2900 0    50   Input ~ 0
A1
Text GLabel 1300 3000 0    50   Input ~ 0
A2
Text GLabel 1300 3100 0    50   Input ~ 0
A3
Text GLabel 1300 3200 0    50   Input ~ 0
A4
Text GLabel 1300 3300 0    50   Input ~ 0
A5
Text GLabel 1300 3400 0    50   Input ~ 0
A6
Text GLabel 1300 3500 0    50   Input ~ 0
A7
$Comp
L 74LS244 U12
U 1 1 59F90B12
P 2200 4800
F 0 "U12" H 2250 4600 60  0000 C CNN
F 1 "74ALS244" H 2300 4400 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 2200 4800 60  0001 C CNN
F 3 "" H 2200 4800 60  0000 C CNN
	1    2200 4800
	1    0    0    -1  
$EndComp
Wire Wire Line
	3100 4300 2900 4300
Wire Wire Line
	3100 4400 2900 4400
Wire Wire Line
	3100 4500 2900 4500
Wire Wire Line
	3100 4600 2900 4600
Wire Wire Line
	3100 4700 2900 4700
Wire Wire Line
	3100 4800 2900 4800
Wire Wire Line
	3100 4900 2900 4900
Wire Wire Line
	3100 5000 2900 5000
Text GLabel 3100 4300 2    50   Output ~ 0
B_A8
Text GLabel 3100 4400 2    50   Output ~ 0
B_A9
Text GLabel 3100 4500 2    50   Output ~ 0
B_A10
Text GLabel 3100 4600 2    50   Output ~ 0
B_A11
Text GLabel 3100 4700 2    50   Output ~ 0
B_A12
Text GLabel 3100 4800 2    50   Output ~ 0
B_A13
Text GLabel 3100 4900 2    50   Output ~ 0
B_A14
Text GLabel 3100 5000 2    50   Output ~ 0
B_A15
Wire Wire Line
	1300 4300 1500 4300
Wire Wire Line
	1300 4400 1500 4400
Wire Wire Line
	1300 4500 1500 4500
Wire Wire Line
	1300 4600 1500 4600
Wire Wire Line
	1300 4700 1500 4700
Wire Wire Line
	1300 4800 1500 4800
Wire Wire Line
	1300 4900 1500 4900
Wire Wire Line
	1300 5000 1500 5000
Text GLabel 1300 4300 0    50   Input ~ 0
A8
Text GLabel 1300 4400 0    50   Input ~ 0
A9
Text GLabel 1300 4500 0    50   Input ~ 0
A10
Text GLabel 1300 4600 0    50   Input ~ 0
A11
Text GLabel 1300 4700 0    50   Input ~ 0
A12
Text GLabel 1300 4800 0    50   Input ~ 0
A13
Text GLabel 1300 4900 0    50   Input ~ 0
A14
Text GLabel 1300 5000 0    50   Input ~ 0
A15
$Comp
L 74LS244 U13
U 1 1 59F90B87
P 2200 6300
F 0 "U13" H 2250 6100 60  0000 C CNN
F 1 "74ALS244" H 2300 5900 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 2200 6300 60  0001 C CNN
F 3 "" H 2200 6300 60  0000 C CNN
	1    2200 6300
	1    0    0    -1  
$EndComp
Wire Wire Line
	3100 5800 2900 5800
Wire Wire Line
	3100 5900 2900 5900
Wire Wire Line
	3100 6000 2900 6000
Wire Wire Line
	3100 6100 2900 6100
Wire Wire Line
	6750 4550 6550 4550
Wire Wire Line
	6750 4650 6550 4650
Wire Wire Line
	3100 6200 2900 6200
Wire Wire Line
	3100 6300 2900 6300
Text GLabel 3100 5800 2    50   Output ~ 0
B_A16
Text GLabel 3100 5900 2    50   Output ~ 0
B_A17
Text GLabel 3100 6000 2    50   Output ~ 0
B_A18
Text GLabel 3100 6100 2    50   Output ~ 0
B_A19
Text GLabel 3100 6400 2    50   Output ~ 0
B_~MREQ
Text GLabel 6750 4650 2    50   Output ~ 0
B_~IORQ
Text GLabel 3100 6200 2    50   Output ~ 0
B_~M1
Text GLabel 3100 6300 2    50   Output ~ 0
B_DT_~R
Wire Wire Line
	1300 5800 1500 5800
Wire Wire Line
	1300 5900 1500 5900
Wire Wire Line
	1300 6000 1500 6000
Wire Wire Line
	1300 6100 1500 6100
Wire Wire Line
	4950 4550 5150 4550
Wire Wire Line
	4950 4650 5150 4650
Wire Wire Line
	1300 6200 1500 6200
Wire Wire Line
	1300 6300 1500 6300
Text GLabel 1300 5800 0    50   Input ~ 0
A16
Text GLabel 1300 5900 0    50   Input ~ 0
A17
Text GLabel 1300 6000 0    50   Input ~ 0
A18
Text GLabel 1300 6100 0    50   Input ~ 0
A19
Text GLabel 1300 6400 0    50   Input ~ 0
~CS_XMEM
Text GLabel 4950 4650 0    50   Input ~ 0
~CS_XIO
Text GLabel 1300 6200 0    50   Input ~ 0
D_~C
Text GLabel 1300 6300 0    50   Input ~ 0
DT_~R
$Comp
L GND #PWR014
U 1 1 59F90BB3
P 850 7400
F 0 "#PWR014" H 850 7400 30  0001 C CNN
F 1 "GND" H 850 7330 30  0001 C CNN
F 2 "" H 850 7400 60  0000 C CNN
F 3 "" H 850 7400 60  0000 C CNN
	1    850  7400
	1    0    0    -1  
$EndComp
Wire Wire Line
	1500 3700 850  3700
Wire Wire Line
	850  3700 850  7400
Wire Wire Line
	1500 3800 850  3800
Connection ~ 850  3800
Wire Wire Line
	1500 5200 850  5200
Connection ~ 850  5200
Wire Wire Line
	1500 5300 850  5300
Connection ~ 850  5300
Wire Wire Line
	1500 6700 850  6700
Connection ~ 850  6700
Wire Wire Line
	1500 6800 850  6800
Connection ~ 850  6800
Text GLabel 10050 1250 2    60   Input ~ 0
B_~NMI
$Comp
L 74LS14 U9
U 3 2 5A00F73B
P 9050 1250
F 0 "U9" H 9200 1350 40  0000 C CNN
F 1 "74HCT14" H 9250 1150 40  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 9050 1250 60  0001 C CNN
F 3 "" H 9050 1250 60  0001 C CNN
	3    9050 1250
	-1   0    0    -1  
$EndComp
Text GLabel 7850 1250 0    60   Output ~ 0
NMI
Wire Wire Line
	8600 1250 7850 1250
Wire Wire Line
	10050 1250 9500 1250
$Comp
L 74LS240 U14
U 1 1 5A0113B3
P 9000 2250
F 0 "U14" H 9050 2050 50  0000 C CNN
F 1 "74LS240" H 9100 1850 50  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 9000 2250 50  0001 C CNN
F 3 "" H 9000 2250 50  0001 C CNN
	1    9000 2250
	-1   0    0    -1  
$EndComp
Text GLabel 10050 1750 2    60   Input ~ 0
B_~IR1
Text GLabel 7850 1750 0    60   Output ~ 0
IR1
Wire Wire Line
	8300 1750 7850 1750
Text GLabel 10050 1550 2    60   Input ~ 0
B_~INT
Wire Wire Line
	9700 1750 10050 1750
Wire Wire Line
	10050 1550 9800 1550
Text GLabel 10050 1850 2    60   Input ~ 0
B_~IR2
Wire Wire Line
	10050 1850 9700 1850
Text GLabel 10050 2050 2    60   Input ~ 0
B_~IR5
Wire Wire Line
	10050 1950 9700 1950
Text GLabel 10050 2150 2    60   Input ~ 0
B_~IR6
Wire Wire Line
	9700 2050 10050 2050
Text GLabel 10050 2250 2    60   Input ~ 0
B_~IR7
Wire Wire Line
	10050 2150 9700 2150
Text GLabel 7850 1850 0    60   Output ~ 0
IR9
Wire Wire Line
	8300 1850 7850 1850
Text GLabel 7850 2050 0    60   Output ~ 0
IR5
Wire Wire Line
	8300 1950 7850 1950
Text GLabel 7850 2150 0    60   Output ~ 0
IR6
Wire Wire Line
	8300 2050 7850 2050
Text GLabel 7850 2250 0    60   Output ~ 0
IR7
Wire Wire Line
	8300 2150 7850 2150
$Comp
L GND #PWR015
U 1 1 5A01172F
P 9850 2950
F 0 "#PWR015" H 9850 2950 30  0001 C CNN
F 1 "GND" H 9850 2880 30  0001 C CNN
F 2 "" H 9850 2950 60  0001 C CNN
F 3 "" H 9850 2950 60  0001 C CNN
	1    9850 2950
	1    0    0    -1  
$EndComp
Wire Wire Line
	9700 2650 9850 2650
Wire Wire Line
	9850 2650 9850 2950
Wire Wire Line
	9700 2750 9850 2750
Connection ~ 9850 2750
Text Notes 8450 1000 0    60   ~ 0
NMI must be driven to +4.8v
Text GLabel 7850 2450 0    60   Output ~ 0
B_~HALT
Wire Wire Line
	7850 2450 8300 2450
Wire Wire Line
	9700 2350 10150 2350
Wire Wire Line
	10150 2350 10150 3250
Wire Wire Line
	10150 3250 8100 3250
Wire Wire Line
	8100 3250 8100 2450
Connection ~ 8100 2450
Text GLabel 10400 2450 2    60   Input ~ 0
HALT
Wire Wire Line
	9700 2450 10400 2450
Text GLabel 7350 2350 0    60   Output ~ 0
B_HALT
Wire Wire Line
	8300 2350 7350 2350
Text GLabel 4750 5550 0    50   Input ~ 0
~LBA
Wire Wire Line
	4750 5550 5150 5550
Text GLabel 4850 5250 0    50   Input ~ 0
~READYO
Wire Wire Line
	4850 5250 5150 5250
Text GLabel 6950 5250 2    50   BiDi ~ 0
~READY
Wire Wire Line
	6950 5250 6550 5250
Text Notes 4000 5150 0    70   ~ 0
FPU output
Wire Wire Line
	4950 4750 5150 4750
Wire Wire Line
	4950 4850 5150 4850
Text GLabel 4950 4750 0    50   Input ~ 0
~RD
Text GLabel 4950 4850 0    50   Input ~ 0
~WR
Wire Wire Line
	6750 4750 6550 4750
Wire Wire Line
	6750 4850 6550 4850
Text GLabel 6750 4750 2    50   Output ~ 0
B_~RD
Text GLabel 6750 4850 2    50   Output ~ 0
B_~WR
$Comp
L GND #PWR016
U 1 1 5A03A085
P 5050 5750
F 0 "#PWR016" H 5050 5750 30  0001 C CNN
F 1 "GND" H 5050 5680 30  0001 C CNN
F 2 "" H 5050 5750 60  0000 C CNN
F 3 "" H 5050 5750 60  0000 C CNN
	1    5050 5750
	1    0    0    -1  
$EndComp
Wire Wire Line
	5050 5450 5050 5750
Wire Wire Line
	5150 5450 5050 5450
Text GLabel 10050 3600 2    60   Input ~ 0
B_~DREQ
Wire Wire Line
	10050 2250 9700 2250
Text GLabel 7850 3600 0    60   Output ~ 0
DREQ0
Wire Wire Line
	7850 2250 8300 2250
Wire Wire Line
	1300 6400 1500 6400
$Comp
L 74LS14 U9
U 5 2 5A038498
P 9050 3600
F 0 "U9" H 9200 3700 40  0000 C CNN
F 1 "74HCT14" H 9250 3500 40  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 9050 3600 60  0001 C CNN
F 3 "" H 9050 3600 60  0001 C CNN
	5    9050 3600
	-1   0    0    -1  
$EndComp
Wire Wire Line
	8600 3600 7850 3600
Wire Wire Line
	10050 3600 9500 3600
Text GLabel 10050 1950 2    60   Input ~ 0
B_~IR3
Text GLabel 7850 1950 0    60   Output ~ 0
IR13
$Comp
L 74LS241 U3
U 1 1 5A2D9E5C
P 5850 5050
F 0 "U3" H 5900 4850 60  0000 C CNN
F 1 "74LS241" H 5950 4650 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 5850 5050 60  0001 C CNN
F 3 "" H 5850 5050 60  0000 C CNN
	1    5850 5050
	1    0    0    -1  
$EndComp
NoConn ~ 6550 5150
NoConn ~ 6550 5050
NoConn ~ 5150 5150
NoConn ~ 5150 5050
Text Notes 6200 2000 0    70   ~ 0
IR9  redirects to IR2\nIR13 redirects to IR3\n
Text GLabel 4950 4550 0    50   Input ~ 0
~RESET
Wire Wire Line
	3100 6400 2900 6400
Text GLabel 6750 4550 2    50   Output ~ 0
B_~RESOUT
NoConn ~ 6550 4950
NoConn ~ 5150 4950
Wire Wire Line
	9800 1550 9800 1750
Connection ~ 9800 1750
Text GLabel 3100 6500 2    50   Output ~ 0
B_~CLK
Wire Wire Line
	3100 6500 2900 6500
$Comp
L 74HC14 U9
U 4 1 5A5EBE15
P 2500 7250
F 0 "U9" H 2650 7350 50  0000 C CNN
F 1 "74HCT14" H 2700 7150 50  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 2500 7250 50  0001 C CNN
F 3 "" H 2500 7250 50  0000 C CNN
	4    2500 7250
	-1   0    0    -1  
$EndComp
Text GLabel 3250 7250 2    50   Input ~ 0
CLKOUT
Wire Wire Line
	3250 7250 2950 7250
Wire Wire Line
	2050 7250 1350 7250
Wire Wire Line
	1350 7250 1350 6500
Wire Wire Line
	1350 6500 1500 6500
$EndSCHEMATC
