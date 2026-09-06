/*
 **************************************************************************
 *
 * Utility program to optimize the output of the BCC compiler
 *
 * Module:  copt.c
 * Purpose: Optimize BCC assembler output
 * Entries: main
 *
 * This program is based on an idea from Christopher W. Fraser.
 *
 **************************************************************************
 *
 * Copyright (C) 1995,1996,1997 Gero Kuhlmann <gero@gkminix.han.de>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */
/***
	March 2018 -- John Coffman <johninsd@gmail.com>

	1. Change the COPT comment character from '#' to '!'



	March 2005 -- John Coffman <johninsd@san.rr.com>
	
	1. Fix pointer handling so that rules with null replacements
	can actually delete lines.
	2. Implement the label operations: '-L' switch turns them on;
	then the %@n (n=0..9) conditional match is effective (see below).
	3. Fix the 'eval()' logic so that it works. All that was needed
	was to remove the global variables; the logic is recursive so
	'num' and 'retval' have to be in the stack.
	4. Change to eval match of hexadecimal constants. They are prefixed
	with a (variable) string. BCC uses "$"; LCC targeting x86/nasm uses
	"0x". Perhaps a switch is needed to place this on the command line,
	with the BCC "$" being the default.
	
 ***/
/*************************************************************************

	Label operations were implemented to allow 'copt' to optimize
	output from LCC 4.2 targeted to the NASM assembler for x86.
	
	Label operations are initiated with the '-Lpattern' switch, which
	defines the format of compiler generated labels in terms of a
	prefix, a number, and an optional suffix.  For instance, the
	command line switch:  -L_.L9999_ defines the label prefix as the
	string "_.L", the suffix as "_", and the numeric part provides
	for a table of up to 9999 labels.  The input is scanned, and the
	number of appearances of each label is noted.  Of particular
	interest are labels which occur only once (orphans), and labels
	which occur only twice.  Knowledge of the last allows intelligent
	optimiztion which removes labels, knowing that they are not 
	referenced anywhere else.
	
	Just as '%0' matches any string in the pattern, the special
	character '@' before the digit indicates matching a label which
	adheres to the "-Lpattern", and which occurs in the input file
	only as many times as the wildcard match occurs in the rule pattern.
	If no -L occurred on the command line, 	the match will always fail.
	The '@' special character is used only on the LAST occurrence of 
	the label wildcard match in the rule pattern.  If '%4' occurs once
	at the beginning of the rule pattern, and the final occurrence of
	wildcard '4' is '%@4', then the rule pattern is only matched if the
	'%@4' references a label in the format of the command line '-L'
	switch, and the label is referenced only twice in the entire source
	file.
	
	For example, the 'copt' rule:
	
	%@1:
	=
	
	
	will remove orphan labels; i.e., those which occur only once.
	
	The rule:
	
	jn%0 %1
	jmp %2  
	%@1:
	=
	j%0 %2

	will change the sense of a branch condition, and remove the label
	which matches '%1', since the final match of '%@1' is conditioned
	upon the occurence of the '%1' pattern twice only in the entire
	input file.  Thus it is known that it is completely safe to remove
	the reference to label '%1'.
	
	Note that the initial '%1' will always match; but if the label is
	referenced anywhere else in the file besides the label definition
	line, '%@1:', the second match will fail because the '%1' pattern
	occurs only twice in the rule, but the count of input file uses
	of the pattern is not two.  Because the final match fails, the 
	entire rule fails to match.
	
	This usage of the '@' modifier to a pattern variable in a rule
	will occur only in the top part of a rule, which will probably
	be written so as to remove labels that are no longer necessary.
	
============================================================================

	The '@' special character has been given a second meaning when
	it occurs in the second part, or replacement pattern.  It may
	be used to generate new, unique, labels.  In this case, the
	digit following the '%@' may not have been use previously in
	pattern (top) part of the rule.  It may be used again in the
	replacement (bottom) part of the rule, but without the '@', since
	the unique pattern has already been generated.
	
	Without the '-L' label pattern definition, the occurrence in the
	replacement part of a rule will create a unique string of digits.
	This string may be combined with a prefix and/or suffix to create
	unique generated labels.
	
	With the '-L' specified on the command line, the label generated
	will not conflict with any other in the input file, and will
	match the same pattern as other labels in the file; i.e., it 
	will already be of the form:  prefix, unique number, optional
	suffix.
	
	For example, the following rule generates the '%9' label with
	the first occurence in the replacement pattern of '%@9', and
	subsequently inserts the same label again with the use of the
	'%9' pattern.  The digit, '9' in this case, is unique throughout
	the rule.
	
	cmp qword [%5],%2:%3
	je %7
	=
	cmp dword [%5],%2
	jne %@9
	cmp dword [%5+4],%3
	je %7
	%9:

	If no '-L' were used on the command line, this rule could be
	written:	

	cmp qword [%5],%2:%3
	je %7
	=
	cmp dword [%5],%2
	jne LB%@9NEW
	cmp dword [%5+4],%3
	je %7
	LB%9NEW:
	
	to explicitly add the prefix 'LB' and the suffix 'NEW' to the
	generated unique numeric digit string created by '%@9'.
	

John Coffman <johninsd@sbcglobal.net>
05-Feb-2008
***************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <limits.h>

/* the following flag will add debugging code for the label scan */
#define DEBUG 1

