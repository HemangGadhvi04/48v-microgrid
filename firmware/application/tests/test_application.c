#include "microgrid_app.h"
#include "adc_scaling.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static uint16_t encode(float value,float zero,float units)
{
    float count=zero+value/units;
    if(count<0.0f)count=0.0f;if(count>4095.0f)count=4095.0f;
    return (uint16_t)lroundf(count);
}

static mg_app_raw_input_t sample(float grid_voltage,float utility_voltage,
                                 float grid_current,uint32_t sequence)
{
    return (mg_app_raw_input_t){
        .pv_voltage=encode(46.5f,MG_ADC_PV_VOLTAGE_ZERO_COUNT,MG_ADC_PV_VOLTAGE_UNITS_PER_COUNT),
        .dc_bus_voltage=encode(48.0f,MG_ADC_DC_BUS_VOLTAGE_ZERO_COUNT,MG_ADC_DC_BUS_VOLTAGE_UNITS_PER_COUNT),
        .pv_current=encode(10.0f,MG_ADC_PV_CURRENT_ZERO_COUNT,MG_ADC_PV_CURRENT_UNITS_PER_COUNT),
        .dc_inductor_current=encode(10.0f,MG_ADC_DC_INDUCTOR_CURRENT_ZERO_COUNT,MG_ADC_DC_INDUCTOR_CURRENT_UNITS_PER_COUNT),
        .grid_voltage=encode(grid_voltage,MG_ADC_GRID_VOLTAGE_ZERO_COUNT,MG_ADC_GRID_VOLTAGE_UNITS_PER_COUNT),
        .utility_voltage=encode(utility_voltage,MG_ADC_UTILITY_VOLTAGE_ZERO_COUNT,MG_ADC_UTILITY_VOLTAGE_UNITS_PER_COUNT),
        .grid_current=encode(grid_current,MG_ADC_GRID_CURRENT_ZERO_COUNT,MG_ADC_GRID_CURRENT_UNITS_PER_COUNT),
        .heatsink_temperature=encode(35.0f,MG_ADC_HEATSINK_TEMPERATURE_ZERO_COUNT,MG_ADC_HEATSINK_TEMPERATURE_UNITS_PER_COUNT),
        .sequence=sequence,.start_request=true};
}

static void test_start_run_and_trip(void)
{
    const float pi=3.14159265358979323846f,ts=50.0e-6f;
    mg_app_t app; mg_app_init(&app); mg_app_output_t out={0};
    for(uint32_t k=0;k<4000u;++k){
        float angle=2.0f*pi*50.0f*k*ts;
        mg_app_raw_input_t raw=sample(40.8f*sinf(angle),40.8f*sinf(angle),10.0f*sinf(angle),k);
        out=mg_app_step(&app,&raw);
    }
    assert(out.state==MG_STATE_RUN && out.pwm_enable);
    assert(out.grid_mode==MG_GRID_CONNECTED && out.grid_breaker_close);
    assert(out.dc_duty_input_leg>=0.0f && out.dc_duty_input_leg<=0.98f);
    assert(out.dc_duty_output_leg>=0.0f && out.dc_duty_output_leg<=0.98f);
    assert(out.inverter_duty_leg_a>=0.025f && out.inverter_duty_leg_a<=0.975f);
    assert(out.inverter_duty_leg_b>=0.025f && out.inverter_duty_leg_b<=0.975f);
    assert(app.sunspec.registers[108]==4u);
    assert(app.sunspec.registers[80]>2700u && app.sunspec.registers[80]<3000u);
    assert((int16_t)app.sunspec.registers[84]>150);
    mg_app_raw_input_t trip=sample(0.0f,0.0f,30.0f,4000u);
    out=mg_app_step(&app,&trip);
    assert(out.state==MG_STATE_FAULT && !out.pwm_enable);
    assert((out.faults&MG_FAULT_GRID_OVERCURRENT)!=0u);
    assert(out.dc_duty_input_leg==0.0f && out.inverter_duty_leg_a==0.0f);
}

