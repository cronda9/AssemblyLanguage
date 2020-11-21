//----------------------------------------------------------------------
// bigintadd.s
// Author: Christian Ronda
//----------------------------------------------------------------------

    .section .rodata

printfLongFormat:
    .string "%ld"

//----------------------------------------------------------------------

    .section .data

//----------------------------------------------------------------------

    .section .bss

//----------------------------------------------------------------------

    .section .text

    //------------------------------------------------------------------
    // Return the larger of lLength1 and lLength2. 
    //------------------------------------------------------------------

    // Must be a multiple of 16
    .equ BIGINT_LARGER_STACKCOUNT, 32

    // BigInt_larger local variable stack offsets:
    .equ LLARGER, 8

    // BigInt_larger parameter stack offsets:
    .equ LLENGTH1, 16
    .equ LLENGTH2, 24

BigInt_larger:

    //prolog 
    sub sp, sp, BIGINT_LARGER_STACKCOUNT
    str x30, [sp]
    str x0, [sp, LLENGTH1]
    str x1, [sp, LLENGTH2]

lenIf:

    // if (lLength1 <= lLength2) goto else1;
    cmp x0, x1
    ble else1

    // lLarger = lLength1;
    ldr x2, [sp, LLARGER]
    str x0, [x2]

    // goto endElse
    b endIf

else1:

    // lLarger = lLength2;
    str x1, [x2]

endIf:

    // Epilogue and return lLarger
    ldr x30, [sp]
    add x30, x30, BIGINT_LARGER_STACKCOUNT
    ldr x0, [sp, LLARGER]
    ldr x0, [x0]
    ret

    .size   BigInt_larger, (. - BigInt_larger)

    //------------------------------------------------------------------
    // Assign the sum of oAddend1 and oAddend2 to oSum.  oSum should be
    // distinct from oAddend1 and oAddend2.  Return 0 (FALSE) if an
    // overflow occurred, and 1 (TRUE) otherwise.
    //------------------------------------------------------------------
    
    // In lieu of boolean data type
    .equ TRUE, 1
    .equ FALSE, 0

    // The maximum number of digits a BigInt object can contain
    .equ MAX_DIGITS, 32768

    // Size of unsigned(long)
    .equ SIZEOF_ULONG, 8

    // Must be a multiple of 16
    .equ BIGINT_ADD_STACKCOUNT, 64

    // BigInt_add local variable stack offsets:
    .equ ULCARRY, 40
    .equ ULSUM, 48
    .equ LINDEX, 56
    .equ LSUMLENGTH, 64

    // BigInt_add paramter stack offsets:
    .equ OADDEND1, 72
    .equ OADDEND2, 80
    .equ OSUM, 88

    // BigInt struct offsets
    .equ LLENGTH, 0
    .equ LDIGITS, 8

    .global BigInt_add

BigInt_add:

    //prolog
    sub sp, sp, BIGINT_ADD_STACKCOUNT
    str x30, [sp]
    str x0, [sp, OADDEND1]
    str x1, [sp, OADDEND2]
    str x2, [sp, OSUM]

    // Determine the larger length.
    // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength);
        // Puts oAddend1 -> lLength into x0
    ldr x0, [sp, OADDEND1]
    add x0, x0, LLENGTH
    ldr x0, [x0]
        // Puts oAddend2 -> lLength into x1
    ldr x1, [sp, OADDEND2]
    add x1, x1, LLENGTH
    ldr x1, [x1]
    bl BigInt_larger
    str x0, [sp, LSUMLENGTH]

    // printf("%ld", lSumLength);
    ldr x1, [x0]
    ldr x0, printfLongFormat
    bl printf

    // Clear oSum's array if necessary. 

clear:

    // if (oSum->lLength <= lSumLength) goto endClear;
        // x0 --> oSum -> lLength 
    ldr x0, [sp, OSUM]
    add x0, x0, LLENGTH
    ldr x0, [x0]
        // x1 --> lSumLength  
    ldr x1, [sp, LSUMLENGTH]
    ldr x1, [x1]
        // oSum->lLength <= lSumLength
    cmp x0, x1
        // goto endClear
    ble endClear

    // memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long));
        // x0 --> oSum -> aulDigits into x0
    ldr x0, [sp, OSUM]
    add x0, x0, LDIGITS
        // x1 --> 0 
    mov x1, 0
        // x2 --> MAX_DIGITS * sizeof(unsigned long) into x2
    mov x2, MAX_DIGITS
    mov x3, SIZEOF_ULONG
    mul x2, x2, x3
    bl memset
    