/* the following will add in the label_loopind count code */
#define LABELREF 1

/* compilation with '-DNDEBUG' will remove all debugging code */
#ifdef NDEBUG
# define debug(d,x) (void)0
# undef DEBUG
# define DEBUG 0
#else
# define debug(d,x) (void)(dflag>=(d)&&((x),0))
#endif


#define VERSION "0.16.17.4 + jrc 2018"

#define MAXLINE		1024
#define MAXCOUNT	127
#ifdef __BCC__
#define HASHSIZE	107
#else
#define HASHSIZE	1999
#endif
#define NOCHAR		'\177'
#define VARNUM		10

#define COPT_COMMENT '!'


/* Struct containing each string of an input file */
struct line_s {
	struct line_s *next;
	struct line_s *prev;
	char          *text;
	int 	       comment_flg;
};


/* Struct containing one rule */
struct rule_s {
	struct rule_s *next;
	struct line_s *old;
	struct line_s *new;
};


/* Hash table to store strings in a space saving way */
struct hash_s {
	struct hash_s *next;
	char          *text;
	int	      length;	/* length of string */
};



/*
 * Global variables
 */
static struct rule_s *first = NULL;	/* first rule */
static struct rule_s *last = NULL;	/* last rule */
static struct line_s *infile = NULL;	/* list of strings in input file */
static struct hash_s *htab[HASHSIZE];	/* string hash table */
static char *vars[VARNUM];		/* variable table */
static int vuse[VARNUM];		/* label match value */
static char *progname;			/* program name */

static char *labelprefix, *labelsuffix;	/* label definition identifiers */
static int labelradix = 10;		/* radix, if not 10 */
static unsigned int label_max;		/* number of elements in label array */
static signed char *label_usecount;	/* count usage of each label */
static int *label_loopind;		/* record delta lineno if 2 uses only */
static int prelen, suflen=0;		/* lengths of label prefix & suffix */
static int label_generator = 9999;	/* used to generate labels */
#ifdef __BCC__
static char *hex = "$";
#else
static char *hex = "0x";
#endif
static int dflag = 0;			/* debugging flag */

/*
 * Allocate memory and print error if none available
 */
static void *mymalloc(int size)
{
  void *p;

  if ((p = malloc(size)) == NULL) {
	fprintf(stderr, "%s: no memory\n", progname);
	exit(1);
  }
  return(p);
}


/*
 *	Allocate and copy a string
 */
static char *mystrdup(char *str)
{
	char *p = mymalloc(strlen(str)+1);
	return strcpy(p, str);
}

/*
 *	Allocate and copy a string of specified length
 */
static char *mystrndup(char *str, int len)
{
	char *p = mymalloc(len+1);
	strncpy(p, str, len);
	p[len] = '\0';
	return p;
}

/*
 * Insert a string into the hash table. If the string is already in there
 * just return the pointer to that string.
 */
/* new version */
static char *install(char *str, int slen)
{
  struct hash_s *hp;
  char *cp;
  unsigned int hashval;
  int i;

  /* Get check string */
  if (slen < 0)
	slen = strlen(str);
{
  int i = strlen(str);
  if (i<slen) debug(0,fprintf(stderr,"install:  string '%s'(%d) reported as slen=%d\n",str,i,slen));
}

  /* Determine hashing value of string */
  hashval = 0;
  for (cp = str, i = 0; i < slen; i++)
	hashval = (hashval*73 + cp[i]) % HASHSIZE;

  /* Check if the string is already in the hashing table */
  for (hp = htab[hashval]; hp != NULL; hp = hp->next)
        if (hp->length == slen  &&  !strncmp(hp->text, str, slen) )
                return(hp->text);

  /* String is not in hash table, so create a new entry */
  hp = (struct hash_s *)mymalloc(sizeof(struct hash_s));
  hp->text = mystrndup(str, slen);
  hp->length = slen;
  hp->next = htab[hashval];
  htab[hashval] = hp;

  return(hp->text);
}

/*
 * Scan string to find balanced parentheses.
 * Return character count including the last ')'.
 * Input string does not include the first '('; i.e., all you get
 *   from a scanner is:  "a+(b*c)-d)".
 * Return -1 upon error
 */
static int paren_balance(char *cp)
{
    int count = 0;
    int lvl = 1;
    int c;
debug(2,fprintf(stderr,"paren_balance:  \"%s\" -> ", cp));
    while ((c = *cp++) && lvl) {
        if (c == '(') {
            ++lvl;
        }
        else if (c == ')') {
            --lvl;
        }
        ++count;
    }
    if (lvl) count = -1;

debug(2,fprintf(stderr,"%d\n", count));		
    return count;
}


