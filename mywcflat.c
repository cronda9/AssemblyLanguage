/*--------------------------------------------------------------------*/
/* mywcflat.c                                                         */
/* Author: Christian Ronda                                            */
/*--------------------------------------------------------------------*/

#include <stdio.h>
#include <ctype.h>

/*--------------------------------------------------------------------*/

/* In lieu of a boolean data type. */
enum {FALSE, TRUE};

/*--------------------------------------------------------------------*/

static long lLineCount = 0;      /* Bad style. */
static long lWordCount = 0;      /* Bad style. */
static long lCharCount = 0;      /* Bad style. */
static int iChar;                /* Bad style. */
static int iInWord = FALSE;      /* Bad style. */

/*--------------------------------------------------------------------*/

int main(void)
{
mainLoop:
    if((iChar = getchar()) == EOF) goto mainLoopEnd;
    lCharCount++;

    isSpace:
        if (!isspace(iChar)) goto else1;
        inWord:
            if (!iInWord) goto endInWord;
            lWordCount++;
            iInWord = FALSE;
        endInWord:
        goto endIsSpace;
    else1:
        inWord2:
            if (iInWord) goto endInWord2;
            iInWord = TRUE;
        endInWord2:
    endIsSpace:

    newLine:
        if (iChar != '\n') goto endNewLine;
        lLineCount++;
    endNewLine:
    goto mainLoop;
mainLoopEnd:
    inWord3:
        if (!iInWord) goto endInWord3;
        lWordCount++;
    endInWord3:

   printf("%7ld %7ld %7ld\n", lLineCount, lWordCount, lCharCount);
   return 0;
}