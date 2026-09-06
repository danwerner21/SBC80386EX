;************************************************************************************************************************
;
; /$$$$$$$   /$$$$$$  /$$   /$$  /$$$$$$   /$$$$$$  /$$$$$$$  /$$$$$$$$      
;| $$__  $$ /$$__  $$| $$$ | $$ /$$__  $$ /$$__  $$| $$__  $$| $$_____/      
;| $$  \ $$| $$  \ $$| $$$$| $$| $$  \__/| $$  \ $$| $$  \ $$| $$            
;| $$  | $$| $$$$$$$$| $$ $$ $$| $$      | $$  | $$| $$  | $$| $$$$$         
;| $$  | $$| $$__  $$| $$  $$$$| $$      | $$  | $$| $$  | $$| $$__/         
;| $$  | $$| $$  | $$| $$\  $$$| $$    $$| $$  | $$| $$  | $$| $$            
;| $$$$$$$/| $$  | $$| $$ \  $$|  $$$$$$/|  $$$$$$/| $$$$$$$/| $$$$$$$$      
;|_______/ |__/  |__/|__/  \__/ \______/  \______/ |_______/ |________/      
;                                                                       
;
;    This is test code for research purposes only.
;
;
;
;
;
;************************************************************************************************************************
; HARDWARE SPECIFIC VALUES		:
;				:
;  -  CONTROLLER I/O PORT		:
;     > WHEN READ FROM:		:
;	HF_PORT+0 - READ DATA (FROM CONTROLLER TO CPU)	:
;	HF_PORT+1 - GET ERROR REGISTER		:
;	HF_PORT+2 - GET SECTOR COUNT		:
;	HF_PORT+3 - GET SECTOR NUMBER		:
;	HF_PORT+4 - GET CYLINDER LOW		:
;	HF_PORT+5 - GET CYLINDER HIGH (2 BITS)	:
;	HF_PORT+6 - GET SIZE/DRIVE/HEAD		:
;	HF_PORT+7 - GET STATUS REGISTER		:
;				:
;     > WHEN WRITTEN TO:		:
;	HF_PORT+0 - WRITE DATA (FROM CPU TO CONTROLLER)	:
;	HF_PORT+1 - SET PRECOMPENSATION CYLINDER	:
;	HF_PORT+2 - SET SECTOR COUNT		:
;	HF_PORT+3 - SET SECTOR NUMBER		:
;	HF_PORT+4 - SET CYLINDER LOW		:
;	HF_PORT+5 - SET CYLINDER HIGH (2 BITS)	:
;	HF_PORT+6 - SET SIZE/DRIVE/HEAD		:
;	HF_PORT+7 - SET COMMAND REGISTER		:
;				:
;------------------------------------------------------------

HF_PORT		EQU	01F0H	; DISK PORT

IDEDTA		EQU       HF_PORT+0	; DATA PORT (16 BIT)
IDEERR		EQU       HF_PORT+1	; READ: ERROR REGISTER; WRITE: PRECOMP
IDESECTC	EQU       HF_PORT+2	; SECTOR COUNT
IDESECTN	EQU       HF_PORT+3	; SECTOR NUMBER
IDECYLLO	EQU       HF_PORT+4	; CYLINDER LOW
IDECYLHI	EQU       HF_PORT+5	; CYLINDER HIGH
IDEHEAD		EQU       HF_PORT+6	; DRIVE/HEAD
IDESTTS		EQU       HF_PORT+7	; READ: STATUS; WRITE: COMMAND

IDEADDR		EQU       HF_PORT+15; DRIVE ADDRESS (NOT IBM COMPAT?)

IDE_CMD_RECAL		EQU     010h
IDE_CMD_PIO_READ    EQU 	020h
IDE_CMD_PIO_WRITE   EQU 	030h
IDE_CMD_INIT_PARAM  EQU 	091h
IDE_CMD_DMA_READ    EQU 	0C8h
IDE_CMD_DMA_WRITE   EQU 	0CAh
IDE_CMD_SPINDOWN    EQU 	0E0h
IDE_CMD_SPINUP      EQU 	0E1h
IDE_CMD_IDENT       EQU 	0ECh
IDE_CMD_SET_FEATURE EQU 	0EFh






	push	cs
	pop		ds
	mov		si,startnotice
	call	putstr

	mov		dx,0000h		; select segment 0000
	mov 	es,dx

