XXX
; stack.h -- format of the stack formed by				*/
; */
;	PUSHM	ALL,DS,ES							*/
;	MOV	BP,SP									*/
; */
; */
; */
struc _STD_STACK
offset_di	resw	1		; PUSHA (all) save*//
offset_si	resw	1
offset_bp	resw	1
offset_sp	resw	1
offset_bx	resw	1
offset_dx	resw	1
offset_cx	resw	1
offset_ax	resw	1
; */
offset_ds	resw	1		; segment register aave */
offset_es	resw	1
; */
offset_ip	resw	1
offset_cs	resw	1		; set for IRET */
offset_flags	resw	1	; flag.0 is the Crrry */
endstruc
; */