static void test_stale_adc_and_telemetry(void)
{
    mg_app_t app; mg_app_init(&app);
    mg_app_raw_input_t raw=sample(0.0f,0.0f,0.0f,1u);
    raw.start_request=false;
    for(int k=0;k<201;++k)mg_app_step(&app,&raw);
    assert(app.supervisor.state==MG_STATE_FAULT);
    assert((app.supervisor.latched_faults&MG_FAULT_SENSOR_INVALID)!=0u);
    assert(app.sunspec.registers[70]==101u);
    assert(app.sunspec.registers[108]==7u);
}

static void test_islanding_and_reconnect(void)
{
    const float pi=3.14159265358979323846f,ts=50.0e-6f;
    mg_app_t app; mg_app_init(&app); mg_app_output_t out={0};
    uint32_t k=0u;
    for(;k<4000u;++k){
        const float angle=2.0f*pi*50.0f*k*ts;
        out=mg_app_step(&app,&(mg_app_raw_input_t){
            .pv_voltage=encode(46.5f,MG_ADC_PV_VOLTAGE_ZERO_COUNT,MG_ADC_PV_VOLTAGE_UNITS_PER_COUNT),
            .dc_bus_voltage=encode(48.0f,MG_ADC_DC_BUS_VOLTAGE_ZERO_COUNT,MG_ADC_DC_BUS_VOLTAGE_UNITS_PER_COUNT),
            .pv_current=encode(10.0f,MG_ADC_PV_CURRENT_ZERO_COUNT,MG_ADC_PV_CURRENT_UNITS_PER_COUNT),
            .dc_inductor_current=encode(10.0f,MG_ADC_DC_INDUCTOR_CURRENT_ZERO_COUNT,MG_ADC_DC_INDUCTOR_CURRENT_UNITS_PER_COUNT),
            .grid_voltage=encode(40.8f*sinf(angle),MG_ADC_GRID_VOLTAGE_ZERO_COUNT,MG_ADC_GRID_VOLTAGE_UNITS_PER_COUNT),
            .utility_voltage=encode(40.8f*sinf(angle),MG_ADC_UTILITY_VOLTAGE_ZERO_COUNT,MG_ADC_UTILITY_VOLTAGE_UNITS_PER_COUNT),
            .grid_current=encode(7.0f*sinf(angle),MG_ADC_GRID_CURRENT_ZERO_COUNT,MG_ADC_GRID_CURRENT_UNITS_PER_COUNT),
            .heatsink_temperature=encode(35.0f,MG_ADC_HEATSINK_TEMPERATURE_ZERO_COUNT,MG_ADC_HEATSINK_TEMPERATURE_UNITS_PER_COUNT),
            .sequence=k,.start_request=true});
    }
    assert(out.grid_mode==MG_GRID_CONNECTED && out.grid_breaker_close);
    for(;k<6500u;++k){
        const float angle=2.0f*pi*50.0f*k*ts;
        mg_app_raw_input_t raw=sample(40.8f*sinf(angle),0.0f,7.0f*sinf(angle),k);
        out=mg_app_step(&app,&raw);
    }
    assert(out.state==MG_STATE_RUN && out.pwm_enable);
    assert(out.grid_mode==MG_GRID_ISLANDED && !out.grid_breaker_close);
    assert(out.ac_frequency_reference_hz>=48.0f && out.ac_frequency_reference_hz<=52.0f);
    assert(out.ac_voltage_reference_rms_v>=24.5f && out.ac_voltage_reference_rms_v<=31.7f);
    assert(out.inverter_duty_leg_a>=0.025f && out.inverter_duty_leg_a<=0.975f);
    for(;k<14000u;++k){
        const float angle=2.0f*pi*50.0f*k*ts;
        mg_app_raw_input_t raw=sample(40.8f*sinf(angle),40.8f*sinf(angle),7.0f*sinf(angle),k);
        out=mg_app_step(&app,&raw);
    }
    assert(out.grid_mode==MG_GRID_CONNECTED && out.grid_breaker_close);
}

int main(void)
{
    test_start_run_and_trip(); test_stale_adc_and_telemetry();
    test_islanding_and_reconnect();
    puts("PASS: integrated real-time application tests"); return 0;
}