;	mov 	bx,0000h
;	call 	DUMP_RAM
;
;	mov		dx,0000h		; select segment 0000
;	mov 	es,dx

;  CLEAR WORKING RAM
	xor 	bx,bx
.115:
	xor 	ax,ax
	es mov 	byte [bx+06000h],al
	cmp 	bx,0200h
	je 		.116
	inc 	bx
	jmp 	.115
.116:

;	mov 	bx,06000h
;	call 	DUMP_RAM
	
	CALL 	IDE_READ_ID

	push	cs
	pop		ds
	mov		si,IDEMSG1
	call	putstr
	mov		dx,0000h
	PUSH 	DX
	POP 	DS
	mov 	es,dx
	xor 	ax,ax
	mov 	bx,40
	es mov 	byte [bx+06000h],al
	mov		si,06014h
	call	putstr
	CALL 	crlf

	push	cs
	pop		ds
	mov		si,IDEMSG3
	call	putstr
	mov		dx,0000h
	PUSH 	DX
	POP 	DS
	mov 	es,dx
	xor 	ax,ax
	mov 	bx,94
	es mov 	byte [bx+06000h],al
	mov		si,06036h
	call	putstr
	CALL 	crlf

	push	cs
	pop		ds
	mov		si,IDEMSG2
	call	putstr
	mov		dx,0000h
	PUSH 	DX
	POP 	DS
	mov 	es,dx
	xor 	ax,ax
	mov 	bx,36H
	es mov 	byte [bx+06000h],al
	mov		si,0602Eh
	call	putstr
	CALL 	crlf

	mov 	bx,63H
	es mov 	al, byte [bx+06000h]
    and     al,00000001b
    jnz     .211
	push	cs
	pop		ds
	mov		si,IDEMSG5
	call	putstr
	jmp 	.212
.211
	push	cs
	pop		ds
	mov		si,IDEMSG4
	call	putstr

; DMA Test goes here

	call 	wr_lba

	CALL 	IDE_READ_DMA

	mov 	bx,06000h
	call 	DUMP_RAM

	mov 	bx,06000h
	call 	DUMP_RAM

	mov 	bx,06000h
	call 	DUMP_RAM

	mov 	bx,06000h
	call 	DUMP_RAM


	mov 	bx,06000h
	call 	DUMP_RAM


	mov 	bx,06000h
	call 	DUMP_RAM




.212




	
	push	cs
	pop		ds
	mov		si,msg99	;"Done." message
	call	putstr

	hlt





DUMP_RAM:
	xor     dx,dx
	xor     cx,cx
	mov 	ax,bx
	call 	wout
	call 	space

.15:
	es mov 	al,byte [bx]
	call 	bout
	call 	space
	cmp 	cx,01FFh
	je 		.16
	inc 	bx
	inc		cx
	inc 	dl
	cmp 	dl,10h
	je 		.16a
	jmp 	.15

.16a:
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx
	dec 	bx

	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx
	dec 	cx


    call 	space
    call 	space
   	xor     dx,dx
.16b
	es mov 	al,byte [bx]
	call 	charout
	cmp 	cx,01FFh
	je 		.16
	inc 	bx
	inc		cx
	inc 	dl
	cmp 	dl,10h
	je 		.16c
	jmp 	.16b



.16c
	call crlf
	xor     dx,dx
	mov 	ax,bx
	call 	wout
	call 	space
	jmp 	.15
.16:
	call 	crlf
    ret



;int_irq14:
;	sti
;	;push 	ax
;	push 	bx
;	push 	cx
;	push 	dx
;	push    es
;	push    ds

;	mov	al,1111b	
;	mov	dx,P1LTC	; get the LITES latch
;	not	al
;	shl	al,4		; shift complement to position
;	mov	ah,al		; save in AH
;	in	al,dx		; read the latch
;	and	al,0Fh		; preserve bits
;	or	al,ah		; set the new bits
;	out	dx,al		; put out the new LITES value

	
;	push	cs
;	pop		ds
;	mov		si,msgint14	
;	call	putstr

