/* hex2bin.c -- yet another reader and writer of Intel hex files 
   Copyright (C) 2011 John R Coffman <johninsd@gmail.com>.
***********************************************************************
   When invoked as 'hex2bin' read a sequence of Intel hex files
   and create an overlaid binary file.

   When invoked as 'bin2hex' read a binary file and create an
   Intel hex file.

   All command line numeric constants may be specified in any
   radix.
***********************************************************************

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    in the file COPYING in the distribution directory along with this
    program.  If not, see <http://www.gnu.org/licenses/>.

**********************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "mytypes.h"

#ifndef min
#define min(a,b) ((a)<(b)?(a):(b))
#endif
#define true   1
#define false  0
#define SEG_MASK 0x00FFFFu
#define LBA_MASK 0x00FF0000ul
#define MAX_MASK (LBA_MASK|SEG_MASK)
#define ONE_MEG 0x100000ul
#define CRC2 2
#define CRC1 1
#define CRC16 3

dword upper_lba = 0;     /* upper address */
dword address_mask = SEG_MASK;  /* address mask  */
byte pad = 0xFF;
byte *buffer;
dword rom_size = 0;
dword crc_addr;
dword overwrite;     /* count of possible overwrites */
byte h2b, verbose, segmented, crc;
char *outfilename = NULL;
char *binfilename = NULL;
dword source_address, source_limit;
dword dest_address, dest_limit;
FILE *infile;
FILE *outfile;
byte checksum;
char line[1024];
char *lp;
long int lineno;


#if 1
static
const word crc16tab[] = {
  	0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7,
  	0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF,
  	0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6,
  	0x9339, 0x8318, 0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE,
  	0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4, 0x5485,
  	0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D,
  	0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4,
  	0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC,
  	0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
  	0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B,
  	0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12,
  	0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A,
  	0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,
  	0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49,
  	0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13, 0x2E32, 0x1E51, 0x0E70,
  	0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78,
  	0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F,
  	0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,
  	0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E,
  	0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,
  	0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D,
  	0x34E2, 0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
  	0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E, 0xC71D, 0xD73C,
  	0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634,
  	0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB,
  	0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,
  	0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,
  	0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92,
  	0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9,
  	0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1,
  	0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,
  	0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0,
};
#endif


/* return updated CRC word after processing buffer of bytes */
word crc16_big(byte *buffer, dword count, word crc)
{
	do {
		crc = (crc << 8) ^ crc16tab[ (crc>>8) ^ (word)*buffer++ ];
	} while (--count);
	return crc;
}



dword convert_constant(char *str)
{
   char *final;
   dword value = strtoul(str, &final, 0);

   if (*final == 'k' || *final == 'K') value *= 1024ul;
   else if (*final == 'M' || *final == 'm') value *= ONE_MEG;

   return value;
}

void error(byte level, char *msg)
{
   printf("%s(%d): %s\n",
         level>1 ? "Error" : "Warning", (int)level, msg);
   if (level>1) exit(level);
   else if (level==0) printf("line %ld  %s", lineno, line);
}


int getnibble(void)
{
   char ch;

	ch = -1;
   if (lp) {
      ch = *lp++;
      if (ch>='0' && ch<='9') ch -= '0';
      else if (ch>='A' && ch<='F') ch -= 'A'-10;
      else if (ch>='a' && ch<='f') ch -= 'a'-10;
      else {
         error(0,"Illegal hex digit");
         ch = -1;
      }
   }
   else error(0,"Line is too short");
   return (int)ch;
}

int getbyte(void)
{
   int b = getnibble();
   b <<= 4;
   b += getnibble();
   checksum += b;
   return b;
}

int getword(void)
{
   int w = getbyte();
   w <<= 8;
   w += getbyte();
   return w;
}

dword getdword(void)
{
   dword d = getword();
   d <<= 16;
   d += getword();
   return d;
}