/*
 * Read one line from input file and skip all blanks at the beginning
 */
static char *readline(FILE *fp)
{
  static char buf[MAXLINE];
  char *cp;

  /* Read line from input file */
  if (fgets(buf, MAXLINE-1, fp) == NULL)
	return(NULL);
  buf[MAXLINE-1] = '\0';

  /* Delete trailing newline */
  if ((cp = strchr(buf, '\n')) != NULL)
	*cp = '\0';

  /* Delete leading white spaces */
  for (cp = buf; *cp && isspace(*cp); cp++) ;
  if (cp != buf && *cp)
	strcpy(buf, cp);

  return(buf);
}



/*
 * Read a list of input lines. Terminate reading when the 'quit' character
 * has been found in the first column of the input line. All lines with the
 * 'comment' character in the first position will be skipped.
 */
static struct line_s *readlist(FILE *fp, int quit, int comment)
{
  struct line_s *lp;
  struct line_s *first_line = NULL;
  struct line_s *last_line = NULL;
  char *cp;

  while ((cp = readline(fp)) != NULL) {
	if (quit != NOCHAR && quit == *cp)
		break;
	if (comment != NOCHAR && comment == *cp && quit != NOCHAR)
		continue;
	if (*cp == '\0')
		continue;
	lp = mymalloc(sizeof(struct line_s));
	lp->text = install(cp, -1);
	lp->prev = last_line;
	lp->next = NULL;
	lp->comment_flg = (comment != NOCHAR && *cp == comment);
#if DEBUG
	if (lp->comment_flg) {
	    debug(3,fprintf(stderr,"Comment:\"%s\"\n", cp));
        }
#endif
	if (first_line == NULL)
		first_line = lp;
	if (last_line != NULL)
		last_line->next = lp;
	last_line = lp;
  }
  return(first_line);
}



/*
 * Read pattern file
 */
static void readpattern(char *rulesdir, char *filename)
{
  static char path[MAXLINE];
  struct rule_s *rp;
  FILE *fp;

  /* Open pattern file */
  if (rulesdir && (filename && !(*filename == '.' || *filename == '/')))
  {
  	int last = strlen(rulesdir);
	sprintf(path, "%s%s%s",
		rulesdir, 
		rulesdir[last-1] == '/' ? "" : "/",
		filename);
  }
  else
	sprintf(path, "%s", filename);
  if ((fp = fopen(path, "r")) == NULL) {
	fprintf(stderr, "%s: can't open pattern file %s\n", progname, path);
	exit(1);
  }

  /* Read every line of the pattern file */
  while (!feof(fp)) {
	rp = (struct rule_s *)mymalloc(sizeof(struct rule_s));
	rp->old = readlist(fp, '=', COPT_COMMENT);
	rp->new = readlist(fp, '\0', COPT_COMMENT);
	if (rp->old == NULL) {
		free(rp);
		break;
	}

/* This put the rules into the table in reverse order; this is confusing *
	rp->next = first;
	first = rp;
	if (last == NULL)
		last = rp;
*/
	rp->next = NULL;
	if (last) {
		last->next = rp;
		last = rp;
	} else {
		first = last = rp;
	}

  }

  /* Close pattern file */
  (void)fclose(fp);
}



/*
 * Clear pattern list to allow for another run
 */
static void clearpattern(void)
{
  struct rule_s *rp1, *rp2;
  struct line_s *lp1, *lp2;

  rp1 = first;
  while (rp1 != NULL) {
	/* Clear old rule text list */
	lp1 = rp1->old;
	while (lp1 != NULL) {
		lp2 = lp1;
		lp1 = lp1->next;
		free(lp2);
	}
	/* Clear new rule text list */
	lp1 = rp1->new;
	while (lp1 != NULL) {
		lp2 = lp1;
		lp1 = lp1->next;
		free(lp2);
	}
	/* Clear rule itself */
	rp2 = rp1;
	rp1 = rp1->next;
	free(rp2);
  }

  first = NULL;
  last = NULL;
}



/*
 * Read input file
 */
static void readinfile(char *filename, int comment)
{
  FILE *fp;

  fp = stdin;
  if (filename != NULL && (fp = fopen(filename, "r")) == NULL) {
	fprintf(stderr, "%s: can't open input file %s\n", progname, filename);
	exit(1);
  }
  infile = readlist(fp, NOCHAR, comment);
  if (fp != stdin)
	  (void)fclose(fp);
}

#if 0
#define NO_OP  0
#define ADD_OP 1
#define SUB_OP 2
#define MUL_OP 3
#define DIV_OP 4
#define SHL_OP 5
#define SHR_OP 6
#else

#define BINARY 4

enum {NO_OP, UN_MINUS, UN_COMPL, 
      ADD_OP=BINARY, SUB_OP, MUL_OP, DIV_OP, SHL_OP, SHR_OP, 
      AND_OP, OR_OP, XOR_OP, MOD_OP };
