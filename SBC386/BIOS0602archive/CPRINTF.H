#ifndef CPRINTF_H__
#define CPRINTF_H__ 1


int __cdecl cprintf(const char * fmt, ...);

#define printf cprintf
void pr_lic(void);
void VIDEO_putchar(int ch, int attr);
int KBD_getchar(void);


#endif
