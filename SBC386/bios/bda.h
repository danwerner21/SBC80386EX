XXX

/* bda.h -- definitions of the BIOS Data Area at 0040:0000 (0x400)  */
#define BDA_segment 0x40

typedef struct _BDA {

/* first items at 0x40:0	*/

	word	serial_dev[4];	/* serial port device codes */
	word	parallel_dev[4];	/* printer port device codes */
	word	equip_flag;		/* int 12h equipment flags */
	byte	mfg_test;		/* initialization flags */
	word	memory_size;	/* base memory size in Kilowords (1024) */
	byte	mfg_err_flag;
	byte	mfg_err_flag2;

/* */
/* first Keyboard data area */

	byte	kbd_flag;	/* shift status &c. */
	byte	kbd_flag1;	/*  more  */
	byte	alt_input;	/* save alternate kbd entry code */
	word	buffer_head;
	word	buffer_tail;
/* */
	word	kbd_buffer[16];	/* buffer empty when  head==tail */

/* */
/* Diskette data area */

	byte	seek_status;	/* drive recalibration status */
					/* bits 3..0 drive must recalibrate before next seek */
	byte	motor_status;	/* bits 3..0 motor running */
					/* bit 7 current op is write */
	byte	motor_count;	/* timeout counter for motor turn-off */
	byte	fd_status;	/* return code status byte */
	byte	fd_ctrl_stat[7];	/* controller return bytes */

/* */
/* Video Display data area -- also used for video emulation */

	byte	vid_mode;	/* current display mode */
	word	vid_columns;	/* no. of columns on the screen */
	word	vid_buf_len;	/* length of video buffer in bytes */
	word	vid_start;	/* start address of screen regeneration (in vid buf) */
	word	vid_cursor[8];	/* cursor postition on up to 8 screens */
	word	vid_cursor_mode;
	byte	vid_active_page;
	word	vid_addr_chip;	/* I/O address for the video chip (6845,EGA,VGA) */
	byte	vid_crt_mode;	/* current setting of the 3x8 register ???? */
	byte	vid_palette;	/* current color setting / palette  */

/* */
/* POST and ROM data */
	dword	io_rom_addr;	/* far word to ROM initialization routine */
#define io_rom_addr_low io_rom_addr
#define io_rom_addr_seg (io_rom_addr+2)
	byte	interrupt_flag;	/* indicates an interrupt occurred */

/* */
/* Timer data area  18.206602 hz  = ~54.925 ms  */
	word	timer_count_low;	/* low word of timer count */
	word	timer_count_high;
#define timer_count timer_count_low
/* use timer_count as the double word timer counter */
	byte	timer_overflow;	/* timer has rolled over since last read */

/* */
/* System & Keboard data area */

	byte	kbd_break_flag;	/* bit 7 set if Break key is pressed */
	word	reset_flag;	/* word=0x1234 if Reset is underway (80286) */

/* */
/* Fixed (Hard) disk data area */

	byte	hd_status;	/* status info for hard disk */
#define disk_status1 hd_status
	byte	hd_number;	/* number of hard disks (for int 13h, fn 8h) */
	byte	control_byte;	/* head control ???? */
	byte	port_offset;	/* obsolete, maybe ???? */

/* */
/* Timeout counters */
	byte	printer_timeout[4];	/* four bytes for each interface */
	byte	serial_timeout[4];	/* four bytes for each interface */

/* */
/* Keyboard additional data area -- buffer location within segment 40h */
	word	buffer_start;	/* offset of keyboard buffer start */
	word	buffer_end;		/* offset of end of kbd buffer */

/* */
/* EGA/PGA? data work area (graphic mode?  probably available) */

	byte	ega_rows;		/* rows on the active screen (less 1) */
	word	ega_points;		/* bytes per character	*/
	byte	ega_info;		/* mode options ???? */
	byte	ega_info_3;		/* switch settings */
	byte	ega_rsvd[2];	/* reserved for adapter mfgrs */

/* */
/* Disk / Diskette media data */

	byte	fd_last_data_rate;	/* last data rate selected */
	byte	hd_status_reg;		/* hard disk status register */
	byte	hd_error_reg;		/* hard disk error register */
	byte	hd_int_flag;	/* HD interrupt flag */
	byte	hd_cntrl;		/* HD/FD combo controller bit flag */
	byte	hd_media[2];	/* media state */
	byte	hd_op_start[2];	/* operation start state */
	word	hd_track;		/* HD present cylinder number */

/* */
/* Additional Keyboard flags */

	byte	kbd_flag3;	/* mode state & type flags */
	byte	kbd_flag2;	/* kbd LED flags */

/* */
/* Real Time Clock data area */

	dword	rtc_user_flag_addr;	/* far address of user's wait flag */
	dword	rtc_user_wait_flag;	/* user wait flag */
	byte	rtc_wait_active;	/* 01=busy, 80=posted, 00=post acknowledge */

/* */
/* Miscellaneous */
	byte	rsvd_network[7];	/* reserved for network adapters */
	dword	ptr_ega_save;		/* far pointer to EGA parameter control block */

/* */
/*	byte	rsvd_unused[84];	/* reserved for 386EX usage */
	word	errno;				/* library error flag (errno.h) */
	byte	rsvd_unused[41];	/* reserved for 386EX usage */
	byte	serial_flags[4];	/* flags for each serial device */
	word	extended_memory;	/* size of Extended Memory in Kilobytes */
			/* this size is stored in CMOS on the PC/AT */
	word	CPU_freq;	/* CPU frequency in kilohertz */
	word	ebda_seg_ptr;		/* for EBDA allocations; c.f., memory_size */
/* */
 /* start of 31 bytes of NVRAM information */
	byte	nvram_info[2];	/* 31 bytes of NVRAM information (this may move) */
							/* starts with 2 bytes of SIO0 params */
	byte	floppy_tab[2];		/* floppy disk driver table */
	byte	disk_tab[8];  		/* hard disk driver table */
	byte	nvram_unused[17];
	word	nvram_checksum;	/* 31st byte of the NVRAM info */
 /* end of 31 bytes of NVRAM information */
/* */
	byte	AT_status_byte;	/* at 40:100h, 00500h, Print Screen Status byte */
					/* 00=ready/ok  01=busy  0FF=error	*/
	byte	SRAM_size;	/* size of SRAM in Kilobytes */
/* */
/* Extentsion to BDA during BIOS startup */
/* */
} T_BDA;