static const char cvt[] = "+-*/<>&|^%";
static const char unary[] = "+-~";

#endif

#if 0
  int sign = NO_OP;
/*  int base = 10; */
  int op = NO_OP;
#endif

/* Apply operation to current numeric value */
static long doretval(int op, long num, long retval, int *sign)
{
debug(3,fprintf(stderr,"doretval: op=%d, retval=%lu, num=%lu, sign=%d\n", op, retval, num, *sign));
      switch (*sign) {
              case UN_MINUS:	num = -num;
                              break;
              case UN_COMPL:	num = ~num;
                              break;
              default:
                              break;
      }
      switch (op) {
	      case NO_OP:	retval = num;
			      break;
	      case ADD_OP:	retval += num;
			      break;
	      case SUB_OP:	retval -= num;
			      break;
	      case MUL_OP:	retval *= num;
			      break;
	      case DIV_OP:	retval /= num;
	                      break;
              case MOD_OP:	retval %= num;
			      break;
	      case SHL_OP:	retval <<= num;
			      break;
	      case SHR_OP:	retval = (unsigned long)retval>>num;
			      break;
              case AND_OP:	retval &= num;
                              break;
              case OR_OP:	retval |= num;
                              break;
              case XOR_OP:	retval ^= num;
                              break;
      }
      *sign = NO_OP;
/*      base = 10;  */
debug(3,fprintf(stderr,"doretval: result=%lu\n", retval));
      return retval;
}

#define EVALERROR (long)0x80808080UL

/*
 * Eval an expression into an integer number
 */
static long eval(char *str, int len)
{
  char *cp, c, *t;
  int state = 0;
  int i, j, varnum, base = 10;
  long num = 0;
  long retval = 0;
  int op = NO_OP;
  int sign = NO_OP;


debug(3, fprintf(stderr, "eval: %d %s\n", len, str));

  /* Scan through whole string and decode it */
  for (cp = str, i = 0; *cp && i < len; cp++, i++) {
	c = toupper(*cp);

debug(3, fprintf(stderr, "eval loop: state=%d  char='%c' \n", state, c));

        if ((t = strchr(unary, c)) != NULL && (state == 0 || state == 5)) {
                state = 1;
                sign = t - unary;
debug(3, fprintf(stderr,"  sign set to %d\n", sign));
	} else if (c == '%' && isdigit(*(cp + 1)) && (state < 2 || state == 5)) {
		state = 4;
		varnum = *(cp + 1) - '0';
		if (vars[varnum] == NULL || i >= len) {
			retval = EVALERROR;
			goto eval_return;
                }
		num = eval(vars[varnum], strlen(vars[varnum]));
		retval = doretval(op, num, retval, &sign);
		cp++; i++;
        } else if (c == '(' && (state < 2 || state == 5)) {
                int len;
                state = 4;
                len = paren_balance(++cp);
                num = eval(cp, len-1);
                retval = doretval(op, num, retval, &sign);
                i += len;
                cp += len-1;
	} else if ((state < 2 || state == 5) && !strncmp(cp,hex,(j=strlen(hex)))) {
		state = 2;
		base = 16;
		cp += --j;
		i += j;
	} else if (base == 10 && (c >= '0' && c <= '9') &&
	           (state <= 3 || state == 5)) {
		state = 3;
		num = num * 10 + (c - '0');
	} else if (base == 16 &&
	           ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')) &&
	           (state <= 3 || state == 5)) {
		state = 3;
		num = num * 16 + (c >= 'A' ? c - '0' - 7 : c - '0');
	} else if (c == ' ' && state >= 3) {
		if (state == 3) {
 			retval = doretval(op, num, retval, &sign);
			state = 4;
		}
	} else if ((t = strchr(cvt, c)) != NULL && (state == 3 || state == 4)) {
		if (state == 3)
			retval = doretval(op, num, retval, &sign);
		state = 5;
		op = t - cvt + BINARY;
		num = 0;	/* restart */
		base = 10;
	} else {
		retval = EVALERROR;
		goto eval_return;
        }
  }

  /* Check if the string has been terminated correctly */
  if (state != 3 && state != 4) {
	retval = EVALERROR;
	goto eval_return;
  }

  if (state == 3)
		retval = doretval(op, num, retval, &sign);
eval_return:
debug(3, fprintf(stderr, "eval returns: %d == 0x%08x\n", retval, retval));
  return(retval);
}



/*
 * Compare an infile string with a pattern string. If there is any variable
 * defined, it will be inserted into the variable list from the pattern
 * string.
 */
