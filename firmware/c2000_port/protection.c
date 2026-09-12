#ifndef MG_C2000_TARGET
typedef int mg_f28379d_protection_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "protection.h"
#include "f28379d_board_contract.h"

static const uint32_t pwm_bases[4] = {EPWM1_BASE, EPWM2_BASE, EPWM3_BASE, EPWM4_BASE};

void init_protection(void)
{
    // Route TRIP_LATCH_N to TZ1 (Hardware Overcurrent/Fault)
    XBAR_setInputPin(XBAR_INPUT1, MG_GPIO_TRIP_LATCH_N);
    XBAR_lockInput(XBAR_INPUT1);

    // Route ESTOP_N to TZ2 (Emergency Stop Button)
    XBAR_setInputPin(XBAR_INPUT2, MG_GPIO_ESTOP_N);
    XBAR_lockInput(XBAR_INPUT2);

    uint16_t index;
    for(index = 0u; index < 4u; index++) {
        uint32_t base = pwm_bases[index];
        // Both TZ1 and TZ2 force PWMs LOW
        EPWM_setTripZoneAction(base, EPWM_TZ_ACTION_EVENT_TZA, EPWM_TZ_ACTION_LOW);
        EPWM_setTripZoneAction(base, EPWM_TZ_ACTION_EVENT_TZB, EPWM_TZ_ACTION_LOW);
        
        // Enable OSHT (One-Shot) for TZ1 and TZ2
        EPWM_enableTripZoneSignals(base, EPWM_TZ_SIGNAL_OSHT1 | EPWM_TZ_SIGNAL_OSHT2);
        
        // Boot up safe: force trip event initially
        EPWM_forceTripZoneEvent(base, EPWM_TZ_FORCE_EVENT_OST);
    }
}

void clear_pwm_trip(void)
{
    uint16_t index;
    for(index = 0u; index < 4u; index++) {
        EPWM_clearTripZoneFlag(pwm_bases[index], EPWM_TZ_FLAG_OST);
    }
}

void force_pwm_trip(void)
{
    uint16_t index;
    for(index = 0u; index < 4u; index++) {
        EPWM_forceTripZoneEvent(pwm_bases[index], EPWM_TZ_FORCE_EVENT_OST);
    }
}
#endif

bool is_pwm_tripped(uint16_t index) {
    if (index >= 4) return false;
    return (EPWM_getTripZoneFlagStatus(pwm_bases[index]) & EPWM_TZ_FLAG_OST) != 0;
}
