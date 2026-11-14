#include "fixed.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    (*n) = 0;
    while (b != 0) {
        uint32_t c = (a & b) << 1;
        a = a ^ b;
        b = c;
        (*n)++;
    }
    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    uint32_t carry = (a & 1u) & (b & 1u);

    return (a >> 1) + (b >> 1) + carry;
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a;
    uint32_t ub = (uint32_t) b;

    if (a < 0) {
        ua = 0u - ua;
    }
    if (b < 0) {
        ub = 0u - ub;
    }

    uint32_t lo = 0;
    uint32_t hi = 0;
    uint32_t xlo = ua;
    uint32_t xhi = 0;

    while (ub != 0) {
        if (ub & 1u) {
            uint32_t old = lo;
            lo += xlo;
            hi += xhi;
            hi += (lo < old);
        }

        xhi = (xhi << 1) | (xlo >> 31);
        xlo <<= 1;
        ub >>= 1;
    }

    // 對完整乘積取二補數
    if ((a < 0) != (b < 0)) {
        lo = 0u - lo;

        // Unsigned negation wraps; lo is not necessarily zero.
        // cppcheck-suppress knownConditionTrueFalse
        hi = ~hi + (lo == 0);
    }

    // 加上捨入常數，並傳遞進位
    uint32_t old = lo;
    lo += 1u << 19;

    // Unsigned addition can wrap, producing a carry.
    // cppcheck-suppress knownConditionTrueFalse
    hi += (lo < old);

    // 取原乘積的 bits 51～20
    uint32_t bits = (lo >> 20) | (hi << 12);

    if (bits <= INT32_MAX) {
        return (int32_t) bits;
    }

    return -1 - (int32_t) (UINT32_MAX - bits);
}
