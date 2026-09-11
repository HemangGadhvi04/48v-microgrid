#include "microgrid_c2000_port.h"
#include "microgrid_rtu_transport.h"
#include "adc_scaling.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

typedef struct {
    uint32_t time_ticks;
    uint32_t elapsed_ticks;
    uint32_t applied_count;
    uint32_t watchdog_count;
    uint32_t ack_count;
    bool adc_complete;
    mg_c2000_digital_input_t digital;
    mg_app_raw_input_t adc;
    mg_app_output_t applied;
} mock_hal_t;

typedef struct {uint8_t data[MG_MODBUS_MAX_RTU_FRAME];size_t length;} mock_tx_t;

static void transmit(void *context,const uint8_t *data,size_t length)
{
    mock_tx_t *tx=context;assert(length<=sizeof(tx->data));
    for(size_t index=0u;index<length;index++)tx->data[index]=data[index];
    tx->length=length;
}

static uint16_t encode(float value,float zero,float units)
{
    float count=zero+value/units;
    if(count<0.0f)count=0.0f;
    if(count>4095.0f)count=4095.0f;
    return (uint16_t)lroundf(count);
}

static bool read_adc(void *context,mg_app_raw_input_t *raw)
{
    mock_hal_t *mock=context;*raw=mock->adc;return mock->adc_complete;
}

static mg_c2000_digital_input_t read_digital(void *context)
{
    return ((mock_hal_t *)context)->digital;
}

static uint32_t read_time(void *context)
{
    mock_hal_t *mock=context;
    const uint32_t value=mock->time_ticks;
    mock->time_ticks+=mock->elapsed_ticks;
    return value;
}

static void apply(void *context,const mg_app_output_t *output)
{
    mock_hal_t *mock=context;mock->applied=*output;mock->applied_count++;
}

static void watchdog(void *context){((mock_hal_t *)context)->watchdog_count++;}
static void acknowledge(void *context){((mock_hal_t *)context)->ack_count++;}

static mg_c2000_runtime_t setup(mock_hal_t *mock)
{
    *mock=(mock_hal_t){0};
    mock->adc_complete=true;mock->elapsed_ticks=3000u;
    mock->digital.start_request=true;
    mock->adc.pv_voltage=encode(46.5f,MG_ADC_PV_VOLTAGE_ZERO_COUNT,MG_ADC_PV_VOLTAGE_UNITS_PER_COUNT);
    mock->adc.dc_bus_voltage=encode(48.0f,MG_ADC_DC_BUS_VOLTAGE_ZERO_COUNT,MG_ADC_DC_BUS_VOLTAGE_UNITS_PER_COUNT);
    mock->adc.pv_current=encode(10.0f,MG_ADC_PV_CURRENT_ZERO_COUNT,MG_ADC_PV_CURRENT_UNITS_PER_COUNT);
    mock->adc.dc_inductor_current=encode(10.0f,MG_ADC_DC_INDUCTOR_CURRENT_ZERO_COUNT,MG_ADC_DC_INDUCTOR_CURRENT_UNITS_PER_COUNT);
    mock->adc.heatsink_temperature=encode(35.0f,MG_ADC_HEATSINK_TEMPERATURE_ZERO_COUNT,MG_ADC_HEATSINK_TEMPERATURE_UNITS_PER_COUNT);
    const mg_c2000_hal_t hal={mock,read_adc,read_digital,read_time,apply,
        watchdog,acknowledge,200u};
    mg_c2000_runtime_t runtime;mg_c2000_runtime_init(&runtime,&hal);return runtime;
}

