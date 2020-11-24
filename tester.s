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

    // BigInt struct offsets
    .equ LLENGTH, 0 // Struct offset for length
    .equ LDIGITS, 8 // Struct offset for long array

    // BigInt_add local variable registers:
    ULCARRY     .req x25
    LSUMLENGTH  .req x24 // callee-saved register
    LINDEX      .req x23 // callee-saved register
    ULSUM       .req x22 // callee-saved register

    // BigInt_add paramter registers:
    OSUM        .req x21 // callee-saved register
    OADDEND2    .req x20 // callee-saved register
    OADDEND1    .req x19 // callee-saved register

    .global BigInt_add

BigInt_add:

    //prolog
    sub sp, sp, BIGINT_ADD_STACKCOUNT
    str x30, [sp]
    str x19, [sp, 8]
    str x20, [sp, 16]
    str x21, [sp, 24]
    str x22, [sp, 32]
    str x23, [sp, 40]
    str x24, [sp, 48]
    str x25, [sp, 56]

    // Store parameters in registers
    mov OADDEND1, x0
    mov OADDEND2, x1
    mov OSUM, x2

    // Determine the larger length.
    // if(oAddend1->lLength <= oAddend2->lLength) goto else1;
    ldr LSUMLENGTH, [OADDEND1, LLENGTH] // LSUMLENGTH --> oAddend1->lLength
    ldr x1, [OADDEND2, LLENGTH] // x1 --> oAddend2->lLength
    cmp LSUMLENGTH, x1 
    bgt clear
    
else1:

    // move larger length into LSUMLENGTH
    mov LSUMLENGTH, x1

clear:

    // if (oSum->lLength <= lSumLength) goto endClear;
    ldr x0, [OSUM, LLENGTH]
    cmp x0, LSUMLENGTH   
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
    // lIndex = 0;
    mov LINDEX, 0

    // if (lIndex == lSumLength)
    cmp LINDEX, LSUMLENGTH
    beq endAddition 

    // Perform the addition. */
    // ulCarry = 0;
    mov ULCARRY, 0 

addition:

    // ulSum = ulCarry;
    mov ULSUM, ULCARRY 

    //ulCarry = 0;
    mov ULCARRY, 0

    // x1 = aulDigits + [lIndex]
    lsl x1, LINDEX, 3
    add x1, x1, LDIGITS

    // ulSum += oAddend1->aulDigits[lIndex];
    ldr x2, [OADDEND1, x1]
    adds ULSUM, ULSUM, x2
    bcc endOverflow1

carry1:
    // ulCarry = 1;
    mov ULCARRY, 1

endOverflow1: 

    // ulSum += oAddend2->aulDigits[lIndex];
    ldr x2, [OADDEND2, x1]
    adds ULSUM, ULSUM, x2
    bcc endOverflow2

carry2:
    // ulCarry = 1;
    mov ULCARRY, 1

endOverflow2:

    // oSum->aulDigits[lIndex] = ulSum;
    str ULSUM, [OSUM, x1]  // CHANGED

    // lIndex++;
    add LINDEX, LINDEX, 1

    // set carry flag
    mrs x0, nzcv
     
    // if(lIndex < lSumLength) goto loop;
    cmp LINDEX, LSUMLENGTH
    blt addition

endAddition:

carry:  /* Check for a carry out of the last "column" of the addition. */

    // if (ulCarry != 1) goto endMaxDigits;
    cmp ULCARRY, 1
    bne endCarry

maxDigits:

    // if (lSumLength != MAX_DIGITS) goto endMaxDigits;
    cmp LSUMLENGTH, MAX_DIGITS
    bne endMaxDigits

    // Epilogue and return FALSE
    mov x0, FALSE
    ldr x30, [sp]
    ldr x19, [sp, 8]
    ldr x20, [sp, 16]
    ldr x21, [sp, 24]
    ldr x22, [sp, 32]
    ldr x23, [sp, 40]
    ldr x24, [sp, 48]
    ldr x25, [sp, 56]
    add sp, sp, BIGINT_ADD_STACKCOUNT
    ret

endMaxDigits:

    // oSum->aulDigits[lSumLength] = 1;
    add x0, OSUM, LDIGITS
    mov x1, 1
    str x1, [x0, LSUMLENGTH, lsl 3]

    // lSumLength++;
    add LSUMLENGTH, LSUMLENGTH, 1

endCarry:

    // Set the length of the sum.
    // oSum->lLength = lSumLength;
    add x0, OSUM, LLENGTH
    str LSUMLENGTH, [x0]  // CHANGED

    // Epilogue and return TRUE;
    mov x0, TRUE
    ldr x30, [sp]
    ldr x19, [sp, 8]
    ldr x20, [sp, 16]
    ldr x21, [sp, 24]
    ldr x22, [sp, 32]
    ldr x23, [sp, 40]
    ldr x24, [sp, 48]
    ldr x25, [sp, 56]
    add sp, sp, BIGINT_ADD_STACKCOUNT
    ret

    .size   BigInt_add, (. - BigInt_add)
