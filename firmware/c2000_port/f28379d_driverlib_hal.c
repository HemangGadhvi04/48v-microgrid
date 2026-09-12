/* Build only for CPU1 with TI C2000Ware and MG_C2000_TARGET defined. */
#ifndef MG_C2000_TARGET
typedef int mg_f28379d_target_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "microgrid_c2000_port.h"
#include "microgrid_rtu_transport.h"
#include "f28379d_board_contract.h"
#include "protection.h"
#include "pwm.h"

static mg_c2000_runtime_t runtime;
static mg_c2000_rtu_transport_t rtu_transport;
static volatile bool start_request;
static volatile bool reset_request;

static const uint32_t pwm_bases[4]={MG_PWM_DC_INPUT_BASE,MG_PWM_DC_OUTPUT_BASE,
    MG_PWM_INVERTER_A_BASE,MG_PWM_INVERTER_B_BASE};

static bool target_read_adc(void *context,mg_app_raw_input_t *raw)
{
    (void)context;
    if(!ADC_getInterruptStatus(ADCA_BASE,ADC_INT_NUMBER1))return false;
    raw->pv_voltage=ADC_readResult(MG_ADC_PV_VOLTAGE_RESULT_BASE,MG_ADC_PV_VOLTAGE_SOC);
    raw->dc_inductor_current=ADC_readResult(MG_ADC_DC_INDUCTOR_CURRENT_RESULT_BASE,MG_ADC_DC_INDUCTOR_CURRENT_SOC);
    raw->grid_current=ADC_readResult(MG_ADC_GRID_CURRENT_RESULT_BASE,MG_ADC_GRID_CURRENT_SOC);
    raw->heatsink_temperature=ADC_readResult(MG_ADC_HEATSINK_TEMPERATURE_RESULT_BASE,MG_ADC_HEATSINK_TEMPERATURE_SOC);
    raw->pv_current=ADC_readResult(MG_ADC_PV_CURRENT_RESULT_BASE,MG_ADC_PV_CURRENT_SOC);
    raw->utility_voltage=ADC_readResult(MG_ADC_UTILITY_VOLTAGE_RESULT_BASE,MG_ADC_UTILITY_VOLTAGE_SOC);
    raw->dc_bus_voltage=ADC_readResult(MG_ADC_DC_BUS_VOLTAGE_RESULT_BASE,MG_ADC_DC_BUS_VOLTAGE_SOC);
    raw->grid_voltage=ADC_readResult(MG_ADC_GRID_VOLTAGE_RESULT_BASE,MG_ADC_GRID_VOLTAGE_SOC);
    return true;
}

static mg_c2000_digital_input_t target_read_digital(void *context)
{
    (void)context;
    const mg_c2000_digital_input_t input={
        .start_request=start_request,
        .reset_request=reset_request,
        .emergency_stop=GPIO_readPin(MG_GPIO_ESTOP_N)==0u,
        .hardware_trip=GPIO_readPin(MG_GPIO_TRIP_LATCH_N)==0u
            ||GPIO_readPin(MG_GPIO_BIAS_POWER_GOOD)==0u || is_pwm_tripped(0) || is_pwm_tripped(1) || is_pwm_tripped(2) || is_pwm_tripped(3)};
    if (reset_request && GPIO_readPin(MG_GPIO_TRIP_LATCH_N)!=0u && GPIO_readPin(MG_GPIO_ESTOP_N)!=0u && GPIO_readPin(MG_GPIO_BIAS_POWER_GOOD)!=0u) {
        clear_pwm_trip();
    }
    reset_request=false;
    return input;
}

static uint32_t target_time(void *context)
{
    (void)context;
    return UINT32_MAX-CPUTimer_getTimerCount(CPUTIMER0_BASE);
}

static uint16_t compare_from_duty(float duty)
{
    if(duty<=0.0f)return 0u;
    if(duty>=1.0f)return MG_C2000_PWM_TBPRD;
    return (uint16_t)(duty*(float)MG_C2000_PWM_TBPRD+0.5f);
}

