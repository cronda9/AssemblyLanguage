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
    LLARGER     .req x28 // callee-saved register

    // BigInt_larger parameter registers
    LLENGTH1    .req x27 // callee-saved register
    LLENGTH2    .req x26 // callee-saved register

BigInt_larger:

//prolog 
    sub sp, sp, BIGINT_LARGER_STACKCOUNT
    str x30, [sp]
    str x26, [sp, 8]
    str x27, [sp, 16]
    str x28, [sp, 24]

lenIf:

    // move parameters into registers
    mov LLENGTH1, x0
    mov LLENGTH2, x1

    // if (lLength1 <= lLength2) goto else1;
    cmp LLENGTH1, LLENGTH2
    ble else1

    // lLarger = lLength1;
    mov LLARGER, LLENGTH1

else1:

    // lLarger = lLength2;
    mov LLARGER, LLENGTH2

endIf:

    // Epilogue and return lLarger
    mov x0, LLARGER
    ldr x30, [sp]
    ldr x26, [sp, 8]
    ldr x27, [sp, 16]
    ldr x28, [sp, 24]
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
    LSUMLENGTH  .req x25 // callee-saved register
    LINDEX      .req x24 // callee-saved register
    ULSUM       .req x23 // callee-saved register
    ULCARRY     .req x22 // callee-saved register

    // BigInt_add paramter registers:
    OSUM        .req x21 // callee-saved register
    OADDEND2    .req x20 // callee-saved register
    OADDEND1    .req x19 // callee-saved register

    // BigInt struct offsets
    .equ LLENGTH, 0 // Struct offset for length
    .equ LDIGITS, 8 // Struct offset for long array

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
    // lSumLength = BigInt_larger(oAddend1->lLength, oAddend2->lLength);
    add x0, OADDEND1, LLENGTH
    ldr x0, [x0]    // x0 --> oAddend1->lLength
    add x1, OADDEND1, LLENGTH
    ldr x1, [x1]    // x1 --> oAddend2->lLength
    bl BigInt_larger
    mov LSUMLENGTH, x0 
    
    // Clear oSum's array if necessary. 

clear:

    // if (oSum->lLength <= lSumLength) goto endClear;
    add x0, OSUM, LLENGTH
    ldr x0, [x0]     // x0 --> oSum->lLength
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
    // ulCarry = 0;
    mov ULCARRY, 0 
    // lIndex = 0;
    mov LINDEX, 0

addition:

    // if( lIndex >= lSumLength) goto endAddition;
    cmp LINDEX, LSUMLENGTH 
    bge endAddition

    // ulSum = ulCarry;
    mov ULSUM, ULCARRY 
    
    //ulCarry = 0;
    mov ULCARRY, 0

    // ulSum += oAddend1->aulDigits[lIndex];
    add x0, OADDEND1, LDIGITS
    ldr x2, [x0, LINDEX, lsl 3] 
    add x0, ULSUM, x2
    mov ULSUM, x0   // potential fix?

overflow1:

    // if (ulSum >= oAddend1->aulDigits[lIndex]) goto endOverflow1;
    cmp ULSUM, x2
    bhs endOverflow1

    // ulCarry = 1;
    mov ULCARRY, 1

endOverflow1: 

    // ulSum += oAddend2->aulDigits[lIndex];
    add x0, OADDEND2, LDIGITS
    ldr x2, [x0, LINDEX, lsl 3] 
    add x0, ULSUM, x2
    mov ULSUM, x0 // potential fix?

overflow2: // check for overflow
    
    // if (ulSum >= oAddend2->aulDigits[lIndex]) goto endOverflow2;
    cmp ULSUM, x2
    bhs endOverflow2

    // ulCarry = 1;
    mov ULCARRY, 1

endOverflow2:

    // oSum->aulDigits[lIndex] = ulSum;
    add x0, OSUM, LDIGITS
    add x0, [x0, LINDEX, lsl 3]
    mov x0, ULSUM // CHANGED

    // lIndex++;
    add LINDEX, LINDEX, 1
    b addition

endAddition:

carry:  /* Check for a carry out of the last "column" of the addition. */


    // if (ulCarry != 1) goto endCarry;
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
    add x0, [x0, LINDEX, lsl 3]  // CHANGED
    mov x0, 1

    // lSumLength++;
    add LSUMLENGTH, LSUMLENGTH, 1

endCarry:

    // Set the length of the sum.
    // oSum->lLength = lSumLength;
    add x0, OSUM, LLENGTH
    mov x0, LSUMLENGTH // CHANGED

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
