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
Sheet 2 11
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
L VCC #PWR03
U 1 1 59A59AA6
P 2500 700
F 0 "#PWR03" H 2500 800 30  0001 C CNN
F 1 "VCC" H 2500 800 30  0000 C CNN
F 2 "" H 2500 700 60  0000 C CNN
F 3 "" H 2500 700 60  0000 C CNN
	1    2500 700 
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR04
U 1 1 59A5A1AB
P 2500 7650
F 0 "#PWR04" H 2500 7650 30  0001 C CNN
F 1 "GND" H 2500 7580 30  0001 C CNN
F 2 "" H 2500 7650 60  0000 C CNN
F 3 "" H 2500 7650 60  0000 C CNN
	1    2500 7650
	1    0    0    -1  
$EndComp
Text Notes 2850 4350 0    80   ~ 0
80386EX
Text GLabel 1800 1450 0    50   Output ~ 0
A1
Text GLabel 1800 1550 0    50   Output ~ 0
A2
Text GLabel 1800 1650 0    50   Output ~ 0
A3
Text GLabel 1800 1750 0    50   Output ~ 0
A4
Text GLabel 1800 1850 0    50   Output ~ 0
A5
Text GLabel 1800 1950 0    50   Output ~ 0
A6
Text GLabel 1800 2050 0    50   Output ~ 0
A7
Text GLabel 1800 2150 0    50   Output ~ 0
A8
Text GLabel 1800 2250 0    50   Output ~ 0
A9
Text GLabel 1800 2350 0    50   Output ~ 0
A10
Text GLabel 1800 2450 0    50   Output ~ 0
A11
Text GLabel 1800 2550 0    50   Output ~ 0
A12
Text GLabel 1800 2650 0    50   Output ~ 0
A13
Text GLabel 1800 2750 0    50   Output ~ 0
A14
Text GLabel 1800 2850 0    50   Output ~ 0
A15
Text GLabel 1800 2950 0    50   Output ~ 0
A16
Text GLabel 1800 3050 0    50   Output ~ 0
A17
Text GLabel 1800 3150 0    50   Output ~ 0
A18
Text GLabel 1800 3250 0    50   Output ~ 0
A19
Text GLabel 1800 3350 0    50   Output ~ 0
A20
Text GLabel 1800 3450 0    50   Output ~ 0
A21
Text GLabel 1800 3550 0    50   Output ~ 0
A22
Text GLabel 1800 3650 0    50   Output ~ 0
A23
Text GLabel 1800 3750 0    50   Output ~ 0
A24
Text GLabel 1800 3850 0    50   Output ~ 0
A25
Text GLabel 1750 4000 0    50   Output ~ 0
CLKOUT
Text GLabel 1800 4150 0    50   BiDi ~ 0
D0
Text GLabel 1800 4250 0    50   BiDi ~ 0
D1
Text GLabel 1800 4350 0    50   BiDi ~ 0
D2
Text GLabel 1800 4450 0    50   BiDi ~ 0
D3
Text GLabel 1800 4550 0    50   BiDi ~ 0
D4
Text GLabel 1800 4650 0    50   BiDi ~ 0
D5
Text GLabel 1800 4750 0    50   BiDi ~ 0
D6
Text GLabel 1800 4850 0    50   BiDi ~ 0
D7
Text GLabel 1800 4950 0    50   BiDi ~ 0
D8
Text GLabel 1800 5050 0    50   BiDi ~ 0
D9
Text GLabel 1800 5150 0    50   BiDi ~ 0
D10
Text GLabel 1800 5250 0    50   BiDi ~ 0
D11
Text GLabel 1800 5350 0    50   BiDi ~ 0
D12
Text GLabel 1800 5450 0    50   BiDi ~ 0
D13
Text GLabel 1800 5550 0    50   BiDi ~ 0
D14
Text GLabel 1800 5650 0    50   BiDi ~ 0
D15
Text GLabel 1800 1050 0    50   Input ~ 0
~CS_ROM
Text GLabel 1800 1150 0    50   Output ~ 0
~ADS
Text GLabel 1800 1250 0    50   Output ~ 0
~BHE
Text GLabel 1800 1350 0    50   Output ~ 0
~BLE
Text GLabel 4400 6250 2    50   Output ~ 0
~REFRESH
Text GLabel 4400 6350 2    50   Output ~ 0
~CS_ROM
Text GLabel 4400 6050 2    50   Input ~ 0
NMI
Text GLabel 4400 5550 2    50   Input ~ 0
TMRCLK0
Text GLabel 4400 7050 2    50   Output ~ 0
~RD
Text GLabel 4400 7150 2    50   Output ~ 0
~WR
Text GLabel 4400 7250 2    50   Output ~ 0
DT_~R
Text GLabel 4400 6850 2    50   Output ~ 0
D_~C
Text GLabel 4400 4450 2    50   BiDi ~ 0
~EOP
Text GLabel 4400 3850 2    50   Input ~ 0
DREQ0
Text GLabel 4400 3950 2    50   Input ~ 0
DREQ1
Text GLabel 4400 4250 2    50   Output ~ 0
~DACK1
Text GLabel 5350 4850 2    50   Output ~ 0
SD-CXS
Text GLabel 4400 4650 2    50   Input ~ 0
SD-RXS
Text GLabel 4400 4750 2    50   Output ~ 0
SD-TXS
Text GLabel 4400 1150 2    50   Output ~ 0
~T_RTS0
Text GLabel 4400 2550 2    50   Output ~ 0
T_TXD0
Text GLabel 4400 2650 2    50   Input ~ 0
~T_CTS0
Text GLabel 4400 2450 2    50   Input ~ 0
T_RXD0
Text GLabel 4900 3450 2    50   Output ~ 0
~SD-CS
Text GLabel 4850 2850 2    50   Input ~ 0
PEREQ
Text GLabel 4400 1950 2    50   Output ~ 0
~CS_XIO
Text GLabel 4400 2050 2    50   Output ~ 0
~CS_LIO
Text GLabel 4400 2150 2    50   Output ~ 0
~CS_DRAM
Text GLabel 4400 2250 2    50   Output ~ 0
~CS_XMEM
Text GLabel 4400 2350 2    50   Output ~ 0
~CS_SRAM
Text GLabel 4400 1050 2    50   BiDi ~ 0
RTC_DQ
Text GLabel 4400 1250 2    50   BiDi ~ 0
RTC_CLK
Text GLabel 4400 1350 2    50   BiDi ~ 0
RTC_~RESET
Text GLabel 4400 3550 2    50   Input ~ 0
COMCLK
Text GLabel 4400 3050 2    50   Input ~ 0
IR1
Text GLabel 4400 3150 2    50   Input ~ 0
IR5
Text GLabel 4400 3250 2    50   Input ~ 0
IR6
Text GLabel 4400 3350 2    50   Input ~ 0
IR7
Text GLabel 4400 5650 2    50   Input ~ 0
IR9
Text Notes 6850 5700 2    50   ~ 0
IR9 redirected to IR2; or configured as SSIOINT (SDcard)
Text GLabel 4400 5850 2    50   Input ~ 0
IDE-IR14
Text GLabel 4400 5750 2    50   Input ~ 0
IR13
Text GLabel 4400 5250 2    50   BiDi ~ 0
PEREQ
Text GLabel 4400 5450 2    50   Input ~ 0
~BUSY
Text GLabel 4400 5350 2    50   Input ~ 0
~ERROR
NoConn ~ 4400 5050
Text Notes 5150 6750 0    50   ~ 0
All selects, M & I/O, \nprogram their own READY
Text Notes 1400 950  2    50   ~ 0
ROM is 8-bit
Text GLabel 1000 5950 0    50   Input ~ 0
CLK2
Text GLabel 1450 5850 0    50   Input ~ 0
RESET
Text GLabel 4400 6650 2    50   BiDi ~ 0
~READY
$Comp
L i387SX U2
U 1 1 59FB9394
P 9150 3550
F 0 "U2" H 9150 3550 60  0000 C CNN
F 1 "i387SX" H 9150 3350 60  0000 C CNN
F 2 "Kicad:80188" H 9150 3550 60  0001 C CNN
F 3 "" H 9150 3550 60  0001 C CNN
	1    9150 3550
	1    0    0    -1  
