#define REMAPCFGH        0x0023

#define REMAPCFGL        0x0022

#define REMAPCFG         0x0022

#define PORT92           0xF092

#define PORT92_AT        0x0092

#define DMA0TAR          0xF000

#define DMA0TAR_AT       0x0000

#define DMA0BYC          0xF001

#define DMA0BYC_AT       0x0001

#define DMA1TAR          0xF002

#define DMA1TAR_AT       0x0002

#define DMA1BYC          0xF003

#define DMA1BYC_AT       0x0003

#define DMACMD1          0xF008

#define DMACMD1_AT       0x0008

#define DMASTS           0xF008

#define DMASTS_AT        0x0008

#define DMASRR           0xF009

#define DMASRR_AT        0x0009

#define DMAMSK           0xF00A

#define DMAMSK_AT        0x000A

#define DMAMOD1          0xF00B

#define DMAMOD1_AT       0x000B

#define DMACLRBP         0xF00C

#define DMACLRBP_AT      0x000C

#define DMACLR           0xF00D

#define DMACLR_AT        0x000D

#define DMACLRMSK        0xF00E

#define DMACLRMSK_AT     0x000E

#define DMAGRPMSK        0xF00F

#define DMAGRPMSK_AT     0x000F

#define DMA0REQ0_1       0xF010

#define DMA0REQ2_3       0xF011

#define DMA1REQ0_1       0xF012

#define DMA1REQ2_3       0xF013

#define DMABSR           0xF018

#define DMACHR           0xF019

#define DMAIS            0xF019

#define DMACMD2          0xF01A

#define DMAMOD2          0xF01B

#define DMAIEN           0xF01C

#define DMAOVFE          0xF01D

#define DMACLRTC         0xF01E

#define DMA1TAR2         0xF083

#define DMA1TAR2_AT      0x0083

#define DMA1TAR3         0xF085

#define DMA1TAR3_AT      0x0085

#define DMA0TAR3         0xF086

#define DMA0TAR3_AT      0x0086

#define DMA0TAR2         0xF087

#define DMA0TAR2_AT      0x0087

#define DMA0BYC2         0xF098

#define DMA1BYC2         0xF099

#define ICW1M_AT         0x0020

#define ICW2M_AT         0x0021

#define ICW3M_AT         0x0021

#define ICW4M_AT         0x0021

#define OCW1M_AT         0x0021

#define OCW2M_AT         0x0020

#define OCW3M_AT         0x0020

#define ICW1M            0xF020

#define ICW2M            0xF021

#define ICW3M            0xF021

#define ICW4M            0xF021

#define OCW1M            0xF021

#define OCW2M            0xF020

#define OCW3M            0xF020

#define IRR_M	 	0xF020

#define ICW1S_AT         0x00A0

#define ICW2S_AT         0x00A1

#define ICW3S_AT         0x00A1

#define ICW4S_AT         0x00A1

#define OCW1S_AT         0x00A1

#define OCW2S_AT         0x00A0

#define OCW3S_AT         0x00A0

#define IRR_M_AT	 	0x00A0

#define ICW1S            0xF0A0

#define ICW2S            0xF0A1

#define ICW3S            0xF0A1

#define ICW4S            0xF0A1

#define OCW1S            0xF0A1

#define OCW2S            0xF0A0

#define OCW3S            0xF0A0

#define    TMR0          0xF040

#define    TMR0_AT       0x0040

#define    TMR1          0xF041

#define    TMR1_AT       0x0041

#define    TMR2          0xF042

#define    TMR2_AT       0x0042

#define    TMRCON        0xF043

#define    TMRCON_AT     0x0043

#define    CS0ADL        0xF400

#define    CS0ADH        0xF402

#define    CS0MSKL       0xF404

#define    CS0MSKH       0xF406

#define    CS1ADL        0xF408

#define    CS1ADH        0xF40A

#define    CS1MSKL       0xF40C

#define    CS1MSKH       0xF40E

#define    CS2ADL        0xF410

#define    CS2ADH        0xF412

#define    CS2MSKL       0xF414

#define    CS2MSKH       0xF416

#define    CS3ADL        0xF418

#define    CS3ADH        0xF41A

#define    CS3MSKL       0xF41C

#define    CS3MSKH       0xF41E

#define    CS4ADL        0xF420

#define    CS4ADH        0xF422

#define    CS4MSKL       0xF424

#define    CS4MSKH       0xF426

#define    CS5ADL        0xF428

#define    CS5ADH        0xF42A

#define    CS5MSKL       0xF42C

#define    CS5MSKH       0xF42E

#define    CS6ADL        0xF430

#define    CS6ADH        0xF432

#define    CS6MSKL       0xF434

#define    CS6MSKH       0xF436

#define    UCSADL        0xF438

#define    UCSADH        0xF43A

#define    UCSMSKL       0xF43C

#define    UCSMSKH       0xF43E

#define    SSIOTBUF      0xF480

#define    SSIORBUF      0xF482

#define    SSIOBAUD      0xF484

#define    SSIOCON1      0xF486

#define    SSIOCON2      0xF488

#define    SSIOCTR       0xF48A