static int match(char *ins, char *pat)
{
  char *cp, *oldpat;
  long val;
  int varnum;
  int len;
  int retval;
  static int recurse = 0;

  recurse++;
  retval = len = 0;
  while (*ins && *pat)
  {
  	if (pat[0] != '%')
	{
		if (*pat++ != *ins++)
			goto out;
		else
			continue;
	}
	if (pat[1] == '%') {
		/* '%%' actually means '%' */
		if (*ins != '%')
			goto out;
		pat += 2;
	} else if ((pat[1] == '*' || isdigit(pat[1]))) {
		/* Copy variable text into vars array */
		pat += 2;
		for (cp = ins; *ins && !match(ins, pat); ins++) ;
		if (pat[-1] == '*')
			continue;
		len = ins - cp;
		varnum = pat[-1] - '0';
		if (vars[varnum] == NULL)
			vars[varnum] = install(cp, len);
		else if (strlen(vars[varnum]) != len ||
				strncmp(vars[varnum], cp, len))
			goto out;
		vuse[varnum] += (recurse==1);
debug(4, fprintf(stderr,"  match %%%d=\"%s\" use=%d\n", varnum, vars[varnum], vuse[varnum]));
	} else if (pat[1] == '[') {
		/* Copy only specific variable text into vars array */
		if ((cp = strchr(pat + 2, ']')) == NULL ||
		    (*(cp + 1) != '*' && !isdigit(*(cp + 1)))) {
			if (*ins != '[')
				goto out;
			pat += 2;
			continue;
		}
		oldpat = pat + 1;
		pat = cp + 2;
		/* Separate allowable patterns and compare them with ins */
		while (*oldpat && *oldpat != ']') {
			oldpat++;
			len = strcspn(oldpat, "|]");
			if (!strncmp(ins, oldpat, len))
				break;
			oldpat += len;
		}
		if (!*oldpat || *oldpat == ']')
			goto out;
		ins += len;
		if (!match(ins, pat))
			goto out;
		/* Install new string into variable table */
		if (*(cp + 1) == '*')
			continue;
		varnum = *(cp + 1) - '0';
		if (vars[varnum] == NULL)
			vars[varnum] = install(oldpat, len);
		else if (strlen(vars[varnum]) != len ||
		           strncmp(vars[varnum], oldpat, len))
			goto out;
		vuse[varnum] += (recurse==1);
debug(4, fprintf(stderr,"[]match %%%d=\"%s\" use=%d\n", varnum, vars[varnum], vuse[varnum]));
	} else if (pat[1] == '!') {
		/* Match only if the pattern string is not found */
		if (pat[2] != '[' || (cp = strchr(pat + 3, ']')) == NULL) {
			if (*ins != '!')
				goto out;
			pat += 3;
			continue;
		}
		oldpat = pat + 2;
		pat = cp + 1;
		/* Separate allowable patterns and compare them with ins */
		while (*oldpat && *oldpat != ']') {
			oldpat++;
			len = strcspn(oldpat, "|]");
			if (!strncmp(ins, oldpat, len))
				goto out;
			oldpat += len;
		}
	} else if (pat[1] == '(') {
		/* Match ins with expression */
#if 0
		if ((cp = strchr(pat + 2, ')')) == NULL) {
			if (*ins != '(')
				goto out;
			pat += 2;
			continue;
		}
		oldpat = pat + 2;
		pat = cp + 1;
		len = cp - oldpat;
		val = eval(oldpat, len);
#else
                oldpat = pat + 2;
                len = paren_balance(oldpat);
                if (len < 0) {
                        if (*ins != '(')   goto out;
                        pat = oldpat;
                        continue;
                }
                pat = oldpat + len;
                val = eval(oldpat, len-1);
#endif
		for (cp = ins; *ins && !match(ins, pat); ins++) ;
		len = ins - cp;
		if (val != eval(cp, len))
			goto out;
	}
	else if (pat[1] == '@' && label_max && isdigit(pat[2])) {
		unsigned int label;
		if (strncmp(ins, labelprefix, prelen))
			goto out;
		pat += 3;
		cp = ins;
		if (!isdigit(ins[prelen]))
			goto out;
		label = strtoul(ins+prelen, &ins, labelradix);
		for ( ; *ins && !match(ins, pat); ins++) ;
		len = ins - cp;
		varnum = pat[-1] - '0';
		if (label >= label_max || label_usecount[label] != vuse[varnum]+1)
			goto out;
		if (vars[varnum] == NULL)
			vars[varnum] = install(cp, len);
		else if (strlen(vars[varnum]) != len ||
		           strncmp(vars[varnum], cp, len))
			goto out;
		vuse[varnum] += (recurse==1);
debug(4, fprintf(stderr,"@ match %%%d=\"%s\" use=%d\n", varnum, vars[varnum], vuse[varnum]));
	}
	else /* Bad % format cannot match */
		goto out;
  }

  retval = (*ins == *pat);
out:  
  recurse--;
  return retval;
}

/*
 *  Find an empty slot in the label array by looking a the use counts
 */
unsigned int empty_label(void)
{
	unsigned int i;

	for (i = 1; i < label_max; i++)
		if (label_usecount[i] == 0) return i;

	return 0;
}


/*
 * Substitute variables in a string
 */
