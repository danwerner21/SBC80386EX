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
$Descr A 11000 8500
encoding utf-8
Sheet 9 11
Title "SBC-386EX-2"
Date "2018-01-19"
Rev "002"
Comp "RetroBrew Computer Group"
Comment1 "Licensed for hobbyist use only."
Comment2 "Copyright (C) 2017 John R Coffman.  All rights  reserved."
Comment3 ""
Comment4 ""
$EndDescr
Wire Wire Line
	7250 4500 6900 4500
Wire Wire Line
	5850 2900 7250 2900
Wire Wire Line
	7250 4300 6950 4300
Wire Wire Line
	6750 4000 7250 4000
Wire Wire Line
	6450 4100 7250 4100
Wire Wire Line
	6950 3900 7250 3900
Wire Wire Line
	6450 3800 7250 3800
Wire Wire Line
	6950 3400 7250 3400
Wire Wire Line
	9050 1800 8850 1800
Wire Wire Line
	9050 1900 8850 1900
Wire Wire Line
	9050 2100 8850 2100
Wire Wire Line
	9050 2000 8850 2000
Wire Wire Line
	9050 2400 8850 2400
Wire Wire Line
	9050 2500 8850 2500
Wire Wire Line
	9050 2300 8850 2300
Wire Wire Line
	9050 2200 8850 2200
Wire Wire Line
	9050 3100 8850 3100
Wire Wire Line
	9050 3200 8850 3200
Wire Wire Line
	9050 3400 8850 3400
Wire Wire Line
	9050 3300 8850 3300
Wire Wire Line
	9050 2900 8850 2900
Wire Wire Line
	9050 3000 8850 3000
Wire Wire Line
	9050 2800 8850 2800
Wire Wire Line
	9050 2700 8850 2700
Wire Wire Line
	9050 4500 8850 4500
Wire Wire Line
	9050 4600 8850 4600
Wire Wire Line
	9050 4800 8850 4800
Wire Wire Line
	9050 4700 8850 4700
Wire Wire Line
	9050 5100 8850 5100
Wire Wire Line
	9050 5200 8850 5200
Wire Wire Line
	9050 5000 8850 5000
Wire Wire Line
	9050 4900 8850 4900
Wire Wire Line
	9050 4000 8850 4000
Wire Wire Line
	9050 4100 8850 4100
Wire Wire Line
	9050 4300 8850 4300
Wire Wire Line
	9050 4200 8850 4200
Wire Wire Line
	9050 3800 8850 3800
Wire Wire Line
	9050 3900 8850 3900
Wire Wire Line
	9050 3700 8850 3700
Wire Wire Line
	9050 3600 8850 3600
Wire Wire Line
	6400 1800 7250 1800
Wire Wire Line
	6200 1900 7250 1900
Wire Wire Line
	5800 2100 7250 2100
Wire Wire Line
	6000 2000 7250 2000
Wire Wire Line
	5050 2400 7250 2400
Wire Wire Line
	4750 2500 7250 2500
Wire Wire Line
	5250 2300 7250 2300
Wire Wire Line
	5450 2200 7250 2200
Wire Wire Line
	5250 2600 7250 2600
Wire Wire Line
	5650 2800 7250 2800
Wire Wire Line
	5450 2700 7250 2700
Wire Wire Line
	6950 3000 7250 3000
