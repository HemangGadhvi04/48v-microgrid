#ifndef MICROGRID_C2000_PORT_H
#define MICROGRID_C2000_PORT_H

#include "microgrid_app.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    bool start_request;
    bool reset_request;
    bool emergency_stop;
    bool hardware_trip;
} mg_c2000_digital_input_t;

typedef struct {
    void *context;
    bool (*read_adc_set)(void *context, mg_app_raw_input_t *raw);
    mg_c2000_digital_input_t (*read_digital_inputs)(void *context);
    uint32_t (*read_time_ticks)(void *context);
    void (*apply_outputs)(void *context, const mg_app_output_t *output);
    void (*service_watchdog)(void *context);
    void (*acknowledge_control_interrupt)(void *context);
    uint32_t timer_ticks_per_microsecond;
} mg_c2000_hal_t;

typedef struct {
    mg_app_t app;
    mg_c2000_hal_t hal;
    uint32_t adc_sequence;
    uint32_t last_execution_ticks;
    uint32_t maximum_execution_ticks;
    bool adc_invalid_pending;
    bool deadline_missed_pending;
} mg_c2000_runtime_t;

void mg_c2000_runtime_init(mg_c2000_runtime_t *runtime,
                           const mg_c2000_hal_t *hal);
void mg_c2000_control_isr(mg_c2000_runtime_t *runtime);
size_t mg_c2000_handle_modbus_frame(mg_c2000_runtime_t *runtime,
                                    const uint8_t *request,
                                    size_t request_length,
                                    uint8_t *response,
                                    size_t response_capacity);

#endif
