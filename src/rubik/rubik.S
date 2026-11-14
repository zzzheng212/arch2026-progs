# rubik_solve_asm: optimal 2x2x2 cube solver, hand-written RV32I.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#                                   a0 = state, a1 = out, a2 = cap; result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions, no heap, no recursion. Tests: tests/trubik.c.

    .text

    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
     addi sp, sp, -512
    sw s0, 448(sp)
    sw s1, 452(sp)
    sw s2, 456(sp)
    sw s3, 460(sp)
    sw s4, 464(sp)
    sw s5, 468(sp)
    sw s6, 472(sp)
    sw s7, 476(sp)
    sw s8, 480(sp)
    sw s9, 484(sp)
    sw s10, 488(sp)
    sw s11, 492(sp)
    sw ra, 496(sp)
    mv s0, a1
    mv s1, a2

    # Validate length before accessing the orientation half.
    li t0, 0
    li t1, 14
.Lrb_length:
    add t2, a0, t0
    lbu t3, 0(t2)
    beq t3, zero, .Lrb_invalid
    addi t0, t0, 1
    bltu t0, t1, .Lrb_length
    lbu t3, 14(a0)
    bne t3, zero, .Lrb_invalid

    li t0, 0
    li t1, 0                 # seen cubies
    li t2, 0                 # twist sum
    li s3, 0                 # orientation rank
.Lrb_parse:
    add t3, a0, t0
    lbu t4, 0(t3)
    addi t4, t4, -49
    li t5, 7
    bgeu t4, t5, .Lrb_invalid
    li t5, 1
    sll t5, t5, t4
    and t6, t1, t5
    bne t6, zero, .Lrb_invalid
    or t1, t1, t5
    addi t6, sp, 128
    add t6, t6, t0
    sb t4, 0(t6)
    lbu t4, 7(t3)
    addi t4, t4, -49
    li t5, 3
    bgeu t4, t5, .Lrb_invalid
    add t2, t2, t4
    # Track position*4+orientation for cubies 0 and 1.
    lbu t5, 0(t6)
    li t3, 1
    bltu t3, t5, .Lrb_parse_tracking_done
    slli t3, t0, 2
    add t3, t3, t4
    beq t5, zero, .Lrb_root_cubie0
    sw t3, 212(sp)
    j .Lrb_parse_tracking_done
.Lrb_root_cubie0:
    sw t3, 208(sp)
.Lrb_parse_tracking_done:
    li t5, 6
    beq t0, t5, .Lrb_no_orientation_digit
    slli t5, s3, 1
    add s3, s3, t5
    add s3, s3, t4
.Lrb_no_orientation_digit:
    addi t0, t0, 1
    li t5, 7
    bltu t0, t5, .Lrb_parse
.Lrb_mod3:
    li t5, 3
    bltu t2, t5, .Lrb_mod3_done
    addi t2, t2, -3
    j .Lrb_mod3
.Lrb_mod3_done:
    bne t2, zero, .Lrb_invalid

    # Lehmer rank: rank = rank * (7-i) + smaller.
    li s2, 0
    li t0, 0
.Lrb_rank_outer:
    addi t1, sp, 128
    add t1, t1, t0
    lbu t2, 0(t1)
    li t3, 0
    addi t4, t0, 1
.Lrb_rank_inner:
    li t5, 7
    bgeu t4, t5, .Lrb_rank_accumulate
    addi t1, sp, 128
    add t1, t1, t4
    lbu t6, 0(t1)
    sltu t6, t6, t2
    add t3, t3, t6
    addi t4, t4, 1
    j .Lrb_rank_inner
.Lrb_rank_accumulate:
    sub t5, t5, t0
    mv t6, s2
    li s2, 0
