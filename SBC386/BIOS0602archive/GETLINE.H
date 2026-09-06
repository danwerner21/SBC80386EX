#ifndef GETLINE_H__
#define GETLINE_H__ 1
#include "ascii.h"
#include "cprintf.h"

#define putchar(x) VIDEO_putchar((x),7)
#define getchar(x) KBD_getchar()

int is_print(int ch);
void putline(char *str);
int getline(char *buffer, int length);



#endif
