/* seg.c */

extern	int dev_serial[4];

int main(void)
{
	int a;
	a = dev_serial[0] + dev_serial[2];
	return a;
}
