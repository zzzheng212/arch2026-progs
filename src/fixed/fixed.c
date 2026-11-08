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

    // 無號方式取得絕對值，包含 INT32_MIN
    if (a < 0) {
        ua = 0u - ua;
    }
    if (b < 0) {
        ub = 0u - ub;
    }

    uint64_t product = 0;
    uint64_t x = ua;

    while (ub != 0) {
        if (ub & 1u) {
            product += x;
        }

        x <<= 1;
        ub >>= 1;
    }

    // 轉成有號乘積的二補數位元表示
    if ((a < 0) != (b < 0)) {
        product = UINT64_C(0) - product;
    }

    product += UINT64_C(1) << 19;
    uint32_t bits = (uint32_t) (product >> 20);

    // 將低32位轉成對應的 int32_t，避免超範圍轉型
    if (bits <= INT32_MAX) {
        return (int32_t) bits;
    }

    return -1 - (int32_t) (UINT32_MAX - bits);
}
