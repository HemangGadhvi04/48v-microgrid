#ifndef MG_C2000_TARGET
typedef int mg_f28379d_adc_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "adc.h"
#include "f28379d_board_contract.h"

static void configure_adc_module(uint32_t base)
{
    ADC_setPrescaler(base, ADC_CLK_DIV_4_0);
    ADC_setMode(base, ADC_RESOLUTION_12BIT, ADC_MODE_SINGLE_ENDED);
    ADC_setInterruptPulseMode(base, ADC_PULSE_END_OF_CONV);
    ADC_enableConverter(base);
}

static void setup_soc(uint32_t base, ADC_SOCNumber soc, ADC_Channel channel)
{
    ADC_setupSOC(base, soc, ADC_TRIGGER_EPWM1_SOCA, channel, MG_C2000_ADC_ACQPS);
}

void init_adc(void)
{
    configure_adc_module(ADCA_BASE);
    configure_adc_module(ADCB_BASE);
    configure_adc_module(ADCC_BASE);
    DEVICE_DELAY_US(1000u);
    setup_soc(ADCA_BASE, ADC_SOC_NUMBER0, ADC_CH_ADCIN14);
    setup_soc(ADCA_BASE, ADC_SOC_NUMBER1, ADC_CH_ADCIN3);
    setup_soc(ADCA_BASE, ADC_SOC_NUMBER2, ADC_CH_ADCIN2);
    setup_soc(ADCA_BASE, ADC_SOC_NUMBER3, ADC_CH_ADCIN0);
    setup_soc(ADCB_BASE, ADC_SOC_NUMBER0, ADC_CH_ADCIN3);
    setup_soc(ADCB_BASE, ADC_SOC_NUMBER1, ADC_CH_ADCIN2);
    setup_soc(ADCC_BASE, ADC_SOC_NUMBER0, ADC_CH_ADCIN3);
    setup_soc(ADCC_BASE, ADC_SOC_NUMBER1, ADC_CH_ADCIN2);
    ADC_setInterruptSource(ADCA_BASE, ADC_INT_NUMBER1, ADC_SOC_NUMBER3);
    ADC_clearInterruptStatus(ADCA_BASE, ADC_INT_NUMBER1);
    ADC_enableInterrupt(ADCA_BASE, ADC_INT_NUMBER1);
}

#endif
