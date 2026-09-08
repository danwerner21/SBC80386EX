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
Sheet 8 11
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
L OSC14-8 U16
U 1 1 5A013D9B
P 2050 2900
F 0 "U16" H 2050 3000 60  0000 C CNN
F 1 "CPU-66mhz" H 2050 2850 60  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 2050 2900 60  0001 C CNN
F 3 "" H 2050 2900 60  0000 C CNN
	1    2050 2900
	1    0    0    -1  
$EndComp
Text GLabel 3750 3050 2    60   Output ~ 0
CLK2
Text Notes 4800 3100 2    60   ~ 0
to CPU & FPU
$Comp
L OSC14-8 U17
U 1 1 5A014188
P 2050 4150
F 0 "U17" H 2050 4250 60  0000 C CNN
F 1 "CLK-1.8432" H 2050 4100 60  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 2050 4150 60  0001 C CNN
F 3 "" H 2050 4150 60  0000 C CNN
	1    2050 4150
	1    0    0    -1  
$EndComp
Wire Wire Line
	2950 3050 3750 3050
Wire Wire Line
	2950 3050 2950 2750
Wire Wire Line
	2950 4300 2950 4000
Wire Wire Line
	2950 4000 7100 4000
Wire Wire Line
	5950 4000 5950 2250
Text GLabel 7100 4000 2    60   Output ~ 0
COMCLK
Connection ~ 5950 4000
Text Notes 8800 4050 2    60   ~ 0
1.8432mhz to Serial I/O
$Comp
L 74LS74 U15
U 1 1 5A02F5D9
P 6550 2250
F 0 "U15" H 6600 2250 50  0000 C CNN
F 1 "74LS74" H 6850 1900 50  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 6550 2250 50  0001 C CNN
F 3 "" H 6550 2250 50  0001 C CNN
	1    6550 2250
	1    0    0    -1  
$EndComp
Text GLabel 7700 2050 2    60   Output ~ 0
TMRCLK0
$Comp
L VCC #PWR025
U 1 1 5A02F6EC
P 6550 1550
F 0 "#PWR025" H 6550 1650 30  0001 C CNN
F 1 "VCC" H 6550 1650 30  0000 C CNN
F 2 "" H 6550 1550 60  0000 C CNN
F 3 "" H 6550 1550 60  0000 C CNN
	1    6550 1550
	1    0    0    -1  
$EndComp
Wire Wire Line
	6550 1550 6550 1700
Wire Wire Line
	6550 1600 7350 1600
Wire Wire Line
	7350 1600 7350 2900
Wire Wire Line
	7350 2900 6550 2900
Wire Wire Line
	6550 2900 6550 2800
Connection ~ 6550 1600
Wire Wire Line
	5950 2050 5950 1800
Wire Wire Line
	5950 1800 7250 1800
Wire Wire Line
	7250 1800 7250 2450
Wire Wire Line
	7250 2450 7150 2450
Wire Wire Line
	7150 2050 7700 2050
$EndSCHEMATC