;	mov	al,1000b	
;	mov	dx,P1LTC	; get the LITES latch
;	not	al
;	shl	al,4		; shift complement to position
;	mov	ah,al		; save in AH
;	in	al,dx		; read the latch
;	and	al,0Fh		; preserve bits
;	or	al,ah		; set the new bits
;	out	dx,al		; put out the new LITES value

;	pop 	ds
;	pop 	es
;	pop 	dx
;	pop 	cx
;	pop 	bx
;	pop 	ax
;	iret


; -----------------------------------------------------------------------------	
;  DIDE_READ_ID
; -----------------------------------------------------------------------------	
; Read the 512 byte ID information from the attached drive
;
;  int DIDE_READ_ID(far byte *buffer, byte slave, byte secondary);
;
;
;-----------------------------------------------------------------------------
IDE_READ_ID:
;        push    bp
 ;       mov     bp,sp
  ;      pushm   es,bx,di

			mov	al,0000b	; show '0001' in the LITES
			call	lites

	call	ide_wait_not_busy		;make sure drive is ready

			mov	al,0011b	; show '0001' in the LITES
			call	lites


        xor     ax,ax
        xor     dx,dx
        mov     cx,0	               ; select Master/Slave
        call    wr_lba                  ; select device

	mov	al,0111b	; show '0001' in the LITES
	call	lites

; SET 8-BIT MODE
	  	call	ide_wait_not_busy		;make sure drive is ready
		mov	al,01h  
		mov	dx,IDEERR
		out	dx,al
		mov	al,IDE_CMD_SET_FEATURE
		mov	dx,IDESTTS
		out	dx,al
		call	ide_wait_not_busy		;make sure drive is ready


; GET DRIVE IDENT
		mov	al,IDE_CMD_IDENT
		mov	dx,IDESTTS
		out	dx,al

		call	ide_wait_drq			;wait until it's got the data
		jz	.3

	   	mov	ax,-1
		jmp	.9
.3:

	mov	al,1111b	; show '0001' in the LITES
	call	lites


        mov     bx,06000h
		call	read_data				;grab the data


	mov	al,0110b	; show '0001' in the LITES
	call	lites


        xor     ax,ax
.9:
   ;     popm    es,bx,di
    ;    leave
		ret



;-----------------------------------------------------------------------------
;  Wait for RDY to be set
;
;  Exit with:
;       AL contains status
;       All other registers preserved
;
;------------------------------------------------------------------------------
ide_wait_not_busy:
        push   dx

.1:
		mov	dx,IDESTTS
		in	al,dx

        and     al,10000000b
        jnz     .1

        pop    dx
		ret



;------------------------------------------------------------------------------
	;Wait for the drive to be ready to transfer data (DRQ = data request)
	;Returns the drive's status in Acc
;
;  Exit with:
;       AL contains status
;       All other registers preserved
;------------------------------------------------------------------------------
ide_wait_drq:
        pushm   bx,dx,cx

	mov	cx,0FFFFh
.1:
   		mov	dx,IDESTTS
		in	al,dx

        and     al,10001000b		; Mask off Busy(7) and DRQ(3)
        xor     al,00001000b		; We want Busy(7) to be 0 and DRQ (3) to be 1

		loopnz	.1

		or	al,al
        popm    bx,dx,cx
	ret

;------------------------------------------------------------------------------
; Read a block of 512 bytes (one sector) from the drive
; and store it in memory @ HL
; Read a sector of 512 bytes into memory at ES:[BX]
;
;  Call with:
;       ES:BX -- pointer to the data block
;
;  Exit with:
;       AX and DX are destroyed; other registers preserved
;
;-----------------------------------------------------------------------------
read_data:
        pushm   bx,cx

		mov		dx,IDEDTA

        xchg    di,bx


	mov     cx,256          ; sector size in words
rdblk2:
	in	al,dx
	mov ah,al
	in	al,dx
	stosb
	mov al,ah
	stosb
    loop    rdblk2

    popm    bx,cx
	ret


