#include "test.h"
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output)
{
 		output->x = input->a - nzik->c;
 		output->y = input->b + nzik->c;
}