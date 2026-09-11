#ifndef MICROGRID_SUNSPEC_H
#define MICROGRID_SUNSPEC_H

#include <stddef.h>
#include <stdint.h>

#define MG_SUNSPEC_BASE_REGISTER 40000u
#define MG_SUNSPEC_REGISTER_COUNT 124u
#define MG_SUNSPEC_UNIT_ID 1u
#define MG_MODBUS_MAX_RTU_FRAME 256u

typedef struct {
    float ac_current_a;
    float ac_voltage_v;
    int16_t active_power_w;
    float frequency_hz;
    int16_t apparent_power_va;
    int16_t reactive_power_var;
    float power_factor_percent;
    uint32_t lifetime_energy_wh;
    float dc_current_a;
    float dc_voltage_v;
    int16_t dc_power_w;
    float cabinet_temperature_c;
    float heatsink_temperature_c;
    uint16_t operating_state;
    uint32_t event_bits;
} mg_sunspec_telemetry_t;

typedef struct {
    uint16_t registers[MG_SUNSPEC_REGISTER_COUNT];
    uint8_t unit_id;
} mg_sunspec_server_t;

uint16_t mg_modbus_crc16(const uint8_t *data, size_t length);
void mg_sunspec_init(mg_sunspec_server_t *server);
void mg_sunspec_update(mg_sunspec_server_t *server,
                       const mg_sunspec_telemetry_t *telemetry);

/* Returns response length. A zero length means the frame must be discarded. */
size_t mg_sunspec_handle_rtu(mg_sunspec_server_t *server,
                             const uint8_t *request, size_t request_length,
                             uint8_t *response, size_t response_capacity);

#endif