static char *subst(char *pat)
{
  char buf[MAXLINE];
  char *cp, *cp1, *cp2, *varptr;
  unsigned long num;
  int i = 0;
  int j, pos;

  while (*pat)
	if (pat[0] == '%' && isdigit(pat[1])) {
		/* Substitute with value of variable */
		cp = vars[pat[1] - '0'];
		while (cp != NULL && *cp) {
			buf[i++] = *cp++;
			if (i >= MAXLINE - 1) {
				fprintf(stderr, "%s: line too long\n", progname);
				exit(1);
			}
		}
		pat += 2;
	} else if (pat[0] == '%' && pat[1] == '(') {
	        int len;
		/* Substitute with expression */
		cp = pat + 2;
		len = paren_balance(cp);
#if 0
		if ((pat = strchr(cp, ')')) == NULL || pat - cp <= 0)
			num = 0;
		else
			num = eval(cp, pat - cp);
#else
                if (len < 0) num = EVALERROR;
                else {
                        pat = cp + len - 1;
                        num = eval(cp, len - 1);
                }
#endif
		if (i >= MAXLINE - 20) {
			fprintf(stderr, "%s: line too long\n", progname);
			exit(1);
		}
		i += (num < 32768 ? sprintf(&buf[i], "%ld", num)
				: sprintf(&buf[i], "%s%lx", hex, num) );
		pat++;
	} else if (pat[0] == '%' && pat[1] == '=') {
		/* Substitute with converted variable */
		/* First separate all parts of the pattern string */
		cp = pat + 2;
		cp1 = cp2 = varptr = NULL;
		if (*cp == '[') {
			cp1 = ++cp;
			while (*cp && *cp != ']')
				cp++;
			if (cp[0] == ']' && cp[1] == '[') {
				cp += 2;
				cp2 = cp;
				while (*cp && *cp != ']')
					cp++;
				if (cp[0] == ']' && isdigit(cp[1]))
					 varptr = vars[cp[1] - '0'];
			}
		}
		if (cp1 == NULL || cp2 == NULL || varptr == NULL) {
			buf[i++] = *pat++;
			if (i >= MAXLINE - 1) {
				fprintf(stderr, "%s: line too long\n", progname);
				exit(1);
			}
			continue;
		}
		pat = cp + 2;
		/* Now scan through the first string to find variable value */
		cp1--;
		pos = 0;
		while (*cp1 != ']') {
			cp1++;
			j = strcspn(cp1, "|]");
			if (strlen(varptr) == j && !strncmp(cp1, varptr, j))
				break;
			pos++;
			cp1 += j;
		}
		if (*cp1 == ']')
			continue;
		/* Scan through the second string to find the conversion */
		cp2--;
		while (*cp2 != ']' && pos > 0) {
			cp2++;
			j = strcspn(cp2, "|]");
			pos--;
			cp2 += j;
		}
		if (*cp2 == ']' || pos != 0)
			continue;
		/* Insert conversion string into destination */
		cp2++;
		while (*cp2 != '|' && *cp2 != ']') {
			buf[i++] = *cp2++;
			if (i >= MAXLINE - 1) {
				fprintf(stderr, "%s: line too long\n", progname);
				exit(1);
			}
		}
	} else if (pat[0]=='%' && pat[1]=='@' && isdigit(pat[2])) {
		char tbuf[48];
		unsigned int lbl;
		
		if (vars[ j = pat[2]-'0' ] != NULL) {
			fprintf(stderr, "%s: '%%@%c' label exists already\n",
				progname, pat[2]);
			exit(1);
		}
		pat += 3;
		if (label_max) {  /* generate a label in a known format */
			if ((lbl = empty_label()))
				label_usecount[lbl] = 2;
			sprintf(tbuf, "%s%s%u%s", labelprefix,
				lbl ? "" : "XX",
				lbl ? lbl : ++label_generator,
				suflen ? labelsuffix : "");
		} else { /* generate a unique numeric value */
			sprintf(tbuf, "%d", ++label_generator);
		}
		vars[j] = mystrdup(tbuf);

		for (cp2 = tbuf; *cp2 && i < MAXLINE-1; cp2++)
			buf[i++] = *cp2;
		
		if (i >= MAXLINE - 1) {
			fprintf(stderr, "%s: line too long\n", progname);
			exit(1);
		}
	} else {
		buf[i++] = *pat++;
		if (i >= MAXLINE - 1) {
			fprintf(stderr, "%s: line too long\n", progname);
			exit(1);
		}
	}

  buf[i] = '\0';
  return(install(buf, i));
}
/*
 * Initialize the variable array
 */
void init_vars(void)
{
        int i;
        
	/* Clear variable array */
	for (i = 0; i < VARNUM; i++) {
		vars[i] = NULL;
		vuse[i] = 0;
	}
}


/*
 * Optimize one line of the input file
 */
static struct line_s *optline(struct line_s *cur)
{
  struct rule_s *rp;
  struct line_s *ins, *pat;
  struct line_s *lp1, *lp2;
  int i;

