#ifndef __MYTYPES_H
#define __MYTYPES_H 1

typedef unsigned char  		byte;
typedef unsigned short int	word;
typedef unsigned long int	dword;

#define nelem(x) (sizeof(x)/sizeof(x[0]))

#ifndef __TIMESTAMP__
#define __TIMESTAMP__ "Tue Jan 29 14:40:56 2013"
#endif

#ifndef NULL
#define NULL (void*)0ul
#endif

void lites(int);
void jleds(int);
void exit(int);
byte outp(word,byte);
word inp(word);

#endif  /* __MYTYPES_H */
