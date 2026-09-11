#include "microgrid_sunspec.h"

#include <math.h>
#include <string.h>

enum {
    REG_SUNS_0 = 0,
    REG_SUNS_1 = 1,
    REG_COMMON_ID = 2,
    REG_COMMON_LENGTH = 3,
    REG_COMMON_MANUFACTURER = 4,
    REG_COMMON_MODEL = 20,
    REG_COMMON_OPTIONS = 36,
    REG_COMMON_VERSION = 44,
    REG_COMMON_SERIAL = 52,
    REG_COMMON_DEVICE_ADDRESS = 68,
    REG_COMMON_PAD = 69,
    REG_INVERTER_ID = 70,
    REG_INVERTER_LENGTH = 71,
    REG_AC_CURRENT = 72,
    REG_AC_CURRENT_PHASE_A = 73,
    REG_AC_CURRENT_SF = 76,
    REG_AC_VOLTAGE_PHASE_A = 80,
    REG_AC_VOLTAGE_SF = 83,
    REG_ACTIVE_POWER = 84,
    REG_ACTIVE_POWER_SF = 85,
    REG_FREQUENCY = 86,
    REG_FREQUENCY_SF = 87,
    REG_APPARENT_POWER = 88,
    REG_APPARENT_POWER_SF = 89,
    REG_REACTIVE_POWER = 90,
    REG_REACTIVE_POWER_SF = 91,
    REG_POWER_FACTOR = 92,
    REG_POWER_FACTOR_SF = 93,
    REG_ENERGY_HIGH = 94,
    REG_ENERGY_LOW = 95,
    REG_ENERGY_SF = 96,
    REG_DC_CURRENT = 97,
    REG_DC_CURRENT_SF = 98,
    REG_DC_VOLTAGE = 99,
    REG_DC_VOLTAGE_SF = 100,
    REG_DC_POWER = 101,
    REG_DC_POWER_SF = 102,
    REG_CABINET_TEMPERATURE = 103,
    REG_HEATSINK_TEMPERATURE = 104,
    REG_TEMPERATURE_SF = 107,
    REG_OPERATING_STATE = 108,
    REG_EVENT_HIGH = 110,
    REG_EVENT_LOW = 111,
    REG_END_ID = 122,
    REG_END_LENGTH = 123
};

static uint16_t be16(const uint8_t *data)
{
    return (uint16_t)(((uint16_t)data[0] << 8) | data[1]);
}

static void put_be16(uint8_t *data, uint16_t value)
{
    data[0] = (uint8_t)(value >> 8);
    data[1] = (uint8_t)value;
}

static void finish_crc(uint8_t *frame, size_t payload_length)
{
    const uint16_t crc = mg_modbus_crc16(frame, payload_length);
    frame[payload_length] = (uint8_t)crc;
    frame[payload_length + 1u] = (uint8_t)(crc >> 8);
}

static void put_string(uint16_t *registers, size_t start, size_t count,
                       const char *value)
{
    const size_t length = strlen(value);
    for (size_t index = 0; index < count; ++index) {
        const size_t character = 2u * index;
        const uint8_t high = character < length ? (uint8_t)value[character] : 0u;
        const uint8_t low = character + 1u < length ? (uint8_t)value[character + 1u] : 0u;
        registers[start + index] = (uint16_t)(((uint16_t)high << 8) | low);
    }
}

static uint16_t scaled_u16(float value, float multiplier)
{
    long scaled = lroundf(value * multiplier);
    if (scaled < 0) scaled = 0;
    if (scaled > 65534) scaled = 65534;
    return (uint16_t)scaled;
}

static uint16_t scaled_i16(float value, float multiplier)
{
    long scaled = lroundf(value * multiplier);
    if (scaled < -32767) scaled = -32767;
    if (scaled > 32767) scaled = 32767;
    return (uint16_t)(int16_t)scaled;
}

uint16_t mg_modbus_crc16(const uint8_t *data, size_t length)
{
    uint16_t crc = 0xFFFFu;
    for (size_t index = 0; index < length; ++index) {
        crc ^= data[index];
        for (unsigned bit = 0; bit < 8u; ++bit) {
            crc = (crc & 1u) != 0u ? (uint16_t)((crc >> 1) ^ 0xA001u)
                                    : (uint16_t)(crc >> 1);
        }
    }
    return crc;
}

