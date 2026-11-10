# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    #取出 8 位元 expo
    srli t0, a0, 23
    andi t0, t0, 0xFF

    #處理 Inf/NaN
    li t1, 0xFF
    beq t1, t0, f32_expofull
    #做rounding
    srli t0, a0, 16 #右移 16bits 因要捨棄 0 - 15
    andi t0, t0 ,1  #取得第 16 單 bit => lsb
    
    #加上 0x7FFF 跟 lsb
    li t1, 0x7FFF
    add a0, a0, t1
    add a0, a0, t0

f32_expofull: #Inf/NaN 直接回傳高 16bits
    srli a0, a0, 16
    ret


    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    li      a0, 0
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
bf16_sqrt_asm:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