Text GLabel 6900 4500 0    60   Output ~ 0
DSIZE
Text Notes 7400 1200 0    80   ~ 0
Speed:  PD3, PD2\n  00 = 50ns/100ns\n  01 = 80ns\n  10 = 70ns\n  11 = 60ns
Text Notes 8700 1200 0    80   ~ 0
Size:  PD1, PD0\n  00 = 4mb\n  01 = 2mb/32mb\n  10 = 1mb/16mb\n  11 = 8mb
NoConn ~ 7250 4800
NoConn ~ 7250 4700
Text GLabel 9050 1800 2    60   BiDi ~ 0
D0
Text GLabel 9050 1900 2    60   BiDi ~ 0
D1
Text GLabel 9050 2100 2    60   BiDi ~ 0
D3
Text GLabel 9050 2000 2    60   BiDi ~ 0
D2
Text GLabel 9050 2400 2    60   BiDi ~ 0
D6
Text GLabel 9050 2500 2    60   BiDi ~ 0
D7
Text GLabel 9050 2300 2    60   BiDi ~ 0
D5
Text GLabel 9050 2200 2    60   BiDi ~ 0
D4
Text GLabel 9050 3100 2    60   BiDi ~ 0
D12
Text GLabel 9050 3200 2    60   BiDi ~ 0
D13
Text GLabel 9050 3400 2    60   BiDi ~ 0
D15
Text GLabel 9050 3300 2    60   BiDi ~ 0
D14
Text GLabel 9050 2900 2    60   BiDi ~ 0
D10
Text GLabel 9050 3000 2    60   BiDi ~ 0
D11
Text GLabel 9050 2800 2    60   BiDi ~ 0
D9
Text GLabel 9050 2700 2    60   BiDi ~ 0
D8
Text Notes 7800 5700 0    70   ~ 0
MT8D832
$Comp
L MT16D832 SIM1
U 1 1 54DE2C0C
P 8050 3600
F 0 "SIM1" H 7950 5300 70  0000 C CNN
F 1 "MT16D832" H 8000 1850 70  0000 C CNN
F 2 "01N8VEM:DRAM-72-2021" H 8050 3600 60  0001 C CNN
F 3 "" H 8050 3600 60  0001 C CNN
	1    8050 3600
	1    0    0    -1  
$EndComp
Wire Wire Line
	6750 4000 6750 3800
Connection ~ 6750 3800
Wire Wire Line
	6950 3900 6950 4100
Connection ~ 6950 4100
Wire Wire Line
	6950 3100 7250 3100
Wire Wire Line
	6950 3500 7250 3500
Text GLabel 9050 3600 2    60   BiDi ~ 0
D0
Text GLabel 9050 3700 2    60   BiDi ~ 0
D1
Text GLabel 9050 3900 2    60   BiDi ~ 0
D3
Text GLabel 9050 3800 2    60   BiDi ~ 0
D2
Text GLabel 9050 4200 2    60   BiDi ~ 0
D6
Text GLabel 9050 4300 2    60   BiDi ~ 0
D7
Text GLabel 9050 4100 2    60   BiDi ~ 0
D5
Text GLabel 9050 4000 2    60   BiDi ~ 0
D4
Text GLabel 9050 4900 2    60   BiDi ~ 0
D12
Text GLabel 9050 5000 2    60   BiDi ~ 0
D13
Text GLabel 9050 5200 2    60   BiDi ~ 0
D15
Text GLabel 9050 5100 2    60   BiDi ~ 0
D14
Text GLabel 9050 4700 2    60   BiDi ~ 0
D10
Text GLabel 9050 4800 2    60   BiDi ~ 0
D11
Text GLabel 9050 4600 2    60   BiDi ~ 0
D9
Text GLabel 9050 4500 2    60   BiDi ~ 0
D8
$Comp
L 74LS257 U19
U 1 1 5A36CEB0
P 1750 1550
F 0 "U19" H 1800 1700 70  0000 C CNN
F 1 "74F257" H 1800 1400 70  0000 C CNN
F 2 "dip_sockets:DIP-16__300" H 1750 1550 50  0001 C CNN
F 3 "" H 1750 1550 50  0001 C CNN
	1    1750 1550
	1    0    0    -1  
$EndComp
$Comp
L 74LS257 U20
U 1 1 5A36D159
P 4000 2250
F 0 "U20" H 4050 2400 70  0000 C CNN
F 1 "74F257" H 4050 2100 70  0000 C CNN
F 2 "dip_sockets:DIP-16__300" H 4000 2250 50  0001 C CNN
F 3 "" H 4000 2250 50  0001 C CNN
	1    4000 2250
	1    0    0    -1  