$EndComp
Text GLabel 7600 2850 0    50   Input ~ 0
CLK2
Text GLabel 10600 4450 2    50   Input ~ 0
RESET
Text GLabel 10250 2650 2    50   BiDi ~ 0
D0
Text GLabel 10250 2750 2    50   BiDi ~ 0
D1
Text GLabel 10250 2850 2    50   BiDi ~ 0
D2
Text GLabel 10250 2950 2    50   BiDi ~ 0
D3
Text GLabel 10250 3050 2    50   BiDi ~ 0
D4
Text GLabel 10250 3150 2    50   BiDi ~ 0
D5
Text GLabel 10250 3250 2    50   BiDi ~ 0
D6
Text GLabel 10250 3350 2    50   BiDi ~ 0
D7
Text GLabel 10250 3450 2    50   BiDi ~ 0
D8
Text GLabel 10250 3550 2    50   BiDi ~ 0
D9
Text GLabel 10250 3650 2    50   BiDi ~ 0
D10
Text GLabel 10250 3750 2    50   BiDi ~ 0
D11
Text GLabel 10250 3850 2    50   BiDi ~ 0
D12
Text GLabel 10250 3950 2    50   BiDi ~ 0
D13
Text GLabel 10250 4050 2    50   BiDi ~ 0
D14
Text GLabel 10250 4150 2    50   BiDi ~ 0
D15
Text GLabel 7600 3950 0    50   BiDi ~ 0
~READY
Text GLabel 7600 3250 0    50   Input ~ 0
~ADS
Text GLabel 4400 6750 2    50   Output ~ 0
M_~IO
Text GLabel 7600 3450 0    50   Input ~ 0
M_~IO
Text GLabel 7600 3750 0    50   Input ~ 0
DT_~R
Text GLabel 7600 3550 0    50   Input ~ 0
A23
Text GLabel 7600 3350 0    50   Input ~ 0
A2
Text GLabel 7600 4450 0    50   Output ~ 0
~ERROR
Text GLabel 7600 4550 0    50   Output ~ 0
~BUSY
Text GLabel 7600 4350 0    50   Output ~ 0
PEREQ
Text GLabel 6900 2750 0    50   Input ~ 0
FPU_PU
Text Notes 7650 2750 0    60   ~ 0
pull-up
$Comp
L GND #PWR05
U 1 1 59FBB7ED
P 7950 3050
F 0 "#PWR05" H 7950 3050 30  0001 C CNN
F 1 "GND" H 7950 2980 30  0001 C CNN
F 2 "" H 7950 3050 60  0000 C CNN
F 3 "" H 7950 3050 60  0000 C CNN
	1    7950 3050
	1    0    0    -1  