  for (rp = first; rp != NULL; rp = rp->next) {

	init_vars();	/* clear the variable arrays */
  
	/* Scan through pattern texts and match them against the input file */
	ins = cur;
	pat = rp->old;
	while (ins != NULL
	    && pat != NULL
	    && ( ins->comment_flg ||
	         ( /* (pat->text[0]=='%' || ins->text[0]==pat->text[0]) && */
		  match(ins->text, pat->text)))) {

		if (!ins->comment_flg)
			pat = pat->next;
		else if (ins->text[0]==pat->text[0]) /* Matching a comment! */
		{
		   if (match(ins->text, pat->text))
		      pat = pat->next;
		}
		ins = ins->next;
	}

	/* Current pattern matched input line, so replace input with new */
	if (pat == NULL) {
		/* Clear all lines in the source file for this pattern */
		lp1 = cur;
		cur = cur->prev;
		while (lp1 != ins) {
#if 0
			if( lp1->comment_flg )
			{
				lp2 = lp1;
				lp1 = lp1->next;
				lp2->next = cur->next;
				cur->next = lp2;
				lp2->prev = cur;
				cur=cur->next;
			}
			else
#endif
			{
				lp2 = lp1;
				lp1 = lp1->next;
				free(lp2);
			}
		}
		/* Insert new lines into list */
		pat = rp->new;
		lp1 = cur;
		lp2 = cur;
		while (pat != NULL) {
			lp2 = mymalloc(sizeof(struct line_s));
			lp2->text = subst(pat->text);
			lp2->next = NULL;
			lp2->prev = lp1;
			lp2->comment_flg = 0;
			if (lp1 != NULL)
				lp1->next = lp2;
			else
				infile = lp2;
			lp1 = lp2;
			pat = pat->next;
		}
		if (ins != NULL)
			ins->prev = lp2;
		if (lp2 != NULL)
			lp2->next = ins;
		else if (lp1 != NULL)
			lp1->next = NULL;
		else
			infile = NULL;
		return(cur);
	}
  }
  return(cur->next);
}



/*
 * Actually optimize all strings in the input file
 */
static void optimize(int backup)
{
  struct line_s *cur, *lp;
  int i;
  int in_asm = 0;

  /* Scan through all lines in the input file */
  cur = infile;
  while (cur != NULL) {
	if (cur->comment_flg || in_asm)
	{
		lp=cur->next;
		if (memcmp(cur->text, "!BCC_", 5) == 0)
			in_asm = (memcmp(cur->text+5, "ASM", 3) == 0);
	}
	else
	        if ((lp = optline(cur)) != NULL && lp != cur->next) {
			for (i = 0; i < backup && lp != NULL; i++)
				lp = lp->prev;
			if (lp == NULL)
				lp = infile;
		}
	cur = lp;
  }
}



/*
 * Write out into destination file
 */
static void writeoutf(char *filename, char *headstr)
{
  FILE *fp;
  struct line_s *lp;

  fp = stdout;
  if (filename != NULL && (fp = fopen(filename, "w")) == NULL) {
	fprintf(stderr, "%s: can't open output file %s\n", progname, filename);
	exit(1);
  }
  if (headstr != NULL) {
	fprintf(fp, "%s\n", headstr);
  }
  for (lp = infile; lp != NULL; lp = lp->next)
	fprintf(fp, "%s\n", lp->text);
  if (fp != stdout)
	  (void)fclose(fp);
}



/*
 * Print usage
 */
static void usage(void)
{
  fprintf(stderr, "version: " VERSION "\n");
  dflag=1;
  debug(0,fprintf(stderr,"Debugging enabled with '-D1' switch\n\n"));
  fprintf(stderr, 
  
  "usage: %s [-b<backup-num>] [-c<comment-char>] [-d<rules-dir>]\n"
        "\t[-h<head-str>] [-L<label_pat>] [-f<src-file>] [-o<out-file>]\n"
        "\t<rules-file> ...\n\n"
        "\tMultiple <rules-file>'s may be specified.\n"
        "\tInput is from 'stdin' if no -f is given.\n"
        "\tOutput is to 'stdout' if no -o is given.\n\n"
        , progname);
  exit(1);
}




/*
	Define what a label looks like:  "prefix" number "suffix"
	"prefix" and number are required; the suffix is optional
	number specifies the number of counters to allocate.
*/
static void label_spec(char *str)
{
	char *p, *q;
	p = str = mystrdup(str);
	while (*p && !isdigit(*p)) p++;
	if (isdigit(*p)) {
		if ((label_max = strtoul(p, &q, labelradix)) > 0) {
			label_usecount = mymalloc(label_max*sizeof(*label_usecount));
#if LABELREF
                        label_loopind = mymalloc(label_max*sizeof(*label_loopind));
#endif
			*p = 0; /* terminate prefix */
			labelprefix = str;
			if (*q) labelsuffix = q;
		}
	}
	else free(str);	
}