/* added for SREC files */
dword get6word(void)
{
   dword d = getword();
   d <<= 8;
   d += getbyte();
   return d;
}


void putbyte(dword address, byte data)
{
   if (address < source_address  ||  address > source_limit) return;
   address -= source_address;
   address += dest_address;
   if (address > dest_limit) return;
   if (address >= rom_size) {
      printf("Line %ld ", lineno); error(2,"Data beyond end of ROM");
   }
   if (buffer[address] != pad) {
      overwrite++;
      if (verbose || overwrite<=100) printf("Warning(1): Overwrite at ROM address 0x%lX\n", address);
   }
   buffer[address] = data;
}


void usage(void)
{
   printf("hex2bin.c (bin2hex) -- " __TIMESTAMP__ ".\n"
          "Copyright (c) 2011 John R Coffman. All rights reserved.\n"
          "Distributed under the GNU General Public License, a copy of which\n"
          "is contained in the file COPYING in the distribution directory.\n\n");
   if (h2b) printf(
   "Usage:\n"
   "    hex2bin <options> [<flags> <filename>[/M]]+\n\n"
   "    Options:\n"
   "        -c[<option>]  option is 1, 2, 16  default is 2's complement\n"
   "        -o <output filename>\n"
   "        -p <pad byte>\n"
   "        -R <ROM size> default 64K\n"
   "        -v [<verbosity level>]\n"
   "    Flags:\n"
   "        -d <destination address in BIN file>\n"
   "        -D <destination limit in BIN file>\n"
   "        -s <source address in HEX file>\n"
   "        -S <source limit in HEX file>\n"
	"    Suffix:\n"
	"        /M marks a Motorola S-record input file\n"
   );
   else printf(
   "Usage:\n"
   "    bin2hex <options> [<flags> <filename>]+\n\n"
   "    Options:\n"
   "        -c[<option>]  option is 1, 2, 16  default is 2's complement\n"
   "        -g use Intel seGmented addressing\n"
   "        -o <output filename>\n"
   "        -p <pad byte>\n"
   "        -R <ROM size> default 1024K\n"
   "        -v [<verbosity level>]\n"
   "    Flags:\n"
   "        -d <destination address in HEX file>\n"
   "        -D <destination limit in HEX file>\n"
   "        -s <source address in BIN file>\n"
   "        -S <source limit in BIN file>\n"
   );
}


void hout_byte(byte data)
{
   checksum -= data;
   fprintf(outfile, "%02X", (int)data);
}
void hout_word(word data)
{
   hout_byte(data>>8);
   hout_byte(data);
}
void begin_record(byte length)
{
   checksum = 0;
   fputc(':', outfile);
   hout_byte(length);
}
void end_record(void)
{
   hout_byte(checksum);
   fputc('\n', outfile);
}

void write_lba(dword address)
{
   if (verbose==5) printf("Address: %06lX\n", address);

   if ((address & LBA_MASK) != upper_lba) {
      upper_lba = address & LBA_MASK;
      begin_record(2);
      hout_word(0);
      if (rom_size > ONE_MEG || !segmented) {
         hout_byte(4);     /* linear address */
         hout_word(upper_lba>>16);
      }
      else {   /* handle ROMs 1meg and smaller */
         hout_byte(2);     /* segment address */
         hout_word(upper_lba>>4);
      }
      end_record();
   }
}

void write_data(word nbytes, byte *buf, dword address)
{
   /* compress from the high end */
   while (nbytes && buf[nbytes-1]==pad) --nbytes;
   /* compress from the low end */
   while (nbytes && *buf==pad) {
      ++buf;
      ++address;
      --nbytes;
   }
   if (nbytes) {
      write_lba(address);
      begin_record(nbytes);
      hout_word(address & 0xFFFFu);
      hout_byte(0);     /* data record */
      while(nbytes--) hout_byte(*buf++);
      end_record();
   }
}

#define NREC 16

