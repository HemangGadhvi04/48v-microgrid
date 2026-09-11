#ifndef MG_C2000_TARGET
typedef int mg_f28379d_communications_build_disabled_t;
#else

#include "driverlib.h"
#include "device.h"
#include "board.h"
#include "communications.h"

void init_communications(void)
{
    SCI_disableModule(SCIB_BASE);
    SCI_setConfig(SCIB_BASE, DEVICE_LSPCLK_FREQ, 9600u,
        SCI_CONFIG_WLEN_8 | SCI_CONFIG_STOP_ONE | SCI_CONFIG_PAR_NONE);
    SCI_resetChannels(SCIB_BASE);
    SCI_enableFIFO(SCIB_BASE);
    SCI_resetRxFIFO(SCIB_BASE);
    SCI_resetTxFIFO(SCIB_BASE);
    SCI_enableModule(SCIB_BASE);
}
#endif
