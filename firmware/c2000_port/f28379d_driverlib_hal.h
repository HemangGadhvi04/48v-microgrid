#ifndef MG_F28379D_DRIVERLIB_HAL_H
#define MG_F28379D_DRIVERLIB_HAL_H

#include <stdbool.h>

void mg_f28379d_bind_runtime(void);
void mg_f28379d_set_run_request(bool run);
void mg_f28379d_request_fault_reset(void);
void mg_f28379d_service_serial(void);
void mg_f28379d_control_isr(void);

#endif
