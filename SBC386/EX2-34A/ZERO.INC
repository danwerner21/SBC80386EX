XXX
;----------------------------------------
;	80386 INTERRUPT LOCATIONS	; 	
;----------------------------------------
;
;  start at location 0000:0000
;
;
;       return address points to faulting instruction (Y/N) ------------|
;                                                                       |
;                                                                       V
;
struc LOC0
; vector 0
stg_loc0:
zero_divide	resd	1	;FAULT division by zero DIV, IDIV	Y
debug_exception	resd	1	;TRAP					Y
nmi_ptr:
NMI_interrupt	resd	1	;INT non-maskable interrupt		N
breakpoint	resd	1	;TRAP  int 3  in one instruction	N
overflow	resd	1	;TRAP  into instruction			N
bounds_check	resd	1	;FAULT  bound instruction		Y
%define	int5_ptr bounds_check
invalid_opcode	resd	1	;FAULT  any illegal instruction		Y
FPU_escape	resd	1	;FAULT no FPU, esc or wait (emulation)	Y
; vector 8
int_ptr:
vec_irq0:
double_fault	resd	1	;ABORT any instruction			?
FPU_seg_overrun	resd	1	;ABORT	esc instruction		N
invalid_TSS	resd	1	;FAULT jmp, call, iret, int		Y
seg_not_present	resd	1	;FAULT				Y
stack_fault	resd	1	;FAULT stack references			Y
gen_prot_fault	resd	1	;FAULT any memory reference		Y
page_fault	resd	1	;FAULT any memory access or code fetch	Y
not_used_15	resd	1	; not specified by 386 hardware         -
; vector 16 0x10
video_int:
FPU_error	resd	1	;FAULT esc, wait			Y
vec_int_11h	resd	1
vec_int_12h	resd	1
org_vector:
vec_int_13h	resd	1
vec_int_14h	resd	1
vec_int_15h	resd	1
vec_int_16h	resd	1
vec_int_17h	resd	1
; vector 24 0x18
basic_ptr:
vec_int_18h	resd	1
vec_int_19h	resd	1
vec_int_1Ah	resd	1
vec_int_1Bh	resd	1
vec_int_1Ch	resd	1
param_ptr:
vec_int_1Dh	resd	1	; pointer to video parameters
disk_ptr:
vec_int_1Eh	resd	1	; pointer to diskette parameter table
vec_int_1Fh	resd	1	; pointer to graphic characters 128-255
; vector 32 0x20
Unused_20	resd	0x20
; vector 64 0x40
disk_vector	resd	1	; pointer to diskette int code
hf_tbl_vec	resd	1	; ptr to first disk parameter table
Unused_42	resd	4
hf1_tbl_vec	resd	1	; ptr to second disk parameter table
Unused_47	resd	0x29
; vector 0x70
slave_int_ptr:
vec_irq8	resd	1	; slave ICU interrupts
vec_irq9	resd	1
vec_irq10	resd	1
vec_irq11	resd	1
vec_irq12	resd	1
vec_irq13	resd	1
hdisk_int:
vec_irq14	resd	1	; ptr to hard disk interrupt code
vec_irq15	resd	1
Unused_78	resd	8
; Space for BASIC variables
Basic_Var	resd	127
Basic_end	resd	1
endstruc

TOS	equ	0x400
MFG_TEST	equ	0x500
BOOT_LOCN	equ	0x7C00
