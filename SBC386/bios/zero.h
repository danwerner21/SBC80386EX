XXX
/* zero.inc */
/* this file is used to make "zero.h" */
/*----------------------------------------*/
/*	80386 INTERRUPT LOCATIONS	;		*/
/*----------------------------------------*/
/*  start at location 0000:0000 */
/*       return address points to faulting instruction (Y/N) ------------| */
/*                                                                       | */
/*                                                                       V */
struct _Loc0_vectors_ {
/* vector 0 */
dword	zero_divide;
#define stg_loc0 zero_divide
dword	debug_exception;
dword	NMI_interrupt;
#define nmi_ptr NMI_interrupt
dword	breakpoint;
dword	overflow;
dword	bounds_check;
%define	int5_ptr bounds_check
dword	invalid_opcode;
dword	FPU_escape;
/* vector 8 */
dword	double_fault;
#define int_ptr double_fault
#define vec_irq0 double_fault
dword	FPU_seg_overrun;
dword	invalid_TSS;
dword	seg_not_present;
dword	stack_fault;
dword	gen_prot_fault;
dword	page_fault;
dword	not_used_15;
/* vector 16 0x10 */
dword	FPU_error;
#define video_int FPU_error
dword	vec_int_11h;
dword	vec_int_12h;
dword	vec_int_13h;
#define org_vector vec_int_13h
dword	vec_int_14h;
dword	vec_int_15h;
dword	vec_int_16h;
dword	vec_int_17h;
/* vector 24 0x18 */
dword	vec_int_18h;
#define basic_ptr vec_int_18h
dword	vec_int_19h;
dword	vec_int_1Ah;
dword	vec_int_1Bh;
dword	vec_int_1Ch;
dword	vec_int_1Dh;
#define param_ptr vec_int_1Dh
dword	vec_int_1Eh;
#define disk_ptr vec_int_1Eh
dword	vec_int_1Fh;
/* vector 32 0x20 */
dword	Unused_20[0x20]
/* vector 64 0x40 */
dword	disk_vector;
dword	hf_tbl_vec;
dword	def_video_drv;
dword	EGA_VGA_char;
dword	Unused_44[2]
dword	hf1_tbl_vec;
dword	Unused_47[3]
dword	Alarm_handler;
dword	Unused_4B[0x15]
dword	User_interrupts[7  	; User interrupts 60h..66h]
dword	LIM_EMS_driver;
dword	Unused_68[8]
/* vector 0x70 */
dword	vec_irq8;
#define slave_int_ptr vec_irq8
dword	vec_irq9;
dword	vec_irq10;
dword	vec_irq11;
dword	vec_irq12;
dword	vec_irq13;
dword	vec_irq14;
#define hdisk_int vec_irq14
dword	vec_irq15;
dword	Unused_78[8]
/* Space for BASIC variables */
dword	Basic_Var[127]
dword	Basic_end;
} *LOC0_PTR;
#define loc0 (*LOC0_PTR)
#define TOS 0x400
#define MFG_TEST 0x500
#define BOOT_LOCN 0x7C00