.Lrb_small_product:
    add s2, s2, t6
    addi t5, t5, -1
    bne t5, zero, .Lrb_small_product
    add s2, s2, t3
    addi t0, t0, 1
    li t5, 7
    bltu t0, t5, .Lrb_rank_outer

    la s6, .Lrb_perm_rows
    la s7, .Lrb_orient_rows
    la s8, .Lrb_pattern
    la s9, .Lrb_dist_o
    addi s10, sp, 108       # path[11]
    slli t0, s2, 3
    add t0, t0, s2
    lw t1, 208(sp)
    andi t1, t1, 3
    slli t2, t1, 1
    add t1, t1, t2
    add t0, t0, t1
    lw t1, 212(sp)
    andi t1, t1, 3
    add t0, t0, t1
    add t0, s8, t0
    lbu s4, 0(t0)
    add t0, s9, s3
    lbu t1, 0(t0)
    bgeu s4, t1, .Lrb_restart
    mv s4, t1

.Lrb_restart:
    li t0, 11
    bltu t0, s4, .Lrb_invalid
    li s5, 0                # depth
    sh s2, 0(sp)            # stack_p[0]
    sh s3, 24(sp)           # stack_o[0]
    sb zero, 96(sp)         # next_move[0]
    lw t0, 208(sp)
    sb t0, 144(sp)
    lw t0, 212(sp)
    sb t0, 156(sp)

.Lrb_search:
    slli t0, s5, 1
    add t0, sp, t0
    lhu t1, 0(t0)
    lhu t2, 24(t0)
    or t3, t1, t2
    beq t3, zero, .Lrb_found
    bgeu s5, s4, .Lrb_backtrack
    add t0, sp, s5
    lbu s11, 96(t0)         # candidate move
    li t3, 9
    bgeu s11, t3, .Lrb_backtrack
    addi t3, s11, 1
    sb t3, 96(t0)

    # Decode move into face (0..2) and turn (0..2), without division.
    li t3, 0
    mv t4, s11
    li t5, 3
.Lrb_decode:
    bltu t4, t5, .Lrb_decoded
    addi t4, t4, -3
    addi t3, t3, 1
    j .Lrb_decode
.Lrb_decoded:
    # Skip the whole face if it was used by the parent move.
    beq s5, zero, .Lrb_face_allowed
    add t5, s10, s5
    lbu t5, -1(t5)
    li t6, 3
    bltu t5, t6, .Lrb_parent_r
    li t6, 6
    bltu t5, t6, .Lrb_parent_b
    li t5, 2
    j .Lrb_parent_face
.Lrb_parent_r:
    li t5, 0
    j .Lrb_parent_face
.Lrb_parent_b:
    li t5, 1
.Lrb_parent_face:
    bne t3, t5, .Lrb_face_allowed
    addi t5, t3, 1
    slli t6, t5, 1
    add t5, t5, t6
    sb t5, 96(t0)
    j .Lrb_search

.Lrb_face_allowed:
    slli t5, s5, 1
    add t5, sp, t5
    # Later turns continue from the previous quarter-turn result.
    bne t4, zero, .Lrb_later_turn
    add t4, sp, s5
    lbu a3, 144(t4)
    lbu a4, 156(t4)
    j .Lrb_step
.Lrb_later_turn:
    lhu t1, 48(t5)
    lhu t2, 72(t5)
    add t4, sp, s5
    lbu a3, 168(t4)
    lbu a4, 180(t4)
.Lrb_step:
    # Update the two tracked cubies for this quarter turn.
    slli t4, t3, 5
    slli t6, t3, 2
    sub t4, t4, t6          # face * 28
    la t6, .Lrb_cubie
    add t4, t4, t6
    add t6, t4, a3
    lbu a3, 0(t6)
    add t6, t4, a4
    lbu a4, 0(t6)
    add t4, sp, s5
    sb a3, 168(t4)
    sb a4, 180(t4)
    slli t3, t3, 2
    add t4, s6, t3
    lw t4, 0(t4)
    slli t1, t1, 1
    add t4, t4, t1
    lhu t1, 0(t4)
    add t4, s7, t3
    lw t4, 0(t4)
    slli t2, t2, 1
    add t4, t4, t2
    lhu t2, 0(t4)
    sh t1, 48(t5)
    sh t2, 72(t5)

    sub t3, s4, s5
    addi t3, t3, -1         # remaining after candidate move
    slli t4, t1, 3
    add t4, t4, t1          # permutation rank * 9
    andi t6, a3, 3
    slli a5, t6, 1
    add t6, t6, a5
    add t4, t4, t6
    andi t6, a4, 3
    add t4, t4, t6
    add t4, s8, t4
    lbu t4, 0(t4)
    bltu t3, t4, .Lrb_search
    add t4, s9, t2
    lbu t4, 0(t4)
    bltu t3, t4, .Lrb_search
    add t4, s10, s5
    sb s11, 0(t4)
    addi s5, s5, 1
    slli t4, s5, 1
    add t4, sp, t4
    sh t1, 0(t4)
    sh t2, 24(t4)
    add t4, sp, s5
    sb zero, 96(t4)
    sb a3, 144(t4)
    sb a4, 156(t4)
    j .Lrb_search