void mg_sunspec_init(mg_sunspec_server_t *server)
{
    for (size_t index = 0; index < MG_SUNSPEC_REGISTER_COUNT; ++index)
        server->registers[index] = 0xFFFFu;
    server->unit_id = MG_SUNSPEC_UNIT_ID;
    server->registers[REG_SUNS_0] = 0x5375u;
    server->registers[REG_SUNS_1] = 0x6E53u;
    server->registers[REG_COMMON_ID] = 1u;
    server->registers[REG_COMMON_LENGTH] = 66u;
    put_string(server->registers, REG_COMMON_MANUFACTURER, 16u, "Open Microgrid Research");
    put_string(server->registers, REG_COMMON_MODEL, 16u, "48V-500W-LAB");
    put_string(server->registers, REG_COMMON_OPTIONS, 8u, "LV research bus");
    put_string(server->registers, REG_COMMON_VERSION, 8u, "0.1.0");
    put_string(server->registers, REG_COMMON_SERIAL, 16u, "PROTO-0001");
    server->registers[REG_COMMON_DEVICE_ADDRESS] = server->unit_id;
    server->registers[REG_COMMON_PAD] = 0xFFFFu;
    server->registers[REG_INVERTER_ID] = 101u;
    server->registers[REG_INVERTER_LENGTH] = 50u;
    server->registers[REG_AC_CURRENT_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_AC_VOLTAGE_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_ACTIVE_POWER_SF] = 0u;
    server->registers[REG_FREQUENCY_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_APPARENT_POWER_SF] = 0u;
    server->registers[REG_REACTIVE_POWER_SF] = 0u;
    server->registers[REG_POWER_FACTOR_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_ENERGY_SF] = 0u;
    server->registers[REG_DC_CURRENT_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_DC_VOLTAGE_SF] = (uint16_t)(int16_t)-2;
    server->registers[REG_DC_POWER_SF] = 0u;
    server->registers[REG_TEMPERATURE_SF] = (uint16_t)(int16_t)-1;
    server->registers[REG_END_ID] = 0xFFFFu;
    server->registers[REG_END_LENGTH] = 0u;
}

void mg_sunspec_update(mg_sunspec_server_t *server,
                       const mg_sunspec_telemetry_t *telemetry)
{
    const uint16_t current = scaled_u16(telemetry->ac_current_a, 100.0f);
    server->registers[REG_AC_CURRENT] = current;
    server->registers[REG_AC_CURRENT_PHASE_A] = current;
    server->registers[REG_AC_VOLTAGE_PHASE_A] = scaled_u16(telemetry->ac_voltage_v, 100.0f);
    server->registers[REG_ACTIVE_POWER] = (uint16_t)telemetry->active_power_w;
    server->registers[REG_FREQUENCY] = scaled_u16(telemetry->frequency_hz, 100.0f);
    server->registers[REG_APPARENT_POWER] = (uint16_t)telemetry->apparent_power_va;
    server->registers[REG_REACTIVE_POWER] = (uint16_t)telemetry->reactive_power_var;
    server->registers[REG_POWER_FACTOR] = scaled_i16(telemetry->power_factor_percent, 100.0f);
    server->registers[REG_ENERGY_HIGH] = (uint16_t)(telemetry->lifetime_energy_wh >> 16);
    server->registers[REG_ENERGY_LOW] = (uint16_t)telemetry->lifetime_energy_wh;
    server->registers[REG_DC_CURRENT] = scaled_u16(telemetry->dc_current_a, 100.0f);
    server->registers[REG_DC_VOLTAGE] = scaled_u16(telemetry->dc_voltage_v, 100.0f);
    server->registers[REG_DC_POWER] = (uint16_t)telemetry->dc_power_w;
    server->registers[REG_CABINET_TEMPERATURE] = scaled_i16(telemetry->cabinet_temperature_c, 10.0f);
    server->registers[REG_HEATSINK_TEMPERATURE] = scaled_i16(telemetry->heatsink_temperature_c, 10.0f);
    server->registers[REG_OPERATING_STATE] = telemetry->operating_state;
    server->registers[REG_EVENT_HIGH] = (uint16_t)(telemetry->event_bits >> 16);
    server->registers[REG_EVENT_LOW] = (uint16_t)telemetry->event_bits;
}

static size_t exception_response(uint8_t unit, uint8_t function, uint8_t code,
                                 uint8_t *response, size_t capacity)
{
    if (capacity < 5u) return 0u;
    response[0] = unit;
    response[1] = (uint8_t)(function | 0x80u);
    response[2] = code;
    finish_crc(response, 3u);
    return 5u;
}

size_t mg_sunspec_handle_rtu(mg_sunspec_server_t *server,
                             const uint8_t *request, size_t request_length,
                             uint8_t *response, size_t response_capacity)
{
    if (request_length != 8u || response == NULL || request == NULL) return 0u;
    const uint16_t received_crc = (uint16_t)(request[6] | ((uint16_t)request[7] << 8));
    if (mg_modbus_crc16(request, 6u) != received_crc || request[0] != server->unit_id)
        return 0u;
    const uint8_t function = request[1];
    if (function != 3u)
        return exception_response(server->unit_id, function, 1u, response, response_capacity);
    const uint16_t address = be16(&request[2]);
    const uint16_t count = be16(&request[4]);
    if (count == 0u || count > 125u)
        return exception_response(server->unit_id, function, 3u, response, response_capacity);
    if (address < MG_SUNSPEC_BASE_REGISTER
        || (uint32_t)address + count > (uint32_t)MG_SUNSPEC_BASE_REGISTER
                                      + MG_SUNSPEC_REGISTER_COUNT)
        return exception_response(server->unit_id, function, 2u, response, response_capacity);
    const size_t response_length = 3u + 2u * count + 2u;
    if (response_capacity < response_length) return 0u;
    response[0] = server->unit_id;
    response[1] = function;
    response[2] = (uint8_t)(2u * count);
    const size_t offset = address - MG_SUNSPEC_BASE_REGISTER;
    for (size_t index = 0; index < count; ++index)
        put_be16(&response[3u + 2u * index], server->registers[offset + index]);
    finish_crc(response, response_length - 2u);
    return response_length;
}
