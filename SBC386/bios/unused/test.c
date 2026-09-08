#include "mytypes.h"
#define XXX
#include "bda.h"

int ms;
int n;

extern byte* SecBuffer;
int goo(int);
byte *ebda_alloc(word nbytes);


int IDE_READ_SECTOR(byte ms,byte far *buf, dword lba,byte n)
{
	int j=goo((int)lba) - goo(n) + (int)buf[ms];

	return j;
}


int foo()
{
	int i;

	SecBuffer = ebda_alloc(512);

	SecBuffer[3] = 17;

	i=IDE_READ_SECTOR(ms, SecBuffer, 321321, n);
	return i+(int)SecBuffer[0];
}
