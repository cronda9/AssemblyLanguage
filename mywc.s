//----------------------------------------------------------------------
// mywc.s
// Author: Christian Ronda
//----------------------------------------------------------------------

    .equ FALSE, 0
    .equ TRUE, 1

//----------------------------------------------------------------------
   .section .rodata

printfFormatString:
    .string "%7ld %7ld %7ld\n"

newLineStr:
    .string "\n"

//----------------------------------------------------------------------

    .section .data

lLineCount: 
    .quad 0

lWordCount:
    .quad 0

lCharCount:
    .quad 0

iInWord:
    .word FALSE

//----------------------------------------------------------------------

    .section .bss

iChar:
    .skip 4

//----------------------------------------------------------------------

    .section .text

    //----------------------------------------------------------------------
    // Write to stdout counts of how many lines, words, and characters
    // are in stdin. A word is a sequence of non-whitespace characters.
    // Whitespace is defined by the isspace() function. Return 0.
    //----------------------------------------------------------------------

    .equ EOF, -1

    .global main

main:

    //prolog
    sub sp, sp, 32
    str x30, [sp]

mainLoop: //                                                   mainLoop
    
    //if((iChar = getchar()) == EOF) goto mainLoopEnd;
    adr x1, iChar
    bl getchar
    str w0, [x1]
    cmp w0, EOF
    beq mainLoopEnd

    //lCharCount++;
    adr x0, lCharCount
    ldr x1, [x0]
    add x1, x1, 1
    str x1, [x0]

isSpace: //                                                   isSpace

    //if (!isspace(iChar)) goto else1;
    adr x0, iChar
    ldr w0, [x0]
    bl isspace
    cmp w0, FALSE
    beq else1

inWord: //                                                   inWord

    //if (!iInWord) goto endInWord;
    adr x0, iInWord
    ldr w0, [x0]
    cmp w0, FALSE
    beq endInWord

    //lWordCount++;
    adr x0, lWordCount
    ldr x1, [x0]
    add x1, x1, 1
    str x1, [x0]

    //iInWord = FALSE;
    adr x0, iInWord
    mov w1, FALSE
    str w1, [x0]

endInWord: //                                               ENDInWord

    // goto endIsSpace
    b endIsSpace

else1: //                                                   else1

inWord2: //                                                 inWord2

    //if (iInWord) goto endInWord2;
    adr x0, iInWord
    ldr x0, [x0]
    cmp x0, TRUE
    beq endInWord2

    //iInWord = TRUE;
    mov x1, TRUE
    str x1, [x0]

endInWord2: //                                              ENDinWord2

endIsSpace: //                                              ENDIsSpace

newLine: 

    //if (iChar != '\n') goto endNewLine;
    adr x0, iChar
    ldr x0, [x0]
    mov x1, newLineStr
    cmp x0, x1
    bne endNewLine

    //lLineCount++;
    adr x0, lLineCount
    ldr x1, [x0]
    add x1, x1, 1
    str x1, [x0]

endNewLine:

    // goto mainLoop
    b mainLoop

mainLoopEnd: //                                             ENDmainLoop

inWord3:

    //if (!iInWord) goto endInWord3;
    adr x0, iInWord
    ldr w0, [x0]
    mov w1, FALSE
    cmp w0, w1
    beq endInWord3

    //lWordCount++;
    adr x0, lWordCount
    ldr x1, [x0]
    add x1, x1, 1
    str x1, [x0]

endInWord3:

    //printf("%7ld %7ld %7ld\n", lLineCount, lWordCount, lCharCount);
    adr x0, printfFormatString
    ldr x0, [x0]
    adr x1, lCharCount
    ldr x1, [x1]
    adr x2, printfFormatString
    ldr x2, [x2]
    adr x3, lLineCount
    ldr x3, [x3]
    bl printf

    //epilogue and return 0
    mov w0, 0
    ldr x30, [sp]
    add x30, x30, 32
    ret

    .size   main, (. - main)