$EndComp
$Comp
L 74LS257 U21
U 1 1 5A36D1CD
P 4000 3750
F 0 "U21" H 4050 3900 70  0000 C CNN
F 1 "74F257" H 4050 3600 70  0000 C CNN
F 2 "dip_sockets:DIP-16__300" H 4000 3750 50  0001 C CNN
F 3 "" H 4000 3750 50  0001 C CNN
	1    4000 3750
	1    0    0    -1  
$EndComp
Wire Wire Line
	5850 2900 5850 4000
Wire Wire Line
	5850 4000 4750 4000
Wire Wire Line
	5650 2800 5650 3750
Wire Wire Line
	5650 3750 4750 3750
Wire Wire Line
	5450 2700 5450 3500
Wire Wire Line
	5450 3500 4750 3500
Wire Wire Line
	5250 2600 5250 3250
Wire Wire Line
	5250 3250 4750 3250
Wire Wire Line
	5050 2400 5050 2250
Wire Wire Line
	5050 2250 4750 2250
Wire Wire Line
	5250 2300 5250 2000
Wire Wire Line
	5250 2000 4750 2000
Wire Wire Line
	5450 2200 5450 1750
Wire Wire Line
	5450 1750 4750 1750
Wire Wire Line
	7250 4600 6500 4600
Text GLabel 6500 4600 0    60   Output ~ 0
~SZ32
Wire Wire Line
	5800 2100 5800 1500
Wire Wire Line
	5800 1500 2850 1500
Wire Wire Line
	2850 1500 2850 1800
Wire Wire Line
	2850 1800 2500 1800
Wire Wire Line
	6000 2000 6000 1400
Wire Wire Line
	6000 1400 2750 1400
Wire Wire Line
	2750 1400 2750 1550
Wire Wire Line
	2750 1550 2500 1550
Wire Wire Line
	2500 1300 6200 1300
Wire Wire Line
	6200 1300 6200 1900
Wire Wire Line
	2500 1050 6400 1050
Wire Wire Line
	6400 1050 6400 1800
Text Label 2500 1050 0    60   ~ 0
DR_A0
Text Label 2500 1300 0    60   ~ 0
DR_A1
Text Label 2500 1550 0    60   ~ 0
DR_A2
Text Label 2500 1800 0    60   ~ 0
DR_A3
Text Label 4750 1750 0    60   ~ 0
DR_A4
Text Label 4750 2000 0    60   ~ 0
DR_A5
Text Label 4750 2250 0    60   ~ 0
DR_A6
Text Label 4750 2500 0    60   ~ 0
DR_A7
Text Label 4750 3250 0    60   ~ 0
DR_A8
Text Label 4750 3500 0    60   ~ 0
DR_A9
Text Label 4750 3750 0    60   ~ 0
DR_A10
Text Label 4750 4000 0    60   ~ 0
DR_A11
Text GLabel 1000 1000 0    50   Input ~ 0
A2
Text GLabel 1000 1250 0    50   Input ~ 0
A3
Text GLabel 1000 1500 0    50   Input ~ 0
A4
Text GLabel 1000 1750 0    50   Input ~ 0
A5
Text GLabel 3250 1950 0    50   Input ~ 0
A7
Text GLabel 3250 2200 0    50   Input ~ 0
A8
Text GLabel 3250 2450 0    50   Input ~ 0
A9
Text GLabel 3250 3200 0    50   Input ~ 0
A10
Text GLabel 3250 3450 0    50   Input ~ 0
A11
Text GLabel 3250 1700 0    50   Input ~ 0
A6
Text GLabel 3250 3950 0    50   Input ~ 0
A24
Text GLabel 3250 3700 0    50   Input ~ 0
A22
Text GLabel 3250 4050 0    50   Input ~ 0
A25
Text GLabel 3250 3800 0    50   Input ~ 0
A23
Text GLabel 1000 1100 0    50   Input ~ 0
A12
Text GLabel 1000 1350 0    50   Input ~ 0
A13
Text GLabel 1000 1600 0    50   Input ~ 0
A14
Text GLabel 1000 1850 0    50   Input ~ 0
A15
Text GLabel 3250 1800 0    50   Input ~ 0
A16
Text GLabel 3250 2050 0    50   Input ~ 0
A17
Text GLabel 3250 2300 0    50   Input ~ 0
A18
Text GLabel 3250 2550 0    50   Input ~ 0
A19
Text GLabel 3250 3300 0    50   Input ~ 0
A20
Text GLabel 3250 3550 0    50   Input ~ 0
A21
Wire Wire Line
	1000 2000 800  2000
