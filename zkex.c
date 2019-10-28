#include "zkex.h"
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output)
{
 output->x = input->d + nzik->a + 5 - nzik->b * 2;
}