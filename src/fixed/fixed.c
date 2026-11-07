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
    uint64_t result = (uint64_t) a * (uint64_t) b;
    result += (int64_t) 1u << 19;
    result >>= 20;
    return (uint32_t) result;
}
