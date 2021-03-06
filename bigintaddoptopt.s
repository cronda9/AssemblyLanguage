//----------------------------------------------------------------------
// bigintaddopt.s
// Author: Christian Ronda
//----------------------------------------------------------------------

    .section .rodata

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

    // Store parameters in registers
    mov OADDEND1, x0
    mov OADDEND2, x1
    mov OSUM, x2

    // Determine the larger length.
    // Assume oAddend1 length is longer, set to lSumLength
    ldr LSUMLENGTH, [OADDEND1, LLENGTH] // LSUMLENGTH --> oAddend1->lLength
    ldr x1, [OADDEND2, LLENGTH]         // x1 --> oAddend2->lLength
    cmp LSUMLENGTH, x1 
    bgt clear
    
else1:

    // Handles when oAddend2->length is longer
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
    beq endCarry 

    // Perform the addition. */
addition:

    // reset ULSUM to 0;
    mov ULSUM, 0 

    // x1 = aulDigits + [lIndex]
    lsl x1, LINDEX, 3
    add x1, x1, LDIGITS

    // ulSum += oAddend1->aulDigits[lIndex]; 
    // adds C flad based on previous iteration, sets new C flag value
    ldr x2, [OADDEND1, x1]
    adcs ULSUM, ULSUM, x2
    bcc endOverflow1

    // If C flag was set on above addition, dont add C flag or set it
    ldr x2, [OADDEND2, x1]
    add ULSUM, ULSUM, x2
    b endOverflow2

endOverflow1: 

    // ulSum += oAddend1->aulDigits[lIndex]; 
    // adds C flad based on previous iteration, sets new C flag value
    ldr x2, [OADDEND2, x1]
    adcs ULSUM, ULSUM, x2

endOverflow2:

    // oSum->aulDigits[lIndex] = ulSum;
    str ULSUM, [OSUM, x1] 

    // lIndex++;
    add LINDEX, LINDEX, 1
     
    // if(lIndex < lSumLength) goto addition;
    // Similar to cmp + blt but without setting C flag
    sub x1, LINDEX, LSUMLENGTH
    cbnz x1, addition

endAddition:

carry:  /* Check for a carry out of the last "column" of the addition. */

    // if C flag == 0 goto endMaxDigits;
    bcc endCarry

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
    add sp, sp, BIGINT_ADD_STACKCOUNT
    ret

    .size   BigInt_add, (. - BigInt_add)