void write_hex_file(FILE *outfile)
{
   dword nbytes;
   dword vaddr;
   dword n;
   byte *buf;

   buf = buffer;
   vaddr = 0;
   nbytes = rom_size;
   n = min(nbytes, NREC);
   do {
      write_data(n, buf, vaddr);
      buf += n;
      vaddr += n;
      nbytes -= n;
      n = min(nbytes, NREC);
   } while (n);
/* write the end-of-file record */
   fprintf(outfile,":00000001FF\n");
}


void scan_bin_file(char *filename)
{
   dword length;
   dword nbytes;
   int data;
   dword inaddr;

   infile = fopen(filename, "rb");
   if (!infile) {
      strcpy(line,"Cannot find file: ");
      error(5, strcat(line, filename));
   }
/***   length = filelength(fileno(infile));    ***/
   fseek(infile, 0L, SEEK_END);
   length = ftell(infile);
/***/
   nbytes = 0;
   inaddr = dest_address;
   if (source_address < length) {
      fseek(infile, source_address, SEEK_SET);
      while (inaddr<rom_size && inaddr<=dest_limit) {
         data = fgetc(infile);
         if (data == EOF) break;
         buffer[inaddr++] = data;
      }
   }

   fclose(infile);
}

void scan_srec_file(char *filename)
{
   byte ldata;
   dword laddr;
   byte rectype;
   dword index;
   byte data;
   byte EndOfFile = 0;

   infile = fopen(filename, "rt");
   if (!infile) {
      strcpy(line,"Cannot find file: ");
      error(5, strcat(line, filename));
   }
   lineno = 0;
	laddr = 0;
   do {
      lineno++;
      lp = fgets(line, nelem(line)-1, infile);
      if (lp == NULL) break;
      if (*lp++ != 'S') {
         printf("Illegal: %s",--lp);
         continue;
      }
      if (verbose>=3) printf("%s", lp-1);
      checksum = 0;
      rectype = getnibble();
      ldata = getbyte();
		switch(rectype) {		/* get variable address field */
			case 0:
			case 1:
			case 5:
			case 9:
				laddr = getword();
				ldata -= 2;
				break;
			case 2:
			case 8:
				laddr = get6word();
				ldata -= 3;
				break;
			case 3:
			case 7:
				laddr = getdword();
				ldata -= 4;
				break;
			default:
            error(0,"Unknown record type:");
		}
		if (rectype>=1 && rectype<=3) {
         index = 0;
         while (--ldata) {
            data = getbyte();
					/* no address mask used */
            putbyte(laddr + index, data);
            index++;
         }
		}
		else if (rectype==0) {
			printf("Comment: ");
			while (--ldata) {
				printf("%c", (char)getbyte());
			}
			printf("\n");
		}
	/* else  records 5,7,8,9 are ignored */

      data = getbyte();           /* get final checksum */
      if (checksum != 0xFF) {
         error(0,"Checksum failure");
      }
   } while (lp && !EndOfFile);
   fclose(infile);
}

