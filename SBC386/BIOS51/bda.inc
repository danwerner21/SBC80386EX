XXX
; bda.h -- definitions of the BIOS Data Area at 0040:0000 (0x400)  */
%define BDA_segment 0x40
struc _BDA
; first items at 0x40:0	*/
serial_dev	resw	4	; serial port device codes */
parallel_dev	resw	4	; printer port device codes */
equip_flag	resw	1		; int 12h equipment flags */
mfg_test	resb	1		; initialization flags */
memory_size	resw	1	; base memory size in Kilowords (1024) */
mfg_err_flag	resb	1
mfg_err_flag2	resb	1
; */
; first Keyboard data area */
kbd_flag	resb	1	; shift status &c. */
kbd_flag1	resb	1	;  more  */
alt_input	resb	1	; save alternate kbd entry code */
buffer_head	resw	1
buffer_tail	resw	1
; */
kbd_buffer	resw	16	; buffer empty when  head==tail */
; */
; Diskette data area */
seek_status	resb	1	; drive recalibration status */
; bits 3..0 drive must recalibrate before next seek */
motor_status	resb	1	; bits 3..0 motor running */
; bit 7 current op is write */
motor_count	resb	1	; timeout counter for motor turn-off */
fd_status	resb	1	; return code status byte */
fd_ctrl_stat	resb	7	; controller return bytes */
; */
; Video Display data area -- also used for video emulation */
vid_mode	resb	1	; current display mode */
vid_columns	resw	1	; no. of columns on the screen */
vid_buf_len	resw	1	; length of video buffer in bytes */
vid_start	resw	1	; start address of screen regeneration (in vid buf) */
vid_cursor	resw	8	; cursor postition on up to 8 screens */
vid_cursor_mode	resw	1
vid_active_page	resb	1
vid_addr_chip	resw	1	; I/O address for the video chip (6845,EGA,VGA) */
vid_crt_mode	resb	1	; current setting of the 3x8 register ???? */
vid_palette	resb	1	; current color setting / palette  */
; */
; POST and ROM data */
io_rom_addr	resd	1	; far word to ROM initialization routine */
%define io_rom_addr_low io_rom_addr
%define io_rom_addr_seg (io_rom_addr+2)
interrupt_flag	resb	1	; indicates an interrupt occurred */
; */
; Timer data area  18.206602 hz  = ~54.925 ms  */
timer_count_low	resw	1	; low word of timer count */
timer_count_high	resw	1
%define timer_count timer_count_low
; use timer_count as the double word timer counter */
timer_overflow	resb	1	; timer has rolled over since last read */
; */
; System & Keboard data area */
kbd_break_flag	resb	1	; bit 7 set if Break key is pressed */
reset_flag	resw	1	; word=0x1234 if Reset is underway (80286) */
; */
; Fixed (Hard) disk data area */
hd_status	resb	1	; status info for hard disk */
%define disk_status1 hd_status
hd_number	resb	1	; number of hard disks (for int 13h, fn 8h) */
control_byte	resb	1	; head control ???? */
port_offset	resb	1	; obsolete, maybe ???? */
; */
; Timeout counters *;
printer_timeout	resb	4
serial_timeout	resb	4	; one byte for each interface */
; */
; Keyboard additional data area -- buffer location within segment 40h */
buffer_start	resw	1	; offset of keyboard buffer start */
buffer_end	resw	1		; offset of end of kbd buffer */
; */
; EGA/PGA? data work area (graphic mode?  probably available) */
ega_rows	resb	1		; rows on the active screen (less 1) */
ega_points	resw	1		; bytes per character	*/
ega_info	resb	1		; mode options ???? */
ega_info_3	resb	1		; switch settings */
ega_rsvd	resb	2	; reserved for adapter mfgrs */
; */
; Disk / Diskette media data */
fd_last_data_rate	resb	1	; last data rate selected */
hd_status_reg	resb	1		; hard disk status register */
hd_error_reg	resb	1		; hard disk error register */
hd_int_flag	resb	1	; HD interrupt flag */
hd_cntrl	resb	1		; HD/FD combo controller bit flag */
hd_media	resb	2	; media state */
hd_op_start	resb	2	; operation start state */
hd_track	resb	2	; HD present cylinder number */
; */
; Additional Keyboard flags */
kbd_flag3	resb	1	; mode state & type flags */
kbd_flag2	resb	1	; kbd LED flags */
; */
; Real Time Clock data area */
rtc_user_flag_addr	resd	1	; far address of user's wait flag */
rtc_user_wait_flag	resd	1	; user wait flag */
rtc_wait_active	resb	1	; 01=busy, 80=posted, 00=post acknowledge */
; */
; Miscellaneous */
rsvd_network	resb	7	; reserved for network adapters */
ptr_ega_save	resd	1		; far pointer to EGA parameter control block */
; */
;	byte	rsvd_unused[84];	; reserved for 386EX usage */
extended_memory	resw	1	; size of Extended Memory in Kilobytes */
; this size is stored in CMOS on the PC/AT */
rsvd_unused	resb	72	; reserved for 386EX usage */
disk_tab	resb	8  		; hard disk driver table */
floppy_tab	resb	2		; floppy disk driver table */
; */
AT_status_byte	resb	1	; at 40:100h, 00500h, Print Screen Status byte */
; 00=ready/ok  01=busy  0FF=error	*/
; */
; Extentsion to BDA during BIOS startup */
SRAM_size	resb	1	; size of SRAM in Kilobytes */
nvram_info	resb	31	; 31 bytes of NVRAM information (this may move) */
CPU_freq	resw	1	; CPU frequency in kilohertz */
; */
endstruc
