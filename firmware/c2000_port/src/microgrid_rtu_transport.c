#include "microgrid_rtu_transport.h"

static void finish_frame(mg_c2000_rtu_transport_t *transport)
{
    transport->frames_received++;
    if(transport->overflow){
        transport->frames_discarded++;
    }else{
        const size_t response_length=mg_c2000_handle_modbus_frame(
            transport->runtime,transport->request,transport->request_length,
            transport->response,sizeof(transport->response));
        if(response_length>0u){
            transport->transmit(transport->transmit_context,transport->response,
                                response_length);
            transport->frames_replied++;
        }else transport->frames_discarded++;
    }
    transport->request_length=0u;
    transport->receiving=false;
    transport->overflow=false;
}

void mg_c2000_rtu_transport_init(mg_c2000_rtu_transport_t *transport,
                                 mg_c2000_runtime_t *runtime,
                                 mg_c2000_rtu_transmit_fn transmit,
                                 void *transmit_context,
                                 uint32_t timer_frequency_hz,
                                 uint32_t baud_rate)
{
    *transport=(mg_c2000_rtu_transport_t){0};
    transport->runtime=runtime;
    transport->transmit=transmit;
    transport->transmit_context=transmit_context;
    if(baud_rate>0u){
        const uint64_t numerator=(uint64_t)timer_frequency_hz*77u;
        transport->silent_interval_ticks=(uint32_t)((numerator
            +(uint64_t)baud_rate*2u-1u)/((uint64_t)baud_rate*2u));
    }
}

void mg_c2000_rtu_receive_byte(mg_c2000_rtu_transport_t *transport,
                               uint8_t byte, uint32_t now_ticks)
{
    if(transport->receiving
       &&now_ticks-transport->last_byte_ticks>=transport->silent_interval_ticks)
        finish_frame(transport);
    if(transport->request_length<sizeof(transport->request))
        transport->request[transport->request_length++]=byte;
    else transport->overflow=true;
    transport->last_byte_ticks=now_ticks;
    transport->receiving=true;
}

void mg_c2000_rtu_poll(mg_c2000_rtu_transport_t *transport,
                       uint32_t now_ticks)
{
    if(transport->receiving
       &&now_ticks-transport->last_byte_ticks>=transport->silent_interval_ticks)
        finish_frame(transport);
}