void scan_Intel_file(char *filename)
{
   byte ldata;
   dword laddr;
   byte rectype;
   dword value;
   dword index;
   byte data;
   byte EndOfFile = 0;

   infile = fopen(filename, "rt");
   if (!infile) {
      strcpy(line,"Cannot find file: ");
      error(5, strcat(line, filename));
   }
   upper_lba = 0;
   lineno = 0;
   do {
      lineno++;
      lp = fgets(line, nelem(line)-1, infile);
      if (lp == NULL) break;
      if (*lp++ != ':') {
         printf("Comment: %s",--lp);
         continue;
      }
      if (verbose>=3) printf("%s", lp-1);
      checksum = 0;
      ldata = getbyte();
      laddr = getword();
      rectype = getbyte();
      switch (rectype) {
         case 0:                 /* data record */
            index = 0;
            while (ldata--) {
               data = getbyte();
               putbyte(upper_lba + ((laddr + index)&address_mask), data);
               index++;
            }
            break;
         case 1:                 /* end of file record */
            EndOfFile = 1;
            break;
         case 2:                 /* segment address */
            address_mask = SEG_MASK;
            value = getword();
            upper_lba = value<<4;   /* start of segment */
            ldata -= 2;
            break;
         case 4:                 /* linear upper address */
            address_mask = MAX_MASK;
            value = getword();
            upper_lba = value<<16;  /* full 32-bit address range */
            ldata -= 2;
            break;
         case 3:                 /* start CS:IP */
         case 5:                 /* linear start address */
            value = getdword();
            ldata -= 4;
				break;
         default:
            error(0,"Unknown record type:");
      }
      getbyte();           /* get final checksum */
      if ( (checksum & 0xFF) ) {
         error(0,"Checksum failure");
      }
   } while (lp && !EndOfFile);
   fclose(infile);
}


void scan_hex_file(char *filename)
{
	int i = strlen(filename);

	if (i>3  &&  filename[i-2]=='/'
			&& (filename[i-1]=='M') )   {
		filename[i-2] = 0;		/* remove suffix */
		scan_srec_file(filename);
	}
	else scan_Intel_file(filename);
}


void global_options(int argc, char *argv[])
{
   int iarg;
   char *cp;
   char *tp;
   char ch;
   int i;

   h2b = false;
   crc = false;			/* normally no CRC's */
   crc_addr = -1;		/* impossible flag */
   rom_size = ONE_MEG;     /* bin2hex default value */
/* decide which conversion to do */
   if (strstr(argv[0],"hex2bin")
#ifdef   MSDOS
         || strstr(argv[0],"HEX2BIN")
#endif
      ) {
         h2b = true;
         rom_size = 64 * 1024ul; /* default value */
   }  /* assume 'bin2hex' otherwise */
      
   if (argc<2) { usage(); exit(0); }

/* scan the global command line options */
   for (iarg = 0; iarg<argc; iarg++) {
      cp = argv[iarg];
      if (*cp == '-'
#ifdef   MSDOS
                  || *cp == '/'
#endif
                                 ) {
         ch = cp[1];
         tp = cp + 2;
         switch (ch) {
		 	case 'c': 			/* some CRC option */
				i = 2;
				crc = CRC2;		/* default is 2's complement */
				if (cp[2] == '2') crc = CRC2;
				else if (cp[2] == '0') crc = 0;
				else if (cp[2] == '1') {
					if (cp[3] == '6') {
						crc = CRC16;
						i++;
					}
					else crc = CRC1;
				}
				if (crc) i++;
				if (cp[i] == '=') {
					crc_addr = strtoul(cp+i+1, NULL, 0) & (rom_size-1);
					if (crc_addr > rom_size-2)
						error(5,"CRC word placement illegal");
				}
               	*cp = *tp = 0;
				break;
            case 'g':
               segmented = 1;    /* enable segmented addressing */
               break;            /* for ROMs <= 1M in size      */
            case 'h':
               usage();
               exit(0);
            case 'o':   /* outfile name specification */
               if (!*tp) tp = argv[++iarg];
               outfilename = strdup(tp);
               *cp = *tp = 0;
               break;
            case 'p':   /* specify the pad byte */
               if (!*tp) tp = argv[++iarg];
               pad = (byte)convert_constant(tp);
               *cp = *tp = 0;
               break;
            case 'R':   /* ROM file size specification */
               if (!*tp) tp = argv[++iarg];
               rom_size = convert_constant(tp);
               if (rom_size > MAX_MASK+1) error(5, "ROM size too big");
               if (rom_size < 256) error(5, "ROM size too small");
               *cp = *tp = 0;
               break;
            case 'v':   /* print verbose statistics */
               verbose++;
               if (!*tp) tp = argv[++iarg];
               if (*tp>='1' && *tp<='5' && tp[1]==0) verbose += (*tp - '1');
               else tp = cp;
               *cp = *tp = 0;
               break;
            case 'Y': {
                  int i;
                  for (i=0; i<argc; i++)
                     printf(" %s", argv[i]);
                  printf("\n");
                  exit(0);
               }
            default:
               break;
         }
      }  // if '-'
   }  // for (iarg ...
}


