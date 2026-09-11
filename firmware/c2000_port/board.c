#ifndef MG_C2000_TARGET
typedef int mg_f28379d_board_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "adc.h"
#include "pwm.h"
#include "protection.h"
#include "communications.h"
#include "interrupts.h"
#include "f28379d_board_contract.h"

static void configure_output(uint32_t pin)
{
    GPIO_setDirectionMode(pin, GPIO_DIR_MODE_OUT);
    GPIO_setPadConfig(pin, GPIO_PIN_TYPE_STD);
    GPIO_writePin(pin, 0u);
}

static void configure_gpio(void)
{
    GPIO_setPinConfig(GPIO_0_EPWM1A); GPIO_setPinConfig(GPIO_1_EPWM1B);
    GPIO_setPinConfig(GPIO_2_EPWM2A); GPIO_setPinConfig(GPIO_3_EPWM2B);
    GPIO_setPinConfig(GPIO_4_EPWM3A); GPIO_setPinConfig(GPIO_5_EPWM3B);
    GPIO_setPinConfig(GPIO_6_EPWM4A); GPIO_setPinConfig(GPIO_7_EPWM4B);
    GPIO_setPinConfig(GPIO_18_SCITXDB); GPIO_setPinConfig(GPIO_19_SCIRXDB);
    GPIO_setQualificationMode(MG_GPIO_RS485_RX, GPIO_QUAL_ASYNC);
    GPIO_setDirectionMode(MG_GPIO_TRIP_LATCH_N, GPIO_DIR_MODE_IN);
    GPIO_setDirectionMode(MG_GPIO_ESTOP_N, GPIO_DIR_MODE_IN);
    GPIO_setDirectionMode(MG_GPIO_BIAS_POWER_GOOD, GPIO_DIR_MODE_IN);
    GPIO_setQualificationMode(MG_GPIO_TRIP_LATCH_N, GPIO_QUAL_ASYNC);
    GPIO_setQualificationMode(MG_GPIO_ESTOP_N, GPIO_QUAL_ASYNC);

    configure_output(MG_GPIO_PRECHARGE_RELAY);
    configure_output(MG_GPIO_MAIN_CONTACTOR);
    configure_output(MG_GPIO_GRID_BREAKER);
    configure_output(MG_GPIO_PWM_ARM);
    configure_output(MG_GPIO_RS485_DRIVER_ENABLE);
    configure_output(MG_GPIO_ISR_TIMING_MARKER);
}

void mg_f28379d_configure_peripherals(void)
{
    SysCtl_disablePeripheral(SYSCTL_PERIPH_CLK_TBCLKSYNC);
    SysCtl_setEPWMClockDivider(SYSCTL_EPWMCLK_DIV_2); // Explicitly enforce 100MHz EPWMCLK from 200MHz SYSCLK


    configure_gpio();
    init_protection();
    init_epwm();
    init_adc();
    init_communications();
    init_interrupts();


    CPUTimer_stopTimer(CPUTIMER0_BASE);
    CPUTimer_setPreScaler(CPUTIMER0_BASE, 0u);
    CPUTimer_setPeriod(CPUTIMER0_BASE, UINT32_MAX);
    CPUTimer_reloadTimerCounter(CPUTIMER0_BASE);
    CPUTimer_startTimer(CPUTIMER0_BASE);

    start_epwm();
    SysCtl_enablePeripheral(SYSCTL_PERIPH_CLK_TBCLKSYNC);
}

#endif