$Comp
L GND #PWR026
U 1 1 5A36E668
P 1000 2250
F 0 "#PWR026" H 1000 2250 30  0001 C CNN
F 1 "GND" H 1000 2180 30  0001 C CNN
F 2 "" H 1000 2250 60  0000 C CNN
F 3 "" H 1000 2250 60  0000 C CNN
	1    1000 2250
	1    0    0    -1  
$EndComp
Wire Wire Line
	1000 2100 1000 2250
$Comp
L GND #PWR027
U 1 1 5A36E71B
P 3250 2950
F 0 "#PWR027" H 3250 2950 30  0001 C CNN
F 1 "GND" H 3250 2880 30  0001 C CNN
F 2 "" H 3250 2950 60  0000 C CNN
F 3 "" H 3250 2950 60  0000 C CNN
	1    3250 2950
	1    0    0    -1  
$EndComp
Wire Wire Line
	3250 2800 3250 2950
$Comp
L GND #PWR028
U 1 1 5A36E733
P 3250 4450
F 0 "#PWR028" H 3250 4450 30  0001 C CNN
F 1 "GND" H 3250 4380 30  0001 C CNN
F 2 "" H 3250 4450 60  0000 C CNN
F 3 "" H 3250 4450 60  0000 C CNN
	1    3250 4450
	1    0    0    -1  
$EndComp
Wire Wire Line
	3250 4300 3250 4450
Wire Wire Line
	800  2700 3250 2700
Wire Wire Line
	800  2000 800  2700
Wire Wire Line
	3250 4200 2800 4200
Wire Wire Line
	2800 4200 2800 2700
Connection ~ 2800 2700
Text Label 1400 2700 0    60   ~ 0
MUX
$Comp
L GAL16V8 U22
U 1 1 5A4FE95E
P 1900 5900
F 0 "U22" H 1900 6000 60  0000 C CNN
F 1 "GAL16V8" H 1900 5300 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 1900 5900 60  0001 C CNN
F 3 "" H 1900 5900 60  0000 C CNN
	1    1900 5900
	1    0    0    -1  
$EndComp
$Comp
L GAL16V8 U23
U 1 1 5A4FEA1D
P 4650 5900
F 0 "U23" H 4650 6000 60  0000 C CNN
F 1 "GAL16V8" H 4650 5300 60  0000 C CNN
F 2 "dip_sockets:DIP-20__300" H 4650 5900 60  0001 C CNN
F 3 "" H 4650 5900 60  0000 C CNN
	1    4650 5900
	1    0    0    -1  
$EndComp
Text Notes 1600 5300 0    80   ~ 0
DCTL16-2
$Comp
L GND #PWR029
U 1 1 5A4FEAB3
P 2700 6500
F 0 "#PWR029" H 2700 6500 30  0001 C CNN
F 1 "GND" H 2700 6430 30  0001 C CNN
F 2 "" H 2700 6500 60  0000 C CNN
F 3 "" H 2700 6500 60  0000 C CNN
	1    2700 6500
	1    0    0    -1  
$EndComp
Wire Wire Line
	2500 6300 2700 6300
Wire Wire Line
	2700 6300 2700 6500
Text GLabel 1100 5500 0    50   Input ~ 0
CLK2
Wire Wire Line
	1100 5500 1300 5500
Text GLabel 1100 5600 0    50   Input ~ 0
~ADS
Wire Wire Line
	1100 5600 1300 5600
Text GLabel 1100 5700 0    50   Input ~ 0
~DRAM
Wire Wire Line
	1100 5700 1300 5700
Text GLabel 1100 5800 0    50   Input ~ 0
~READY
Wire Wire Line
	1100 5800 1300 5800
Text GLabel 1100 5900 0    50   Input ~ 0
~RD
Wire Wire Line
	1100 5900 1300 5900
