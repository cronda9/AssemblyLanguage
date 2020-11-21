//----------------------------------------------------------------------
// bigintaddopt.s
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
    // static long BigInt_larger(long lLength1, long lLength2)
    //------------------------------------------------------------------

    // Must be a multiple of 16
    .equ BIGINT_LARGER_STACKCOUNT, 32

    // BigInt_larger local variable registers
    LLARGER     .req x21 // callee-saved register

    // BigInt_larger parameter registers
    LLENGTH1    .req x20 // callee-saved register
    LLENGTH2    .req x19 // callee-saved register

BigInt_larger:

//prolog 
    sub sp, sp, BIGINT_LARGER_STACKCOUNT
    str x30, [sp]
    str x19, [sp, 8]
    str x20, [sp, 16]
    str x21, [sp, 24]

lenIf:

    // move parameters into registers
    mov LLENGTH1, x0
    mov LLENGTH2, x1

    // if (lLength1 <= lLength2) goto else1;
    cmp x0, x1
    ble else1

    // lLarger = lLength1;
    mov LLARGER, LLENGTH1

else1:

    // lLarger = lLength2;
    mov LLARGER, LLENGTH2

endIf:

    // Epilogue and return lLarger
    mov x0, LLARGER
    ldr x19, [sp, 8]
    ldr x20, [sp, 16]
    ldr x21, [sp, 24]
    ldr x30, [sp]
    add sp, sp, BIGINT_LARGER_STACKCOUNT
    ret

    .size   BigInt_larger, (. - BigInt_larger)

    //------------------------------------------------------------------
    // Assign the sum of oAddend1 and oAddend2 to oSum.  oSum should be
    // distinct from oAddend1 and oAddend2.  Return 0 (FALSE) if an
    // overflow occurred, and 1 (TRUE) otherwise.
    // int BigInt_add(BigInt_T oAddend1, BigInt_T oAddend2, BigInt_T oSum)
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

    // BigInt_add local variable registers:
    LSUMLENGTH  .req x28 // callee-saved register
    LINDEX      .req x27 // callee-saved register
    ULSUM       .req x26 // callee-saved register
    ULCARRY     .req x25 // callee-saved register

    // BigInt_add paramter registers:
    OSUM        .req x24 // callee-saved register
    OADDEND2    .req x23 // callee-saved register
    OADDEND1    .req x22 // callee-saved register

    // BigInt struct offsets
    .equ LLENGTH, 0 // Struct offset for length
    .equ LDIGITS, 8 // Struct offset for long array

    .global BigInt_add

BigInt_add:

    //prolog
    sub sp, sp, BIGINT_ADD_STACKCOUNT
    str x30, [sp]
    str x22, [sp, 72]
    str x23, [sp, 80]
    str x24, [sp, 88]
    str x25, [sp, 40]
    str x26, [sp, 48]
    str x27, [sp, 56]
    str x28, [sp, 64]

    // Store parameters in registers
    mov OADDEND1, x0
    mov OADDEND2, x1
    mov OSUM, x2

    // Determine the larger length.
    // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength);
    add x0, OADDEND1, LLENGTH
    ldr x0, [x0]    // x0 --> oAddend1->lLength
    add x1, OADDEND1, LLENGTH
    ldr x1, [x1]    // x1 --> oAddend2->lLength
    bl BigInt_larger
    str x0, [LSUMLENGTH]
    
    // Clear oSum's array if necessary. 

clear:

    // if (oSum->lLength <= lSumLength) goto endClear;
    add x1, OSUM, LLENGTH
    ldr x1, [x1]     // x1 --> oSum->lLength
    cmp x1, x0       // lSumLength already in x0
    ble endClear

    // memset(oSum->aulDigits, 0, MAX_DIGITS * sizeof(unsigned long));
    add x0, OSUM, LDIGITS // x0 --> oSum->aulDigits
    mov x1, 0             // x1 --> 0
    mov x2, MAX_DIGITS
    mov x3, SIZEOF_ULONG
    mul x2, x2, x3        // x2 --> MAX_DIGITS * sizeof(unsigned long)
    bl memset
    