$EndComp
Text Notes 7650 3650 0    60   ~ 0
pull-up
Text GLabel 4400 1450 2    50   Output ~ 0
~LITE_0
Text GLabel 4400 1750 2    50   Output ~ 0
~LITE_3
Text GLabel 4400 1650 2    50   Output ~ 0
~LITE_2
Text GLabel 4400 1550 2    50   Output ~ 0
~LITE_1
Text GLabel 4400 6550 2    50   Output ~ 0
~LBA
Wire Wire Line
	2500 700  2500 750 
Wire Wire Line
	2500 7650 2500 7550
Wire Wire Line
	2500 750  3800 750 
Connection ~ 2600 750 
Connection ~ 2700 750 
Connection ~ 2800 750 
Connection ~ 2900 750 
Connection ~ 3000 750 
Connection ~ 3100 750 
Connection ~ 3200 750 
Connection ~ 3300 750 
Connection ~ 3400 750 
Connection ~ 3500 750 
Connection ~ 2500 7550
Connection ~ 2600 7550
Connection ~ 2700 7550
Connection ~ 2800 7550
Connection ~ 2900 7550
Connection ~ 3000 7550
Connection ~ 3100 7550
Connection ~ 3200 7550
Connection ~ 3300 7550
Connection ~ 3400 7550
Connection ~ 3500 7550
Wire Wire Line
	2500 7550 3800 7550
Wire Wire Line
	1800 5950 1000 5950