static void test_isr_and_hardware_trip(void)
{
    mock_hal_t mock;mg_c2000_runtime_t runtime=setup(&mock);
    const float pi=3.14159265358979323846f,ts=50.0e-6f;
    for(uint32_t k=0;k<4000u;++k){
        const float v=40.8f*sinf(2.0f*pi*50.0f*k*ts);
        mock.adc.grid_voltage=encode(v,MG_ADC_GRID_VOLTAGE_ZERO_COUNT,MG_ADC_GRID_VOLTAGE_UNITS_PER_COUNT);
        mock.adc.utility_voltage=encode(v,MG_ADC_UTILITY_VOLTAGE_ZERO_COUNT,MG_ADC_UTILITY_VOLTAGE_UNITS_PER_COUNT);
        mock.adc.grid_current=encode(7.0f*sinf(2.0f*pi*50.0f*k*ts),MG_ADC_GRID_CURRENT_ZERO_COUNT,MG_ADC_GRID_CURRENT_UNITS_PER_COUNT);
        mg_c2000_control_isr(&runtime);
    }
    assert(mock.applied.state==MG_STATE_RUN&&mock.applied.pwm_enable);
    assert(mock.applied_count==4000u&&mock.ack_count==4000u);
    assert(mock.watchdog_count==4000u);
    mock.digital.hardware_trip=true;mg_c2000_control_isr(&runtime);
    assert(mock.applied.state==MG_STATE_FAULT&&!mock.applied.pwm_enable);
    assert((mock.applied.faults&MG_FAULT_HARDWARE_TRIP)!=0u);
    assert(mock.watchdog_count==4000u);
}

static void test_deadline_and_incomplete_adc_fail_safe(void)
{
    mock_hal_t mock;mg_c2000_runtime_t runtime=setup(&mock);
    mock.elapsed_ticks=7200u;mg_c2000_control_isr(&runtime);
    assert(runtime.deadline_missed_pending&&!mock.applied.pwm_enable);
    mock.elapsed_ticks=3000u;mg_c2000_control_isr(&runtime);
    assert(runtime.app.supervisor.state==MG_STATE_FAULT);
    assert((runtime.app.supervisor.latched_faults&MG_FAULT_DEADLINE_MISSED)!=0u);

    runtime=setup(&mock);mock.adc_complete=false;mg_c2000_control_isr(&runtime);
    assert(!mock.applied.pwm_enable&&mock.applied.state==MG_STATE_FAULT);
    assert((mock.applied.faults&MG_FAULT_SENSOR_INVALID)!=0u);
    mock.adc_complete=true;mg_c2000_control_isr(&runtime);
    assert(runtime.app.supervisor.state==MG_STATE_FAULT);
    assert((runtime.app.supervisor.latched_faults&MG_FAULT_SENSOR_INVALID)!=0u);
}

static void test_modbus_rtu_framing(void)
{
    mock_hal_t mock;mg_c2000_runtime_t runtime=setup(&mock);mock_tx_t tx={0};
    mg_c2000_rtu_transport_t rtu;
    mg_c2000_rtu_transport_init(&rtu,&runtime,transmit,&tx,200000000u,9600u);
    assert(rtu.silent_interval_ticks==802084u);
    uint8_t request[8]={1u,3u,0x9Cu,0x40u,0u,2u,0u,0u};
    const uint16_t crc=mg_modbus_crc16(request,6u);
    request[6]=(uint8_t)crc;request[7]=(uint8_t)(crc>>8);
    uint32_t now=1000u;
    for(size_t index=0u;index<sizeof(request);index++){
        mg_c2000_rtu_receive_byte(&rtu,request[index],now);now+=220000u;
    }
    mg_c2000_rtu_poll(&rtu,now+rtu.silent_interval_ticks);
    assert(rtu.frames_received==1u&&rtu.frames_replied==1u);
    assert(tx.length==9u&&tx.data[0]==1u&&tx.data[1]==3u&&tx.data[2]==4u);
    request[7]^=1u;tx.length=0u;now+=2000000u;
    for(size_t index=0u;index<sizeof(request);index++){
        mg_c2000_rtu_receive_byte(&rtu,request[index],now);now+=220000u;
    }
    mg_c2000_rtu_poll(&rtu,now+rtu.silent_interval_ticks);
    assert(rtu.frames_received==2u&&rtu.frames_discarded==1u&&tx.length==0u);
}

int main(void)
{
    test_isr_and_hardware_trip();test_deadline_and_incomplete_adc_fail_safe();
    test_modbus_rtu_framing();
    puts("PASS: C2000 port boundary tests");return 0;
}