#define    RFSBAD        0xF4A0

#define    RFSCIR        0xF4A2

#define    RFSCON        0xF4A4

#define    RFSADD        0xF4A6

#define    WDTRLDH       0xF4C0

#define    WDTRLDL       0xF4C2

#define    WDTCNTH       0xF4C4

#define    WDTCNTL       0xF4C6

#define    WDTCLR        0xF4C8

#define    WDTSTATUS     0xF4CA

#define    PWRCON        0xF800

#define    CLKPRS        0xF804

#define    P1CFG         0xF820

#define    P2CFG         0xF822

#define    P3CFG         0xF824

#define    PINCFG        0xF826

#define    DMACFG        0xF830

#define    INTCFG        0xF832

#define    TMRCFG        0xF834

#define    SIOCFG        0xF836

#define    P1PIN         0xF860

#define    P1LTC         0xF862

#define    P1DIR         0xF864

#define    P2PIN         0xF868

#define    P2LTC         0xF86A

#define    P2DIR         0xF86C

#define    P3PIN         0xF870

#define    P3LTC         0xF872

#define    P3DIR         0xF874

#define    BIT0          0x01

#define    BIT1          0x02

#define    BIT2          0x04

#define    BIT3          0x08

#define    BIT4          0x10

#define    BIT5          0x20

#define    BIT6          0x40

#define    BIT7          0x80

#define    BIT8          0x0100

#define    BIT9          0x0200

#define    BIT10         0x0400

#define    BIT11         0x0800

#define    BIT12         0x1000

#define    BIT13         0x2000

#define    BIT14         0x4000

#define    BIT15         0x8000

#define    ZBIT0          0

#define    ZBIT1          0

#define    ZBIT2          0

#define    ZBIT3          0

#define    ZBIT4          0

#define    ZBIT5          0

#define    ZBIT6          0

#define    ZBIT7          0

#define    ZBIT8          0

#define    ZBIT9          0

#define    ZBIT10         0

#define    ZBIT11         0

#define    ZBIT12         0

#define    ZBIT13         0

#define    ZBIT14         0

#define    ZBIT15         0

#define    RBR0_F4       0xF4F8

#define    TBR0_F4       0xF4F8

#define    DLL0_F4       0xF4F8

#define    DLH0_F4       0xF4F9

#define    IER0_F4       0xF4F9

#define    IIR0_F4       0xF4FA

#define    LCR0_F4       0xF4FB

#define    MCR0_F4       0xF4FC

#define    LSR0_F4       0xF4FD

#define    MSR0_F4       0xF4FE

#define    SCR0_F4       0xF4FF

#define MFPIC 0
#if MFPIC
#define    RBR0          0x0448

#define    TBR0          0x0448

#define    DLL0          0x0448

#define    DLH0          0x0449

#define    IER0          0x0449

#define    IIR0          0x044A

#define    LCR0          0x044B

#define    MCR0          0x044C

#define    LSR0          0x044D

#define    MSR0          0x044E

#define    SCR0          0x044F

#else
#define    RBR0          0x03F8

#define    TBR0          0x03F8

#define    DLL0          0x03F8

#define    DLH0          0x03F9

#define    IER0          0x03F9

#define    IIR0          0x03FA

#define    LCR0          0x03FB

#define    MCR0          0x03FC

#define    LSR0          0x03FD

#define    MSR0          0x03FE

#define    SCR0          0x03FF

#endif


#define    RBR1_F8       0xF8F8

#define    TBR1_F8       0xF8F8

#define    DLL1_F8       0xF8F8

#define    DLH1_F8       0xF8F9

#define    IER1_F8       0xF8F9

#define    IIR1_F8       0xF8FA

#define    LCR1_F8       0xF8FB

#define    MCR1_F8       0xF8FC

#define    LSR1_F8       0xF8FD

#define    MSR1_F8       0xF8FE

#define    SCR1_F8       0xF8FF

#define    RBR1          0x02F8

#define    TBR1          0x02F8

#define    DLL1          0x02F8

#define    DLH1          0x02F9

#define    IER1          0x02F9

#define    IIR1          0x02FA

#define    LCR1          0x02FB

#define    MCR1          0x02FC

#define    LSR1          0x02FD

#define    MSR1          0x02FE

#define    SCR1          0x02FF

#define    LSR_TE        BIT6

#define    LSR_TBE       BIT5

#define    LSR_BI        BIT4

#define    LSR_FE        BIT3

#define    LSR_PE        BIT2

#define    LSR_OE        BIT1

#define    LSR_RBF       BIT0

#define    CR0_PE        BIT0

#define    CR0_MP        BIT1

#define    CR0_EM        BIT2

#define    CR0_TS        BIT3

#define    ASCII_NUL             0x00

#define    ASCII_BS              0x08

#define    ASCII_HT              0x09

#define    ASCII_LF              0x0A

#define    ASCII_NL              0x0A

#define    ASCII_FF              0x0C

#define    ASCII_CR              0x0D

#define	ASCII_ESC	 	0x1B

#define    ASCII_SP              0x20

#define    ASCII_DEL             0x7F

#define	ASCII_RUB	 	0xFF
