#include <stdint.h> 

#ifndef IO_H
#define IO_H

uint8_t init_com1();
void write_serial(char *message);

#endif // IO_H