/* trunc.c -- truncates a binary file
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

long size = 0;
char *outfilename = NULL;
char *binfilename = NULL;
FILE *infile;
FILE *outfile;

long convert_constant(char *);


void usage(void)
{
   printf("trunc.c\n"
          "Distributed under the GNU General Public License, a copy of which\n"
          "is contained in the file COPYING in the distribution directory.\n\n");
	printf(
   "Usage:\n"
   "    trunc <options> [<flags> <filename>]+\n\n"
   "    Options:\n"
   "        -o <output filename>\n"
   "    Flags:\n"
   "        -s <output file size>\n"
   );
}

long convert_constant(char *str)
{
   char *final;
   long value = strtoul(str, &final, 0);

   if (*final == 'k' || *final == 'K') value *= 1024ul;
   else if (*final == 'M' || *final == 'm') value *= 0x100000ul;

   return value;
}

void process_cmd_input(int argc, char *argv[])
{
   int iarg;
   char *cp;
   char *tp;


   for (iarg=1; iarg<argc; iarg++) {
      cp = argv[iarg];
      if (*cp == '-' || *cp == '/' ) {
         ++cp;
         tp = cp + 1;
         switch (*cp) {
            case 'h':
               usage();
               exit(0);
            case 'o':   /* outfile name specification */
               if (!*tp) tp = argv[++iarg];
               outfilename = strdup(tp);
               *cp = *tp = 0;
               break;
            case 's':            /* size */
               if (!*tp) tp = argv[++iarg];
               size = convert_constant(tp);
               break;
         } // switch
      }  // if (*cp == '-' ...      
   } // for (iarg
}





int main(int argc, char *argv[])
{
   long count=0;
   process_cmd_input(argc, argv);

 if (size==0) {
      size=1024;
      printf("No size specified\n");
      printf("Truncating at 1K\n");
   }



 if (!outfilename) {
      outfilename = "out.bin";
      printf("No output file specified\n");
      printf("Using file named '%s' for output\n", outfilename);
   }

 infile = fopen(argv[1], "rb");
   if (!infile) {
      printf("Cannot find file: %s \n",argv[1]);
	exit(99);
   }

  outfile = fopen(outfilename, "wb");
   if (!infile) {
      printf("Cannot create file: %s \n",outfilename);
	exit(99);
   }


   for(count=0;count<size;count++)
		fputc(fgetc(infile),outfile);

   fclose(infile);
   fclose(outfile);

   return EXIT_SUCCESS;
}

