#include "microgrid_sunspec.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

static size_t make_request(uint8_t unit, uint8_t function, uint16_t address,
                           uint16_t count, uint8_t frame[8])
{
    frame[0]=unit; frame[1]=function;
    frame[2]=(uint8_t)(address>>8); frame[3]=(uint8_t)address;
    frame[4]=(uint8_t)(count>>8); frame[5]=(uint8_t)count;
    const uint16_t crc=mg_modbus_crc16(frame,6u);
    frame[6]=(uint8_t)crc; frame[7]=(uint8_t)(crc>>8);
    return 8u;
}

static uint16_t response_register(const uint8_t *response, size_t index)
{
    return (uint16_t)(((uint16_t)response[3u+2u*index]<<8)
                      |response[4u+2u*index]);
}

static void test_known_crc(void)
{
    const uint8_t payload[]={0x01,0x03,0x00,0x00,0x00,0x0A};
    assert(mg_modbus_crc16(payload,sizeof(payload))==0xCDC5u);
}

static void test_signature_and_model_headers(void)
{
    mg_sunspec_server_t server; mg_sunspec_init(&server);
    assert(server.registers[0]==0x5375u && server.registers[1]==0x6E53u);
    assert(server.registers[2]==1u && server.registers[3]==66u);
    assert(server.registers[70]==101u && server.registers[71]==50u);
    assert(server.registers[122]==0xFFFFu && server.registers[123]==0u);
}

static void test_scaled_update_and_read(void)
{
    mg_sunspec_server_t server; mg_sunspec_init(&server);
    const mg_sunspec_telemetry_t telemetry={
        .ac_current_a=17.32f,.ac_voltage_v=28.85f,.active_power_w=499,
        .frequency_hz=50.01f,.apparent_power_va=500,.reactive_power_var=-150,
        .power_factor_percent=99.94f,.lifetime_energy_wh=123456u,
        .dc_current_a=10.81f,.dc_voltage_v=48.02f,.dc_power_w=519,
        .cabinet_temperature_c=31.2f,.heatsink_temperature_c=42.6f,
        .operating_state=4u,.event_bits=0x00000102u};
    mg_sunspec_update(&server,&telemetry);
    uint8_t request[8],response[MG_MODBUS_MAX_RTU_FRAME];
    make_request(1u,3u,40070u,52u,request);
    const size_t length=mg_sunspec_handle_rtu(&server,request,sizeof(request),
                                              response,sizeof(response));
    assert(length==109u && response[2]==104u);
    assert(response_register(response,2u)==1732u);
    assert(response_register(response,10u)==2885u);
    assert((int16_t)response_register(response,20u)==-150);
    assert((int16_t)response_register(response,22u)==9994);
    assert(response_register(response,24u)==1u);
    assert(response_register(response,25u)==57920u);
    assert(response_register(response,40u)==0u);
    assert(response_register(response,41u)==0x0102u);
    const uint16_t crc=(uint16_t)(response[length-2u]
                       |((uint16_t)response[length-1u]<<8));
    assert(mg_modbus_crc16(response,length-2u)==crc);
}

static void test_errors_and_capacity(void)
{
    mg_sunspec_server_t server; mg_sunspec_init(&server);
    uint8_t request[8],response[MG_MODBUS_MAX_RTU_FRAME];
    make_request(1u,3u,50000u,1u,request);
    assert(mg_sunspec_handle_rtu(&server,request,8u,response,sizeof(response))==5u);
    assert(response[1]==0x83u && response[2]==2u);
    make_request(1u,4u,40000u,1u,request);
    assert(mg_sunspec_handle_rtu(&server,request,8u,response,sizeof(response))==5u);
    assert(response[1]==0x84u && response[2]==1u);
    make_request(1u,3u,40000u,124u,request);
    assert(mg_sunspec_handle_rtu(&server,request,8u,response,20u)==0u);
    request[7]^=1u;
    assert(mg_sunspec_handle_rtu(&server,request,8u,response,sizeof(response))==0u);
}

int main(void)
{
    test_known_crc();
    test_signature_and_model_headers();
    test_scaled_update_and_read();
    test_errors_and_capacity();
    puts("PASS: embedded SunSpec/Modbus RTU tests");
    return 0;
}