.Lrb_backtrack:
    beq s5, zero, .Lrb_raise_bound
    addi s5, s5, -1
    j .Lrb_search
.Lrb_raise_bound:
    addi s4, s4, 1
    j .Lrb_restart

.Lrb_found:
    # Determine exact byte capacity before touching the output.
    li t0, 0
    li t1, 1                # terminating NUL
    la t2, .Lrb_names
.Lrb_count:
    bgeu t0, s5, .Lrb_capacity
    beq t0, zero, .Lrb_count_name
    addi t1, t1, 1
.Lrb_count_name:
    add t3, s10, t0
    lbu t3, 0(t3)
    slli t4, t3, 1
    add t3, t3, t4
    add t3, t2, t3
    addi t1, t1, 1
    lbu t4, 1(t3)
    beq t4, zero, .Lrb_count_next
    addi t1, t1, 1
.Lrb_count_next:
    addi t0, t0, 1
    j .Lrb_count
.Lrb_capacity:
    bltu s1, t1, .Lrb_too_small
    li t0, 0
    mv t1, s0
.Lrb_write:
    bgeu t0, s5, .Lrb_terminate
    beq t0, zero, .Lrb_write_name
    li t3, 32
    sb t3, 0(t1)
    addi t1, t1, 1
.Lrb_write_name:
    add t3, s10, t0
    lbu t3, 0(t3)
    slli t4, t3, 1
    add t3, t3, t4
    add t3, t2, t3
    lbu t4, 0(t3)
    sb t4, 0(t1)
    addi t1, t1, 1
    lbu t4, 1(t3)
    beq t4, zero, .Lrb_write_next
    sb t4, 0(t1)
    addi t1, t1, 1
.Lrb_write_next:
    addi t0, t0, 1
    j .Lrb_write
.Lrb_terminate:
    sb zero, 0(t1)
    mv a0, s5
    j .Lrb_return
.Lrb_too_small:
    beq s1, zero, .Lrb_small_return
    sb zero, 0(s0)
.Lrb_small_return:
    li a0, -2
    j .Lrb_return
.Lrb_invalid:
    li a0, -1
.Lrb_return:
    lw s0, 448(sp)
    lw s1, 452(sp)
    lw s2, 456(sp)
    lw s3, 460(sp)
    lw s4, 464(sp)
    lw s5, 468(sp)
    lw s6, 472(sp)
    lw s7, 476(sp)
    lw s8, 480(sp)
    lw s9, 484(sp)
    lw s10, 488(sp)
    lw s11, 492(sp)
    lw ra, 496(sp)
    addi sp, sp, 512
    ret
    .size rubik_solve_asm, .-rubik_solve_asm

    .section .rodata
    .balign 4
.Lrb_perm_rows:
    .word .Lrb_perm, .Lrb_perm+10080, .Lrb_perm+20160
.Lrb_orient_rows:
    .word .Lrb_orient, .Lrb_orient+1458, .Lrb_orient+2916
.Lrb_names:
    # Three bytes per name, including NUL and padding.
    .byte 82,0,0, 82,50,0, 82,39,0
    .byte 66,0,0, 66,50,0, 66,39,0
    .byte 68,0,0, 68,50,0, 68,39,0

    .include "src/rubik/rubik_tables_asm.inc"
