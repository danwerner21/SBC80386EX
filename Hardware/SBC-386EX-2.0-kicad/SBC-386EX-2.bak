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
Sheet 1 11
Title "SBC-386EX-2"
Date "2018-01-19"
Rev "002"
Comp "RetroBrew Computer Group"
Comment1 "Licensed for hobbyist use only."
Comment2 "Copyright (C) 2017 John R Coffman.  All rights  reserved."
Comment3 ""
Comment4 ""
$EndDescr
$Sheet
S 1250 1000 1350 950 
U 5A0289C8
F0 "CPU386EX" 80
F1 "CPU386EX.sch" 80
$EndSheet
$Sheet
S 3050 1000 1350 950 
U 5A02949D
F0 "Static_RAM" 80
F1 "Static_RAM.sch" 80
$EndSheet
$Sheet
S 4850 1000 1350 950 
U 5A02A8E5
F0 "UART-SIO" 80
F1 "UART-SIO.sch" 80
$EndSheet
$Sheet
S 6650 1000 1350 950 
U 5A02ADBB
F0 "RTC_LITES" 80
F1 "RTC_LITES.sch" 80
$EndSheet
$Sheet
S 8450 1000 1350 950 
U 5A02DAA6
F0 "ECBdrivers" 80
F1 "ECBdrivers.sch" 80
$EndSheet
$Sheet
S 1250 2400 1350 950 
U 5A02DAE3
F0 "ECBbus" 80
F1 "ECBbus.sch" 80
$EndSheet
$Sheet
S 3050 2400 1350 950 
U 5A02F54E
F0 "Oscillators" 80
F1 "Oscillators.sch" 80
$EndSheet
$Comp
L RR9 RR1
U 1 1 5A033280
P 1450 4700
F 0 "RR1" H 1500 5300 70  0000 C CNN
F 1 "10K" V 1480 4700 60  0000 C CNN
F 2 "discret:r_pack9" H 1450 4700 60  0001 C CNN
F 3 "" H 1450 4700 60  0001 C CNN
	1    1450 4700
	-1   0    0    -1  
$EndComp
$Comp
L VCC #PWR01
U 1 1 5A03335B
P 1800 4000
F 0 "#PWR01" H 1800 4100 30  0001 C CNN
F 1 "VCC" H 1800 4100 30  0000 C CNN
F 2 "" H 1800 4000 60  0000 C CNN
F 3 "" H 1800 4000 60  0000 C CNN
	1    1800 4000
	1    0    0    -1  
$EndComp
Wire Wire Line
	1800 4000 1800 4200
Text GLabel 1950 4300 2    50   UnSpc ~ 0
CPU_PU
Wire Wire Line
	1800 4300 1950 4300
Text GLabel 1950 4400 2    50   UnSpc ~ 0
FPU_PU
Wire Wire Line
	1800 4400 1950 4400
$Comp
L RR9 RR2
U 1 1 5A03791A
P 2950 4700
F 0 "RR2" H 3000 5300 70  0000 C CNN
F 1 "10K" V 2980 4700 60  0000 C CNN
F 2 "discret:r_pack9" H 2950 4700 60  0001 C CNN
F 3 "" H 2950 4700 60  0001 C CNN
	1    2950 4700
	-1   0    0    -1  
$EndComp
$Comp
L VCC #PWR02
U 1 1 5A037920
P 3300 4000
F 0 "#PWR02" H 3300 4100 30  0001 C CNN
F 1 "VCC" H 3300 4100 30  0000 C CNN
F 2 "" H 3300 4000 60  0000 C CNN
F 3 "" H 3300 4000 60  0000 C CNN
	1    3300 4000
	1    0    0    -1  
$EndComp
Wire Wire Line
	3300 4000 3300 4200
Wire Wire Line
	3300 4300 3450 4300
Wire Wire Line
	3300 4400 3450 4400
