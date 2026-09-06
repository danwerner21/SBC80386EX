; SEG_DEF.inc
;
%ifndef SEG_DEF
%define SEG_DEF 1

segment CODE	use16	align=16	class=CODE	public
segment _TEXT	use16 	align=16	class=CODE	public
;group AUTO _TEXT CODE

segment CONST2		align=16	class=DATA	public
segment CONST		align=16	class=DATA	public
segment _DATA		align=16	class=DATA	public
segment _BSS		align=16	class=DATA	public
;group DGROUP CONST2 CONST _DATA _BSS

group DGROUP CODE _TEXT CONST2 CONST _DATA _BSS


segment BOOT at 0xFFFF	align=16	class=BOOT	use16


%endif
;
; end SEG_DEF.inc