endClear:

    // Perform the addition. */
    //ulCarry = 0;
    mov x0, 0
    ldr x1, [sp, ULCARRY]
    str x0, [x1]
    //lIndex = 0;
    ldr x1, [sp, LINDEX]
    str x0, [x1]

addition:

    // if( lIndex >= lSumLength) goto endAddition;
    cmp x0, x1
    bge endAddition

    // ulSum = ulCarry;
    ldr x0, [sp, ULCARRY] // x0 --> mem addres of ulCarry
    str x1, [x0]
    str x1, [sp, ULSUM] 
    
    //ulCarry = 0;
    mov x1, 0
    str x1, [x0]

    // ulSum += oAddend1->aulDigits[lIndex];
    ldr x0, [sp, OADDEND1]
    add x0, x0, LDIGITS // x0 --> oAddend1->aulDigits
    ldr x1, [sp, LINDEX]
    ldr x1, [x1] // x1 --> lIndex
    ldr x0, [x0, x1, lsl 3] // x0 --> oAddend1->aulDigits[lIndex]
    ldr x2, [sp, ULSUM]
    ldr x2, [x2] // x2 --> ulSum
    add x1, x0, x2 // x2 --> ulSum + oAddend1->aulDigits[lIndex]
    str x1, [sp, ULSUM]

overflow1:

    // if (ulSum >= oAddend1->aulDigits[lIndex]) goto endOverflow1;
    cmp x2, x0
    bhs endOverflow1

    // ulCarry = 1;
    ldr x0, [sp, ULCARRY]
    mov x1, 1
    str x1, [x0]

endOverflow1: // check for overflow

    // ulSum += oAddend2->aulDigits[lIndex];
    ldr x0, [sp, OADDEND2]
    add x0, x0, LDIGITS // x0 --> oAddend2->aulDigits
    ldr x1, [sp, LINDEX]
    ldr x1, [x1] // x1 --> lIndex
    ldr x0, [x0, x1, lsl 3] // x0 --> oAddend2->aulDigits[lIndex]
    ldr x2, [sp, ULSUM] // x1 --> ulSum mem address
    add x1, x0, x2
    str x1, [sp, ULSUM]

overflow2: // check for overflow
    
    // if (ulSum >= oAddend2->aulDigits[lIndex]) goto endOverflow1;
    cmp x2, x0
    bhs endOverflow2

    // ulCarry = 1;
    ldr x0, [sp, ULCARRY]
    mov x1, 1
    str x1, [x0]

endOverflow2:

    // oSum->aulDigits[lIndex] = ulSum;
    ldr x0, [sp, OSUM]
    add x0, x0, LDIGITS
    ldr x1, [sp, LINDEX]
    ldr x1, [x1]
    ldr x0, [sp, x1, lsl 3]
    ldr x2, [sp, ULSUM]
    ldr x2, [x2]
    str x2, [x0]

    // lIndex++;
    ldr x0, [sp, LINDEX]
    add x0, x0, 1
    str x0, [x0]
    b addition

endAddition:

 carry:  /* Check for a carry out of the last "column" of the addition. */

    // if (ulCarry != 1) goto endCarry;
    ldr x0, [sp, ULCARRY]
    ldr x0, [x0]
    mov x1, 1
    cmp x0, x1
    bne endCarry

maxDigits:

    // if (lSumLength != MAX_DIGITS) goto endMaxDigits;
    ldr x0, [sp, LSUMLENGTH]
    ldr x0, [x0]
    mov x1, MAX_DIGITS
    cmp x0, x1
    bne endMaxDigits

    // return FALSE
    mov x0, FALSE
    ret

endMaxDigits:

    // oSum->aulDigits[lSumLength] = 1;
    ldr x0, [sp, OSUM]
    add x0, x0, LDIGITS
    ldr x1, [sp, LSUMLENGTH]
    ldr x0, [x0, x1, lsl 3]
    mov x2, 1
    str x2, [x0]

    // lSumLength++;
    ldr x0, [sp, LSUMLENGTH]
    add x0, x0, 1
    str x0, [x0]

endCarry:

    // Set the length of the sum.
    // oSum->lLength = lSumLength;
    ldr x0, [sp, OSUM]
    add x0, x0, LLENGTH
    ldr x1, [sp, LSUMLENGTH]
    str x1, [x0]

    // Epilogue and return TRUE;
    ldr x30, [sp]
    add sp, sp, BIGINT_ADD_STACKCOUNT
    mov x0, TRUE
    ret

    .size   BigInt_add, (. - BigInt_add)