void process_cmd_input(int argc, char *argv[])
{
   int iarg;
   char *cp;
   char *tp;

   source_address = dest_address = 0;
   source_limit = dest_limit = MAX_MASK;

   for (iarg=1; iarg<argc; iarg++) {
      cp = argv[iarg];
      if (*cp == '-'
#ifdef   MSDOS
                  || *cp == '/'
#endif
                                 ) {
         ++cp;
         tp = cp + 1;
         switch (*cp) {
            case 's':            /* source */
               if (!*tp) tp = argv[++iarg];
               source_address = convert_constant(tp);
               break;
            case 'S':            /* source limit */
               if (!*tp) tp = argv[++iarg];
               source_limit = convert_constant(tp);
               break;
            case 'd':            /* destination */
               if (!*tp) tp = argv[++iarg];
               dest_address = convert_constant(tp);
               break;
            case 'D':            /* destination limit */
               if (!*tp) tp = argv[++iarg];
               dest_limit = convert_constant(tp) - 1;
               break;
         } // switch
      }  // if (*cp == '-' ...
      else if (*cp) {            /* this must be a filename */
         if (h2b) scan_hex_file(cp);
         else scan_bin_file(cp);

      /* reset the local relocation options */
         source_address = 0;
         dest_address = 0;
         source_limit = MAX_MASK;
         dest_limit = MAX_MASK;
      }
   } // for (iarg
}



void crc_computation(byte crc)
{
	dword mask;
	dword index;
	dword temp;

/*	dword index = (crc_addr+2) & mask; */
	index = 0;

	if (crc == 0) return;
	temp = 0;
	mask = rom_size - 1;

	if (crc_addr == -1) crc_addr = rom_size - 2;
	index = (crc_addr + 2) & mask;

	if (crc <= CRC2)
		while (index != crc_addr) {
			temp += buffer[index];
			index = (index+1) & mask;
		}
	else {
		if (crc_addr + 2 < rom_size) {
			temp = crc16_big(&buffer[crc_addr+2], rom_size-(crc_addr+2), 0);
		}
		temp = crc16_big(buffer, crc_addr, temp);
	}
	/* CRC is stored BIG Endian!!! */
	if (crc == CRC1) {
		temp += (temp>>16);		/* account for end-around carrys */
		temp = ~temp;			/* negation in 1's complement */
	}
	else if (crc == CRC2) temp = -temp;

	temp &= 0xFFFF;
	buffer[crc_addr] = (byte)(temp>>8);
	buffer[crc_addr+1] = (byte)temp;
}



int main(int argc, char *argv[])
{
   dword index;
   byte *ptr;

   verbose = 0;
   global_options(argc, argv);
   
   buffer = (byte*)malloc(rom_size);
   if (!buffer) error(5,"Cannot allocate ROM buffer");
   for (ptr=buffer, index=rom_size; index; index--) *ptr++ = pad;

   process_cmd_input(argc, argv);

   if (!outfilename) {
      if (h2b) {
         outfilename = "out.bin";
      }
      else {
         outfilename = "out.hex";
      }
      error(1,"No output file specified");
      printf("Using file named '%s' for output\n", outfilename);
   }
   outfile = fopen(outfilename, h2b ? "wb" : "wt");
   if (!outfile) error(5,"Cannot create output file");

   crc_computation(crc);

   if (h2b) while (rom_size--) fputc(*buffer++, outfile);
   else write_hex_file(outfile);

   fclose(outfile);

   return EXIT_SUCCESS;
}

