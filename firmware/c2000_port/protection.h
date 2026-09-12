#ifndef MG_PROTECTION_H
#define MG_PROTECTION_H

void init_protection(void);
void clear_pwm_trip(void);
bool is_pwm_tripped(uint16_t index);
void force_pwm_trip(void);

#endif
