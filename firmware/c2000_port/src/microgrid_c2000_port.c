#include "microgrid_c2000_port.h"

static mg_app_output_t inactive_output(uint32_t faults)
{
    mg_app_output_t output={0};
    output.state=MG_STATE_FAULT;
    output.faults=faults;
    return output;
}

void mg_c2000_runtime_init(mg_c2000_runtime_t *runtime,
                           const mg_c2000_hal_t *hal)
{
    runtime->hal=*hal;
    runtime->adc_sequence=0u;
    runtime->last_execution_ticks=0u;
    runtime->maximum_execution_ticks=0u;
    runtime->adc_invalid_pending=false;
    runtime->deadline_missed_pending=false;
    mg_app_init(&runtime->app);
}

void mg_c2000_control_isr(mg_c2000_runtime_t *runtime)
{
    const uint32_t start=runtime->hal.read_time_ticks(runtime->hal.context);
    mg_app_raw_input_t raw={0};
    const bool adc_complete=runtime->hal.read_adc_set(runtime->hal.context,&raw);
    const mg_c2000_digital_input_t digital=
        runtime->hal.read_digital_inputs(runtime->hal.context);
    raw.sequence=runtime->adc_sequence++;
    raw.start_request=digital.start_request;
    raw.reset_request=digital.reset_request;
    raw.emergency_stop=digital.emergency_stop;
    raw.hardware_trip=digital.hardware_trip;
    raw.adc_invalid=runtime->adc_invalid_pending || !adc_complete;
    raw.deadline_missed=runtime->deadline_missed_pending;

    mg_app_output_t output;
    if (adc_complete) output=mg_app_step(&runtime->app,&raw);
    else {
        runtime->adc_invalid_pending=true;
        output=inactive_output(MG_FAULT_SENSOR_INVALID);
    }

    const uint32_t end=runtime->hal.read_time_ticks(runtime->hal.context);
    runtime->last_execution_ticks=end-start;
    if(runtime->last_execution_ticks>runtime->maximum_execution_ticks)
        runtime->maximum_execution_ticks=runtime->last_execution_ticks;
    const uint32_t deadline_ticks=35u*runtime->hal.timer_ticks_per_microsecond;
    if(deadline_ticks==0u || runtime->last_execution_ticks>deadline_ticks){
        runtime->deadline_missed_pending=true;
        output.pwm_enable=false;
        output.dc_duty_input_leg=0.0f;
        output.dc_duty_output_leg=0.0f;
        output.inverter_duty_leg_a=0.0f;
        output.inverter_duty_leg_b=0.0f;
        output.grid_breaker_close=false;
    }else if(adc_complete){
        runtime->deadline_missed_pending=false;
    }
    if(adc_complete)runtime->adc_invalid_pending=false;
    runtime->hal.apply_outputs(runtime->hal.context,&output);
    if(output.state!=MG_STATE_FAULT)
        runtime->hal.service_watchdog(runtime->hal.context);
    runtime->hal.acknowledge_control_interrupt(runtime->hal.context);
}

size_t mg_c2000_handle_modbus_frame(mg_c2000_runtime_t *runtime,
                                    const uint8_t *request,
                                    size_t request_length,
                                    uint8_t *response,
                                    size_t response_capacity)
{
    mg_sunspec_server_t snapshot;
    uint32_t before;
    uint32_t after;
    do {
        before=runtime->app.telemetry_generation;
        for(size_t index=0u;index<MG_SUNSPEC_REGISTER_COUNT;index++)
            snapshot.registers[index]=
                ((const volatile uint16_t *)runtime->app.sunspec.registers)[index];
        snapshot.unit_id=runtime->app.sunspec.unit_id;
        after=runtime->app.telemetry_generation;
    } while((before&1u)!=0u || before!=after);
    return mg_sunspec_handle_rtu(&snapshot,request,request_length,
                                 response,response_capacity);
}
