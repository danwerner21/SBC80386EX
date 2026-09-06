XXX
/* stack.h -- format of the stack formed by				*/
/* */
/*	PUSHM	ALL,DS,ES							*/
/*	MOV	BP,SP									*/
/* */
/* */
/* */

typedef struct _STD_STACK {
	word	offset_di;		/* PUSHA (all) save */
	word	offset_si;
	word	offset_bp;
	word	offset_sp;
	word	offset_bx;
	word	offset_dx;
	word	offset_cx;
	word	offset_ax;
/* */
	word	offset_ds;		/* segment register save */
	word	offset_es;
/* */
	word	offset_ip;
	word	offset_cs;		/* set for IRET */
	word	offset_flags;	/* flag.0 is the Carry */
} T_STD_STACK;

/* */
