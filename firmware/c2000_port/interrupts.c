#ifndef MG_C2000_TARGET
typedef int mg_f28379d_interrupts_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "interrupts.h"

// Defined in f28379d_driverlib_hal.c
extern __interrupt void mg_f28379d_control_isr(void);

void init_interrupts(void)
{
    Interrupt_register(INT_ADCA1, &mg_f28379d_control_isr);
    Interrupt_enable(INT_ADCA1);
}
#endif
