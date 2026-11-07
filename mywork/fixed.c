#include "fixed.h"
#include <inttypes.h>
#include <stdio.h>

uint32_t op1(uint32_t a, uint32_t b, int *n);
uint32_t op2(uint32_t a, uint32_t b);
uint32_t op3(uint32_t a, uint32_t b);
int32_t q_mul(int32_t a, int32_t b);

int main()
{
    // test
}
uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    (*n) = 0;
    while (b != 0) {                // b 會改成 C 即為進位
        uint32_t c = (a & b) << 1;  // carry
        a = a ^ b;                  // 此為暫時解
        b = c;
        (*n)++;
    }
    return a;
}
uint32_t op2(uint32_t a, uint32_t b)  // a - b 也就是 a + b的二補數 a + (~b + 1)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    (void) a;
    (void) b;
    return 0;
}

int32_t q_mul(int32_t a, int32_t b)
{
    (void) a;
    (void) b;
    return 0;
}