Text GLabel 3450 4300 2    50   UnSpc ~ 0
~EOP
Text GLabel 3450 4400 2    50   UnSpc ~ 0
B_~NMI
Wire Wire Line
	3300 4500 3450 4500
Wire Wire Line
	3300 4600 3450 4600
Text GLabel 3450 4500 2    50   UnSpc ~ 0
B_~IR1
Text GLabel 3450 4700 2    50   UnSpc ~ 0
B_~IR3
Wire Wire Line
	3300 4700 3450 4700
Wire Wire Line
	3300 4800 3450 4800
Text GLabel 3450 4800 2    50   UnSpc ~ 0
B_~IR5
Text GLabel 3450 4900 2    50   UnSpc ~ 0
B_~IR6
Wire Wire Line
	3300 4900 3450 4900
Wire Wire Line
	3300 5000 3450 5000
Text GLabel 3450 5000 2    50   UnSpc ~ 0
B_~IR7
Text GLabel 3450 4600 2    50   UnSpc ~ 0
B_~IR2
Text GLabel 1950 4500 2    50   UnSpc ~ 0
B_~DREQ
Wire Wire Line
	1800 4500 1950 4500
Wire Wire Line
	1800 4600 1950 4600
Wire Wire Line
	1800 4700 1950 4700
Wire Wire Line
	1800 4800 1950 4800
Text GLabel 1950 4600 2    50   UnSpc ~ 0
RTC_DQ
Wire Wire Line
	1800 4900 1950 4900
Text GLabel 1950 4700 2    50   UnSpc ~ 0
PEREQ
Wire Wire Line
	1950 5000 1800 5000
$Sheet
S 4850 2400 1350 950 
U 5A36BFF0
F0 "DRAM" 80
F1 "DRAM.sch" 80
$EndSheet
Text GLabel 1950 4900 2    50   UnSpc ~ 0
DSIZE
Text GLabel 1950 5000 2    50   UnSpc ~ 0
~SZ32
$Sheet
S 6650 2400 1350 950 
U 5A5BB58C
F0 "SDcard" 80
F1 "SDcard.sch" 80
$EndSheet
$Sheet
S 8450 2400 1350 950 
U 5A5BB681
F0 "bus-IDE" 80
F1 "bus-IDE.sch" 80
$EndSheet
$Comp
L 74LS14 U9
U 6 1 5A5D0AD3
P 5650 6900
F 0 "U9" H 5800 7000 50  0000 C CNN
F 1 "74HCT14" H 5850 6800 50  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 5650 6900 50  0001 C CNN
F 3 "" H 5650 6900 50  0001 C CNN
	6    5650 6900
	1    0    0    -1  
$EndComp
NoConn ~ 6100 6900
NoConn ~ 5200 6900
Wire Wire Line
	1950 5100 1800 5100
Text GLabel 1950 4800 2    50   UnSpc ~ 0
B_~M1
Text GLabel 1950 5100 2    50   UnSpc ~ 0
~SD-CD
NoConn ~ 3300 5100
$Comp
L 74LS74 U15
U 2 1 5A5FB0EF
P 4250 6900
F 0 "U15" H 4250 6900 50  0000 C CNN
F 1 "74LS74" H 4550 6500 50  0000 C CNN
F 2 "dip_sockets:DIP-14__300" H 4250 6900 50  0001 C CNN
F 3 "" H 4250 6900 50  0000 C CNN
	2    4250 6900
	1    0    0    -1  
$EndComp
NoConn ~ 4250 6350
NoConn ~ 4850 6700
NoConn ~ 4850 7100
NoConn ~ 4250 7450
NoConn ~ 3650 6900
NoConn ~ 3650 6700
Text Notes 3500 6100 0    80   ~ 0
SPARES:
Wire Notes Line
	3150 5800 6600 5800
Wire Notes Line
	6600 5800 6600 7650
Wire Notes Line
	6600 7650 3150 7650
Wire Notes Line
	3150 7650 3150 5800
$EndSCHEMATC
