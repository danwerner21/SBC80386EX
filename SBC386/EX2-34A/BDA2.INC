XXX
; bda.h -- definitions of the BIOS Data Area at 0040:0000 (0x400)  */
struct _BDA {		; Bios Data Area at 00400h  */
serial_dev	resw	4	; serial port device codes */
parallel_dev	resw	4	; printer port device codes */
equip_flag	resw	1		; int 12h equipment flags */
mfg_test	resw	1		; initialization flags */
memory_size	resw	1	; base memory size in Kilowords (1024) */
word	mfg_err_flag;
word	mfg_err_flag2;
endstruc
; so C-code refereneces may be of the form  bda.memory_size  */
%define bda (*BDA_PTR)