static void target_apply(void *context,const mg_app_output_t *output)
{
    (void)context;
    const float duties[4]={output->dc_duty_input_leg,output->dc_duty_output_leg,
        output->inverter_duty_leg_a,output->inverter_duty_leg_b};
    uint16_t index;
    for(index=0u;index<4u;index++)
        EPWM_setCounterCompareValue(pwm_bases[index],EPWM_COUNTER_COMPARE_A,
                                    compare_from_duty(duties[index]));
    const bool hardware_safe=GPIO_readPin(MG_GPIO_TRIP_LATCH_N)!=0u
        &&GPIO_readPin(MG_GPIO_ESTOP_N)!=0u
        &&GPIO_readPin(MG_GPIO_BIAS_POWER_GOOD)!=0u;
    if (output->pwm_enable && hardware_safe) {
        for (uint16_t i = 0; i < 4; i++) { enable_pwm_switching(i); }
        GPIO_writePin(MG_GPIO_PWM_ARM, 1u);
    } else {
        GPIO_writePin(MG_GPIO_PWM_ARM, 0u);
        for (uint16_t i = 0; i < 4; i++) { disable_pwm_switching(i); }
    }
    GPIO_writePin(MG_GPIO_PRECHARGE_RELAY,output->precharge_relay?1u:0u);
    GPIO_writePin(MG_GPIO_MAIN_CONTACTOR,output->main_contactor?1u:0u);
    GPIO_writePin(MG_GPIO_GRID_BREAKER,output->grid_breaker_close?1u:0u);
}

static void target_watchdog(void *context){(void)context;SysCtl_serviceWatchdog();}

static void target_acknowledge(void *context)
{
    (void)context;
    GPIO_writePin(MG_GPIO_ISR_TIMING_MARKER,0u);
    ADC_clearInterruptStatus(ADCA_BASE,ADC_INT_NUMBER1);
    if(ADC_getInterruptOverflowStatus(ADCA_BASE,ADC_INT_NUMBER1)){
        ADC_clearInterruptOverflowStatus(ADCA_BASE,ADC_INT_NUMBER1);
        ADC_clearInterruptStatus(ADCA_BASE,ADC_INT_NUMBER1);
    }
    Interrupt_clearACKGroup(INTERRUPT_ACK_GROUP1);
}

static void target_transmit(void *context,const uint8_t *data,size_t length)
{
    (void)context;
    GPIO_writePin(MG_GPIO_RS485_DRIVER_ENABLE,1u);
    for(size_t index=0u;index<length;index++)
        SCI_writeCharBlockingFIFO(SCIB_BASE,(uint16_t)data[index]);
    while(SCI_isTransmitterBusy(SCIB_BASE)){}
    GPIO_writePin(MG_GPIO_RS485_DRIVER_ENABLE,0u);
}

void mg_f28379d_set_run_request(bool run){start_request=run;}
void mg_f28379d_request_fault_reset(void){reset_request=true;}

void mg_f28379d_service_serial(void)
{
    uint32_t now=target_time(0);
    while(SCI_getRxFIFOStatus(SCIB_BASE)!=SCI_FIFO_RX0){
        const uint8_t byte=(uint8_t)SCI_readCharNonBlocking(SCIB_BASE);
        now=target_time(0);
        mg_c2000_rtu_receive_byte(&rtu_transport,byte,now);
    }
    mg_c2000_rtu_poll(&rtu_transport,now);
}

__interrupt void mg_f28379d_control_isr(void)
{
    GPIO_writePin(MG_GPIO_ISR_TIMING_MARKER,1u);
    mg_c2000_control_isr(&runtime);
}

void mg_f28379d_bind_runtime(void)
{
    const mg_c2000_hal_t hal={
        .context=0,.read_adc_set=target_read_adc,
        .read_digital_inputs=target_read_digital,.read_time_ticks=target_time,
        .apply_outputs=target_apply,.service_watchdog=target_watchdog,
        .acknowledge_control_interrupt=target_acknowledge,
        .timer_ticks_per_microsecond=MG_C2000_CPU_CLOCK_HZ/1000000UL};
    start_request=false;reset_request=false;
    mg_c2000_runtime_init(&runtime,&hal);
    mg_c2000_rtu_transport_init(&rtu_transport,&runtime,target_transmit,0,
                                MG_C2000_CPU_CLOCK_HZ,9600u);
}
#endif