void dump_labels(void)
{
#if DEBUG
        int label;
        int label_count = label_max;
        
	while (--label_count && label_usecount[label_count] == 0) ;
	label_count++;
	for (label=0; label<label_count; label++)
		fprintf(stderr,"%s%d%s:\t%2d"
#if LABELREF
                        "%8d"
#endif
		        "\n"
		        , labelprefix,
			label, 
			labelsuffix ? labelsuffix : "",
			(int)label_usecount[label]
#if LABELREF
			, label_loopind[label]
#endif
			);
        fprintf(stderr,"\n");
#endif
}


void label_scan(struct line_s *file)
{
  char *p;
  unsigned int label;
#if LABELREF
  int lineno = 0;
  int lflag;
#endif
  
  if (label_max) {
	memset(label_usecount, 0, label_max*sizeof(*label_usecount));
#if LABELREF
	memset(label_loopind, 0, label_max*sizeof(*label_loopind));
#endif
  	prelen = strlen(labelprefix);
  	if (labelsuffix)
  		suflen = strlen(labelsuffix);

  	while (file) {
  		p = strstr(file->text, labelprefix);
#if LABELREF
                lineno++;
                lflag = (p == file->text);
#endif
  		if (p && isdigit(p[prelen])) {
  			p += prelen;
  			label = strtoul(p, &p, labelradix);
	  		if (!suflen || !strncmp(p, labelsuffix, suflen)) {
	  			if (label < label_max)
	  				if (label_usecount[label] < MAXCOUNT) {
	  					label_usecount[label]++;
#if LABELREF
                                                if (label_usecount[label] <= 2) {
                                                    label_loopind[label] += (lflag ? lineno : -lineno);
                                                }
                                                else label_loopind[label] = 0;  /* reset to zero if > 2 references */
#endif
	  				} 
	  				/* else skip the label */
	  		}
  		}
  		file = file->next;
  	}
        debug(2,dump_labels());
  }
}


#if DEBUG
/*
 * Gather statistics about the operation of the optimizer
 */
void statistics(void)
{
    int nhash, minlen, maxlen, minhash, maxhash, tothash;
    struct hash_s *hp;
    int i;

    maxhash = maxlen = tothash = 0;
    minhash = minlen = INT_MAX;
    for (i = 0; i < HASHSIZE; i++) {
        nhash = 0;
        for (hp = htab[i]; hp != NULL; hp = hp->next) {
            nhash++;
            if (hp->length > maxlen) maxlen = hp->length;
            if (hp->length < minlen) minlen = hp->length;
        }
        tothash += nhash;
        if (nhash > maxhash) maxhash = nhash;
        if (nhash < minhash) minhash = nhash;
    }
    debug(0,fprintf(stderr,"\nTotal hash table entries: %d ranging in size from %d to %d\n", tothash, minlen, maxlen));
    debug(0,fprintf(stderr,"Longest hash table slot: %d entries; shortest %d entries\n\n", maxhash, minhash));
}
#endif

/*
 * Main program
 */
int main(int argc, char **argv)
{
  int comment = NOCHAR;
  char *srcfile = NULL;
  char *outfile = NULL;
  char *headstr = NULL;
  char *rulesdir = NULL;
  int backup = 0;
  int i;

  /* Clear the hashing table */
  memset(htab, 0, sizeof(htab));

  /* Get program name */
  if ((progname = strrchr(argv[0], '/')) == NULL)
	progname = argv[0];
  else
	progname++;

  /* Make life easy for bcc */
  if ( argc > 4 && strcmp(argv[2], "-o") == 0 && argv[1][0] != '-' )
  {
     srcfile = argv[1];
     argv++,argc--;
  }

  /* Get options from command line */
  for (i = 1; i < argc; i++)
	if (argv[i][0] != '-') break;
	else
	{
		char *param;
		int sw = argv[i][1];
		
		if (!sw) usage();
		param = argv[i]+2;
		if (! *param) {
			param = argv[++i];
			if (!param || *param=='-') usage();
		}
		switch (sw) {
		case 'b':	/* backup */
			backup = atoi(param);
			break;
		case 'c':	/* source comment character */
			comment = *param;
			break;
		case 'd':	/* rules directory */
			rulesdir = param;
			break;
		case 'D':	/* debug flag */
		        dflag = atoi(param);
			break;
		case 'f':	/* input file (if not stdin) */
			srcfile = param;
			break;
		case 'h':	/* head string for output */
			headstr = param;
			break;
		case 'L':
			label_spec(param);
			break;
		case 'o':	/* output file (if not stdout) */
			outfile = param;
			break;
		default:
			usage();
		}
			
	}	/* for ... */

  /* Have to have enough parameters for rule file names */
  if ((argc - i) < 1)
	usage();

  /* Read source file and optimze it with every rules file */
  readinfile(srcfile, comment);
  for ( ; i < argc; i++) {
	label_scan(infile);		/* scan for label usage counts */
	readpattern(rulesdir, argv[i]);
	optimize(backup);
          debug(2,dump_labels());
	clearpattern();
  }
  writeoutf(outfile, headstr);
  
  debug(1,statistics());

  return(0);
}

