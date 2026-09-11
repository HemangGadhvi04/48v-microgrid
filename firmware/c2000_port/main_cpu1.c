#ifdef MG_C2000_TARGET
#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "f28379d_driverlib_hal.h"

void main(void)
{
    Device_init();
    Device_initGPIO();
    Interrupt_initModule();
    Interrupt_initVectorTable();
    mg_f28379d_configure_peripherals();
    mg_f28379d_bind_runtime();
    EINT;
    ERTM;
    for(;;)mg_f28379d_service_serial();
}
#else
typedef int mg_f28379d_main_build_disabled_t;
#endif