;-----------------------------------------------------------------------------
; write the logical block address to the drive's registers
;
;  Call with:
;       DX:AX = logical block address
;       CL = Master/Slave selection in bit 4
;
;  Exit with:
;       AX, BX, DX are destroyed
;
;-----------------------------------------------------------------------------
wr_lba:
        push    ax
        push    dx

        mov     al,10h          ; Master/Slave mask
        and     al,cl           ; mask bit
        mov     bl,dh           ; high order
        and     bl,00Fh
        or      bl,0E0h         ; mark as LBA

		or	al,bl
		mov	dx,IDEHEAD
		out	dx,al
	
        pop     bx              ; get DL to BL

		mov	al,bl
		dec	dx
		out	dx,al

        pop     bx

		mov	al,bh
		dec	dx
		out	dx,al
	
		mov	al,bl
		dec	dx
		out	dx,al
	
		mov	al,1
		dec	dx
		out	dx,al
	
		ret



;_______________________________________________________________________________________________





IDE_READ_DMA:
; setup DMA

; clear byte pointer
	xor     ax,ax
	mov		dx,DMACLRBP 
	out		dx,al

; Set Requester Address
	mov 	al,IDEDTA & 0FFh
	mov 	dx,DMA1REQ0_1
	out 	dx,al
	mov		al, (IDEDTA >> 8) & 0FFh
	mov 	dx,DMA1REQ0_1
	out 	dx,al
	xor     ax,ax
	mov 	dx,DMA1REQ2_3
	out 	dx,al
	mov 	dx,DMA1REQ2_3
	out 	dx,al

; Set Target Address
	mov 	al,06000h & 0FFh
	mov 	dx,DMA1TAR
	out 	dx,al
	mov		al, (06000h >> 8) & 0FFh
	mov 	dx,DMA1TAR
	out 	dx,al
	xor     ax,ax
	mov 	dx,DMA1TAR2
	out 	dx,al
	mov 	dx,DMA1TAR3
	out 	dx,al

; Set Byte Count
	mov 	al,01FFh & 0FFh
	mov 	dx,DMA1BYC
	out 	dx,al
	mov		al, (01FFh >> 8) & 0FFh
	mov 	dx,DMA1BYC
	out 	dx,al
	xor     ax,ax
	mov 	dx,DMA1BYC2
	out 	dx,al

; Set overflow enable
	xor     ax,ax
	mov 	dx,DMAOVFE
	out 	dx,al

; Set Command 1 Register
	xor     ax,ax
	mov 	dx,DMACMD1
	out 	dx,al

; Set Command 2 Register
	xor     ax,ax
	mov 	dx,DMACMD2
	out 	dx,al

; Set DMA Mode 1 Register
	mov     al,01000101b
	mov 	dx,DMAMOD1
	out 	dx,al

; Set DMA Mode 2 Register
	mov     al,01010001b
	mov 	dx,DMAMOD2
	out 	dx,al

; Set DMA channel Mask (Enable DMA channel 1)
	mov     al,00000001b
	mov 	dx,DMAMSK
	out 	dx,al

; Set DMA Bus Size (16bit read 8bit write, channel 1)
	mov     al,00010001b
	mov 	dx,DMABSR
	out 	dx,al


; Set DMA Chaining
	mov     al,00000001b
	mov 	dx,DMACHR
	out 	dx,al

; Set DMA interrupt enable (for now, none)
	mov     al,00000000b
	mov 	dx,DMAIEN
	out 	dx,al

; Set DMA configuration register
	mov     al,00000000b
	mov 	dx,DMACFG
	out 	dx,al


	call ide_wait_not_busy
	sti


	mov		al,0
	mov		dx,IDEERR	; READ: ERROR REGISTER; WRITE: PRECOMP
	out		dx,al
	mov		al,1
	mov		dx,IDESECTC	; SECTOR COUNT
	out		dx,al
	mov		al,1
	mov		dx,IDESECTN	; SECTOR NUMBER
	out		dx,al
	mov		al,0
	mov		dx,IDECYLLO	; CYLINDER LOW
	out		dx,al
	mov		al,0
	mov		dx,IDECYLHI		; CYLINDER HIGH
	out		dx,al
	mov		al,0E0h
	mov		dx,IDEHEAD		; DRIVE/HEAD
	out		dx,al

	call ide_wait_not_busy

; issue IDE command to DMA read
	mov		al,IDE_CMD_DMA_READ
	mov		dx,IDESTTS
	out		dx,al

	call ide_wait_not_busy


; wait for DMA to complete
;.1:
;	mov		dx,DMASTS
;	in		al,dx
;	and	al,02h		
;	cmp	al,00		
;	je	.1

	ret







