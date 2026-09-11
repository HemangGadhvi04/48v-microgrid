#ifndef MICROGRID_RTU_TRANSPORT_H
#define MICROGRID_RTU_TRANSPORT_H

#include "microgrid_c2000_port.h"

typedef void (*mg_c2000_rtu_transmit_fn)(void *context,
                                         const uint8_t *data,
                                         size_t length);

typedef struct {
    mg_c2000_runtime_t *runtime;
    mg_c2000_rtu_transmit_fn transmit;
    void *transmit_context;
    uint8_t request[MG_MODBUS_MAX_RTU_FRAME];
    uint8_t response[MG_MODBUS_MAX_RTU_FRAME];
    size_t request_length;
    uint32_t last_byte_ticks;
    uint32_t silent_interval_ticks;
    uint32_t frames_received;
    uint32_t frames_replied;
    uint32_t frames_discarded;
    bool receiving;
    bool overflow;
} mg_c2000_rtu_transport_t;

void mg_c2000_rtu_transport_init(mg_c2000_rtu_transport_t *transport,
                                 mg_c2000_runtime_t *runtime,
                                 mg_c2000_rtu_transmit_fn transmit,
                                 void *transmit_context,
                                 uint32_t timer_frequency_hz,
                                 uint32_t baud_rate);
void mg_c2000_rtu_receive_byte(mg_c2000_rtu_transport_t *transport,
                               uint8_t byte, uint32_t now_ticks);
void mg_c2000_rtu_poll(mg_c2000_rtu_transport_t *transport,
                       uint32_t now_ticks);

#endif
