
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; some useful macros:
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;

%imacro setloc  1.nolist
 times   (%1-($-$$)) db 0FFh
%endm

%imacro db_lo   1
 db (%1)&255
%endm

%imacro cnop    0.nolist
%if SOFT_DEBUG
        nop
%endif
%endm

%imacro popm 1-*.nolist
%rep %0
%ifidni %1,ALL
 popa
%elifidni %1,F
 popf
%else
 pop %1
%ifidni %1,DS
 cnop
%elifidni %1,ES
 cnop
%endif
%endif
%rotate 1
%endrep
%endm

%imacro pushm 1-*.nolist
%rep %0
%rotate -1
%ifidni %1,ALL
 pusha
%elifidni %1,F
 pushf
%else
 push %1
%endif
%endrep
%endm