startnotice:
	db	NL,NL,NL
    db      "Dan IDE Test Code ", __DATE__, " ", __TIME__, NL, NUL

msg99:
	db	"Done.",NL,NUL

IDEMSG1:
	DB	"IDE SERIAL NUMBER: ",NUL
IDEMSG2:
	DB	"IDE FIRMWARE REVISION: ",NUL
IDEMSG3:
	DB	"IDE MODEL NUMBER: ",NUL
IDEMSG4:
	DB	"IDE SUPPORTS DMA.",NL,NUL
IDEMSG5:
	DB	"IDE DOES NOT SUPPORT DMA.",NL,NUL





msgint14:
	db	NL,"int14.",NL,NUL




charout:
   cmp     al,126     ; test for NL
   jg     charout1            ; if not, just put out the character
   cmp     al,31     ; test for NL
   jg     charout2            ; if not, just put out the character
   jmp    charout1

charout2:
	jmp	putc
charout1:
	mov al,'.'
	jmp putc





;
; output an ASCII_SP to the console
;
space:
	mov	al,ASCII_SP
	jmp	putc
;
; output a CR/LF to the console
;
;;crlf:
;
; outc -- write an ASCII 'cooked' character
;       Convert NL to CR,NL
;
outc:
        cmp     al,ASCII_NL     ; test for NL
        jne     putc            ; if not, just put out the character
crlf:
        mov     al,ASCII_CR     ; get a CR
        call    putc            ; write it out
        mov     al,ASCII_NL     ; restore NL
;
; putc -- put out a character in AL to the SIO0 port
;
putc:
	push	dx		; register save
	push	ax		; PUSH EAX
putc1:
        mov     dx,LSR0         ; Line Status Register

        in      al,dx
        test    al,LSR_TBE      ; Transmit Buffer Empty
        jz      putc1

        pop     ax
        mov     dx,TBR0         ; Transmit buffer register
        out     dx,al           ; send the character

        pop     dx              ; register restore
        ret


; test for character waiting for input
;	returns 1 in AL if char waiting
;	returns 0 in AL if no char is waiting
;
testc:
	push	dx
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	and	al,LSR_RBF	; Receive buffer full
	pop	dx
	ret


getc:
	push	dx
getc1:
	mov	dx,LSR0		; Line Status Register
	in	al,dx
	test	al,LSR_RBF	; Receive buffer full
	jz	getc1

	mov	dx,RBR0		; Receive Buffer
	in	al,dx		; get the character
	pop	dx
	ret

; putstr -- put out ASCII string terminated by NUL
;       DS:SI points at the string
;
putstr:
        xor     ax,ax           ; set NUL terminator in AH
;
; gputstr -- general put out an ASCII string
;       DS:SI points at the string
;       AH is the terminator character, usually NUL
;
gputstr:
        lodsb                   ; get next character
        cmp     ah,al           ; is it the terminator
        je      ps9
        call    outc
        jmp     gputstr
ps9:    ret




; Hexadecimal output:
; extdword(EAX)
; dword(DX:AX) word(AX) byte(AL) nibble(AL[3..0])   output
;
eout:   ror     eax,16          ; put out high word first
        call    wout
        shr     eax,16          ; put out the low word
        jmp     wout
dout:   xchg    ax,dx           ; put out DX first
        call    wout
        mov     ax,dx
wout:   xchg    ah,al           ; put out AH first
        call    bout
        mov     al,ah           ; put out former AL
bout:   push    ax              ; save AL
        shr     al,4            ; position High nibble
        call    nout            ; write high nibble
        pop     ax
nout:   and     al,0x0F         ; mask low nibble
        daa                     ; divide by 10, AH=quotient, AL=remainder
        add     al,0xF0         ; propagate quotient into the Carry flag
        adc     al,0x40         ; form HEX digit
        jmp     putc            ; 'putc' does the return


msg_pause:
	db	NL,"Press any key to continue ...", NUL
pause:
	pushm	ax,si,ds
	push	cs
	pop	ds		; Set up DS:SI
	cnop			; Conditional NOP
	mov	si,msg_pause
	call	putstr
	call	getc
	call	crlf
	popm	ax,si,ds
	ret