Text GLabel 1100 6000 0    50   Input ~ 0
DT_~R
Wire Wire Line
	1100 6000 1300 6000
Text GLabel 1100 6100 0    50   Input ~ 0
~REFRESH
Wire Wire Line
	1100 6100 1300 6100
NoConn ~ 1300 6300
Wire Wire Line
	2500 6000 3100 6000
Text Label 2700 6000 0    60   ~ 0
RAS
Wire Wire Line
	2500 6100 3000 6100
Text Label 2700 6100 0    60   ~ 0
MUX
Wire Wire Line
	2500 6200 3200 6200
Text Label 2700 6200 0    60   ~ 0
CAS
NoConn ~ 2500 5500
NoConn ~ 2500 5700
NoConn ~ 2500 5800
NoConn ~ 2500 5900
Text GLabel 3850 5500 0    50   Input ~ 0
DT_~R
Wire Wire Line
	3850 5500 4050 5500
Wire Wire Line
	3100 5600 4050 5600
Wire Wire Line
	3200 5700 4050 5700
Text GLabel 3850 5800 0    50   Input ~ 0
~REFRESH
Wire Wire Line
	3850 5800 4050 5800
Text GLabel 3850 5900 0    50   Input ~ 0
~BLE
Wire Wire Line
	3850 5900 4050 5900
Text GLabel 3850 6000 0    50   Input ~ 0
~BHE
Wire Wire Line
	3850 6000 4050 6000
Text GLabel 3850 6100 0    50   Input ~ 0
A1
Wire Wire Line
	3850 6100 4050 6100
Text GLabel 3850 6200 0    50   Input ~ 0
A22
Wire Wire Line
	3850 6200 4050 6200
Text GLabel 3850 6300 0    50   Input ~ 0
A24
Wire Wire Line
	3850 6300 4050 6300
Wire Wire Line
	3100 6000 3100 5600
Wire Wire Line
	3200 6200 3200 5700
Wire Wire Line
	5250 6300 5750 6300
Text Label 5450 6300 0    60   ~ 0
~SZ32
Wire Wire Line
	5250 6100 5750 6100
Text Label 5450 6100 0    60   ~ 0
~CAS20
Wire Wire Line
	5250 6000 5750 6000
Text Label 5450 6000 0    60   ~ 0
~RAS1
Wire Wire Line
	5250 5800 5750 5800
Text Label 5450 5800 0    60   ~ 0
~RAS2
Wire Wire Line
	5250 5700 5750 5700
Text Label 5450 5700 0    60   ~ 0
~RAS3
Wire Wire Line
	5250 5600 5750 5600
Text Label 5450 5600 0    60   ~ 0
~CAS31
Wire Wire Line
	5250 5500 5750 5500
Text Label 5450 5500 0    60   ~ 0
DSIZE
Wire Wire Line
	5750 5900 5250 5900
Text Label 5450 5900 0    60   ~ 0
~RAS0
Text Notes 4450 5300 0    80   ~ 0
DRAM-2
Text Label 7200 3000 2    60   ~ 0
~RAS0
Text Label 7200 3100 2    60   ~ 0
~RAS2
Text Label 7200 3400 2    60   ~ 0
~RAS1
Text Label 7200 3500 2    60   ~ 0
~RAS3
Text Label 6700 3800 2    60   ~ 0
~CAS20
Text Label 6700 4100 2    60   ~ 0
~CAS31
Text Label 7100 4300 2    60   ~ 0
~WE
Text Notes 5700 4600 0    70   ~ 0
to Pull-up \n  (10K)
Wire Wire Line
	5750 6200 5250 6200
Text Label 5450 6200 0    60   ~ 0
~WE
Text GLabel 1100 6200 0    50   Input ~ 0
D_~C
Wire Wire Line
	1100 6200 1300 6200
Text GLabel 2650 5600 2    60   Output ~ 0
HALT
Wire Wire Line
	2500 5600 2650 5600
Text Notes 8550 1500 0    80   ~ 0
PD0 = DSIZE\nPD1 = ~SZ32
$EndSCHEMATC
