;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;boot.asm
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; The Real Mode statup jump
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	bits	16

SEGBASE equ 0x10000-(ROM<<6)

        align   16
bootstrap:
        jmp     SEGBASE:0000	; 5 byte real-mode far call
%include "date.inc"
	db	0xFF, 0xFC, 0x03	




