#include "test.h"
void outsource(struct Input *input, struct NzikInput *nzik, struct Output *output)
{
	if (input->a >= nzik->c) {
 		output->x = input->a - nzik->c;
 		output->y = input->b + nzik->c;
 		output->key = input->key;
 	}
 	
}