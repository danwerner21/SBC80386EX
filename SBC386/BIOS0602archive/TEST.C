#include "mytypes.h"

int ms;
int n;

extern byte* SecBuffer;
int goo(int);

int IDE_READ_SECTOR(byte ms,byte far *buf, dword lba,byte n) 
{
	int j=goo((int)lba) - goo(n) + (int)buf[ms];

	return j;
}


int foo()
{
	int i;
	i=IDE_READ_SECTOR(ms, SecBuffer, 321321, n);
	return i+(int)SecBuffer[0];
}
