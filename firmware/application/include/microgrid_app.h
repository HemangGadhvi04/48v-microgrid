#ifndef MICROGRID_APP_H
#define MICROGRID_APP_H

#include "microgrid_control.h"
#include "microgrid_sunspec.h"

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint16_t pv_voltage;
    uint16_t dc_bus_voltage;
    uint16_t pv_current;
    uint16_t dc_inductor_current;
    uint16_t grid_voltage;
    uint16_t utility_voltage;
    uint16_t grid_current;
    uint16_t heatsink_temperature;
    uint32_t sequence;
    bool start_request;
    bool reset_request;
    bool emergency_stop;
    bool hardware_trip;
    bool adc_invalid;
    bool deadline_missed;
} mg_app_raw_input_t;

typedef struct {
    float pv_voltage_v;
    float dc_bus_voltage_v;
    float pv_current_a;
    float dc_inductor_current_a;
    float grid_voltage_v;
    float utility_voltage_v;
    float grid_current_a;
    float heatsink_temperature_c;
} mg_app_measurement_t;

typedef struct {
    float dc_duty_input_leg;
    float dc_duty_output_leg;
    float inverter_duty_leg_a;
    float inverter_duty_leg_b;
    float pv_voltage_reference_v;
    float grid_current_reference_a;
    bool pwm_enable;
    bool precharge_relay;
    bool main_contactor;
    bool grid_breaker_close;
    mg_grid_mode_t grid_mode;
    float ac_voltage_reference_rms_v;
    float ac_frequency_reference_hz;
    mg_operating_state_t state;
    uint32_t faults;
} mg_app_output_t;

typedef struct {
    mg_buck_boost_t dc_dc;
    mg_sogi_pll_t bus_pll;
    mg_sogi_pll_t utility_pll;
    mg_pr_t grid_current;
    mg_pi_t dc_bus_power;
    mg_po_mppt_t mppt;
    mg_supervisor_t supervisor;
    mg_supervisor_config_t supervisor_config;
    mg_droop_t droop;
    mg_grid_relay_t grid_relay;
    mg_grid_relay_config_t grid_relay_config;
    mg_sunspec_server_t sunspec;
    mg_app_measurement_t measurement;
    mg_app_output_t output;
    volatile uint32_t telemetry_generation;
    uint32_t tick;
    uint32_t previous_adc_sequence;
    uint16_t stale_sample_count;
    float pv_voltage_reference_v;
    float active_power_command_w;
    float active_power_filtered_w;
    float reactive_power_filtered_var;
    float grid_voltage_squared_filtered_v2;
    float grid_current_squared_filtered_a2;
    float lifetime_energy_wh;
    float grid_forming_theta_rad;
} mg_app_t;

void mg_app_init(mg_app_t *app);
mg_app_output_t mg_app_step(mg_app_t *app, const mg_app_raw_input_t *raw);

#endif
