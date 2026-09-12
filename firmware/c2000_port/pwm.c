#ifndef MG_C2000_TARGET
typedef int mg_f28379d_pwm_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "pwm.h"
#include "f28379d_board_contract.h"

static const uint32_t pwm_bases[4] = {EPWM1_BASE, EPWM2_BASE, EPWM3_BASE, EPWM4_BASE};

static void configure_one_pwm(uint32_t base)
{
    EPWM_setTimeBaseCounterMode(base, EPWM_COUNTER_MODE_STOP_FREEZE);
    EPWM_setClockPrescaler(base, EPWM_CLOCK_DIVIDER_1, EPWM_HSCLOCK_DIVIDER_1);
    EPWM_setTimeBasePeriod(base, MG_C2000_PWM_TBPRD);
    EPWM_setTimeBaseCounter(base, 0u);
    EPWM_setPhaseShift(base, 0u);
    EPWM_setCounterCompareValue(base, EPWM_COUNTER_COMPARE_A, 0u);
    EPWM_setCounterCompareShadowLoadMode(base, EPWM_COUNTER_COMPARE_A, EPWM_COMP_LOAD_ON_CNTR_ZERO);
    EPWM_setActionQualifierAction(base, EPWM_AQ_OUTPUT_A, EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_TIMEBASE_UP_CMPA);
    EPWM_setActionQualifierAction(base, EPWM_AQ_OUTPUT_A, EPWM_AQ_OUTPUT_HIGH, EPWM_AQ_OUTPUT_ON_TIMEBASE_DOWN_CMPA);

    EPWM_setRisingEdgeDeadBandDelayInput(base, EPWM_DB_INPUT_EPWMA);
    EPWM_setFallingEdgeDeadBandDelayInput(base, EPWM_DB_INPUT_EPWMA);
    EPWM_setDeadBandDelayMode(base, EPWM_DB_RED, true);
    EPWM_setDeadBandDelayMode(base, EPWM_DB_FED, true);
    EPWM_setDeadBandDelayPolarity(base, EPWM_DB_RED, EPWM_DB_POLARITY_ACTIVE_HIGH);
    EPWM_setDeadBandDelayPolarity(base, EPWM_DB_FED, EPWM_DB_POLARITY_ACTIVE_LOW);

    // Explicitly tie DB clock to TBCLK for deterministic timing
    EPWM_setDeadBandCounterClock(base, EPWM_DB_COUNTER_CLOCK_FULL_CYCLE);

    EPWM_setRisingEdgeDelayCount(base, MG_C2000_PWM_DEADBAND_COUNTS);
    EPWM_setFallingEdgeDelayCount(base, MG_C2000_PWM_DEADBAND_COUNTS);
}

void init_epwm(void)
{
    uint16_t index;
    for (index = 0u; index < 4u; index++) configure_one_pwm(pwm_bases[index]);

    EPWM_setADCTriggerSource(EPWM1_BASE, EPWM_SOC_A, EPWM_SOC_TBCTR_ZERO);
    EPWM_setADCTriggerEventPrescale(EPWM1_BASE, EPWM_SOC_A, 1u);
    EPWM_enableADCTrigger(EPWM1_BASE, EPWM_SOC_A);
}

void start_epwm(void)
{
    uint16_t index;
    for(index = 0u; index < 4u; index++) {
        EPWM_setTimeBaseCounterMode(pwm_bases[index], EPWM_COUNTER_MODE_UP_DOWN);
    }
}
#endif

void enable_pwm_switching(uint16_t index) {
    if (index >= 4) return;
    EPWM_setActionQualifierContSWForceAction(pwm_bases[index], EPWM_AQ_OUTPUT_A, EPWM_AQ_SW_DISABLED);
    EPWM_setActionQualifierContSWForceAction(pwm_bases[index], EPWM_AQ_OUTPUT_B, EPWM_AQ_SW_DISABLED);
}
void disable_pwm_switching(uint16_t index) {
    if (index >= 4) return;
    EPWM_setActionQualifierContSWForceAction(pwm_bases[index], EPWM_AQ_OUTPUT_A, EPWM_AQ_SW_OUTPUT_LOW);
    EPWM_setActionQualifierContSWForceAction(pwm_bases[index], EPWM_AQ_OUTPUT_B, EPWM_AQ_SW_OUTPUT_LOW);
}