Wire Wire Line
	1800 5850 1450 5850
Connection ~ 3600 750 
Connection ~ 3700 750 
Connection ~ 3600 7550
Connection ~ 3700 7550
Wire Wire Line
	8100 2850 7600 2850
Wire Wire Line
	10250 4450 10600 4450
Wire Wire Line
	7600 3950 8100 3950
Wire Wire Line
	7600 3250 8100 3250
Wire Wire Line
	7600 3450 8100 3450
Wire Wire Line
	7600 3750 8100 3750
Wire Wire Line
	7600 3550 8100 3550
Wire Wire Line
	7600 3350 8100 3350
Wire Wire Line
	8100 4450 7600 4450
Wire Wire Line
	7600 4550 8100 4550
Wire Wire Line
	8100 4350 7600 4350
Connection ~ 3800 750 
Connection ~ 3800 7550
Wire Wire Line
	6900 2750 8100 2750
Wire Wire Line
	8100 3000 7950 3000
Wire Wire Line
	7950 3000 7950 3050
Wire Wire Line
	8100 3650 7100 3650
Wire Wire Line
	8100 4050 7600 4050
NoConn ~ 1800 6850
NoConn ~ 1800 6450
NoConn ~ 1800 6350
NoConn ~ 1800 6250
NoConn ~ 1800 6150
Text GLabel 1400 6550 0    60   Input ~ 0
~RESET_0
Wire Wire Line
	1400 7050 1800 7050
Wire Wire Line
	1800 6550 1400 6550
Wire Wire Line
	1300 7250 1800 7250
Wire Wire Line
	1400 6750 1800 6750
Text GLabel 1300 7250 0    50   Input ~ 0
CPU_PU
Wire Wire Line
	1400 6750 1400 7250
Connection ~ 1400 7250
Connection ~ 1400 7050
$Comp
L I386EX_passive U1
U 1 1 5A034309
P 3100 4150
F 0 "U1" H 3000 4500 70  0000 L CNN
F 1 "I386EX_passive" H 2750 4300 70  0000 L CNN
F 2 "Kicad:i386EX-132-adapter" H 3100 4150 50  0001 C CNN
F 3 "" H 3100 4150 50  0001 C CNN
	1    3100 4150
	1    0    0    -1  
$EndComp
Connection ~ 2500 750 
Text Notes 2850 4200 0    80   ~ 0
ADAPTER
Wire Wire Line
	7100 3650 7100 2750
Connection ~ 7100 2750
Text GLabel 7600 4050 0    50   Output ~ 0
~READYO
Text Notes 5950 4100 0    70   ~ 0
Ready drive for FPU is\non ECBdrivers.sch
Wire Wire Line
	4400 2850 4850 2850
Text Notes 5250 3000 0    60   ~ 0
*   rev.  2017-12-10\n    PEREQ detect moved from P1.0
Text GLabel 4400 2950 2    50   Input ~ 0
~SD-CD
Text Notes 6050 6250 0    70   ~ 0
DMAINT can be IR12 or IR13\nIDE-INT best on IR14\nFDC-INT may be IR6 (ECB bus)
Wire Wire Line
	4400 3450 4900 3450
Wire Wire Line
	4400 4850 5350 4850
Wire Wire Line
	4400 4550 5050 4550
Wire Wire Line
	5050 4550 5050 4850
Connection ~ 5050 4850
Text Notes 5000 1250 0    60   ~ 0
*  RTC moved from P3.1,2,6
Text Notes 5300 3500 0    60   ~ 0
open collector\nweak pull-down at Reset
NoConn ~ 4400 4150
Text Notes 4700 4150 2    60   ~ 12
~CS5
$Comp
L I386EX_PQFP U101
U 1 1 5A6221B5
P 3100 4150
F 0 "U101" H 3000 4500 50  0000 L CNN
F 1 "I386EX_PQFP" H 2850 4300 50  0000 L CNN
F 2 "Kicad:PQFP-132_i386_JRC" H 3100 4150 50  0001 C CNN
F 3 "" H 3100 4150 50  0001 C CNN
	1    3100 4150
	1    0    0    -1  
$EndComp
$EndSCHEMATC