endClear:

    // Perform the addition. */
    //ulCarry = 0;
    mov x0, 0
    str x0, ULCARRY


addition:

    // if( lIndex >= lSumLength) goto endAddition;
    ldr x1, [sp, LSUMLENGTH]
    cmp x0, x1
    bge endAddition

    // ulSum = ulCarry;
    ldr x0, [sp, ULCARRY] // x0 --> mem addres of ulCarry
    str x0, [sp, ULSUM] 
    
    //ulCarry = 0;
    mov x1, 0
    str x1, [sp, ULCARRY]

    // ulSum += oAddend1->aulDigits[lIndex];
    ldr x0, [sp, OADDEND1]
    add x0, x0, LDIGITS // x0 --> oAddend1->aulDigits
    ldr x1, [sp, LINDEX] // x1 --> lIndex
    ldr x0, [x0, x1, lsl 3] // x0 --> oAddend1->aulDigits[lIndex]
    ldr x2, [sp, ULSUM] // x2 --> ulSum
    add x1, x0, x2 // x1 --> ulSum + oAddend1->aulDigits[lIndex]
    str x1, [sp, ULSUM]

overflow1:

    // if (ulSum >= oAddend1->aulDigits[lIndex]) goto endOverflow1;
    cmp x1, x0
    bhs endOverflow1

    // ulCarry = 1;
    mov x1, 1
    str x1, [sp, ULCARRY]

endOverflow1: // check for overflow

    // ulSum += oAddend2->aulDigits[lIndex];
    ldr x0, [sp, OADDEND2]
    add x0, x0, LDIGITS // x0 --> oAddend2->aulDigits
    ldr x1, [sp, LINDEX] // x1 --> lIndex 
    ldr x0, [x0, x1, lsl 3] // x0 --> oAddend2->aulDigits[lIndex]
    ldr x2, [sp, ULSUM] // x1 --> ulSum mem address
    add x1, x0, x2
    str x1, [sp, ULSUM]

overflow2: // check for overflow
    
    // if (ulSum >= oAddend2->aulDigits[lIndex]) goto endOverflow2;
    cmp x1, x0
    bhs endOverflow2

    // ulCarry = 1;
    mov x1, 1
    str x1, [sp, ULCARRY]

endOverflow2:

    // oSum->aulDigits[lIndex] = ulSum;
    ldr x0, [sp, OSUM]
    add x0, x0, LDIGITS // x0 --> oSum->aulDigits
    ldr x1, [sp, LINDEX] // x1 --> lIndex
    ldr x2, [sp, ULSUM] // x2 --> ulSum
    str x2, [x0, x1, lsl 3]

    // lIndex++;
    ldr x0, [sp, LINDEX]
    add x0, x0, 1
    str x0, [sp, LINDEX]
    b addition

endAddition:

carry:  /* Check for a carry out of the last "column" of the addition. */

    // if (ulCarry != 1) goto endCarry;
    ldr x0, [sp, ULCARRY]
    mov x1, 1
    cmp x0, x1
    bne endCarry

maxDigits:

    // if (lSumLength != MAX_DIGITS) goto endMaxDigits;
    ldr x0, [sp, LSUMLENGTH]
    mov x1, MAX_DIGITS
    cmp x0, x1
    bne endMaxDigits

    // Epilogue and return FALSE
    ldr x30, [sp]
    add sp, sp, BIGINT_ADD_STACKCOUNT
    mov x0, FALSE
    ret

endMaxDigits:

    // oSum->aulDigits[lSumLength] = 1;
    ldr x0, [sp, OSUM]
    add x0, x0, LDIGITS
    ldr x1, [sp, LSUMLENGTH]
    mov x2, 1
    str x2, [x0, x1, lsl 3]

    // lSumLength++;
    ldr x0, [sp, LSUMLENGTH]
    add x0, x0, 1
    str x0, [sp, LSUMLENGTH]

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