#ifndef MICROGRID_CONTROL_H
#define MICROGRID_CONTROL_H

#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float kp;
    float ki;
    float sample_time_s;
    float minimum;
    float maximum;
    float integrator;
} mg_pi_t;

void mg_pi_init(mg_pi_t *controller, float kp, float ki,
                float sample_time_s, float minimum, float maximum);
void mg_pi_reset(mg_pi_t *controller, float output);
float mg_pi_step(mg_pi_t *controller, float error, float feedforward);

typedef struct {
    float previous_voltage_v;
    float previous_power_w;
    float direction_v;
    float step_v;
    float minimum_v;
    float maximum_v;
    bool initialized;
} mg_po_mppt_t;

void mg_po_mppt_init(mg_po_mppt_t *tracker, float initial_step_v,
                     float minimum_v, float maximum_v);
float mg_po_mppt_step(mg_po_mppt_t *tracker, float voltage_v, float current_a);

typedef enum {
    MG_CONVERTER_OFF = 0,
    MG_CONVERTER_BUCK,
    MG_CONVERTER_BOOST
} mg_converter_mode_t;

typedef struct {
    mg_pi_t pv_voltage;
    mg_pi_t inductor_current;
    float maximum_inductor_current_a;
    float maximum_duty;
    uint16_t outer_loop_divider;
    uint16_t outer_loop_counter;
    float input_current_command_a;
    float inductor_current_command_a;
} mg_buck_boost_t;

typedef struct {
    float duty_input_leg;
    float duty_output_leg;
    float inductor_current_command_a;
    mg_converter_mode_t mode;
} mg_buck_boost_output_t;

void mg_buck_boost_init(mg_buck_boost_t *controller,
                        float control_sample_time_s);
mg_buck_boost_output_t mg_buck_boost_step(
    mg_buck_boost_t *controller, bool enabled, float pv_voltage_v,
    float pv_current_a, float dc_bus_voltage_v, float inductor_current_a,
    float pv_voltage_reference_v);

typedef struct {
    float sample_time_s;
    float nominal_omega_rad_s;
    float minimum_omega_rad_s;
    float maximum_omega_rad_s;
    float nominal_peak_voltage_v;
    float sogi_gain;
    float proportional_gain;
    float integral_gain;
    float alpha_v;
    float beta_v;
    float theta_rad;
    float omega_rad_s;
    float loop_integrator;
    uint16_t lock_counter;
    uint16_t lock_samples;
    bool locked;
} mg_sogi_pll_t;

typedef struct {
    float theta_rad;
    float frequency_hz;
    float normalized_q_error;
    float amplitude_v;
    bool locked;
} mg_pll_output_t;

void mg_sogi_pll_init(mg_sogi_pll_t *pll, float sample_time_s,
                      float nominal_frequency_hz, float nominal_peak_voltage_v);
mg_pll_output_t mg_sogi_pll_step(mg_sogi_pll_t *pll, float grid_voltage_v);

typedef struct {
    float sample_time_s;
    float proportional_gain;
    float resonant_gain;
    float resonant_bandwidth_rad_s;
    float fundamental_omega_rad_s;
    float state_1;
    float state_2;
    float minimum_output_v;
    float maximum_output_v;
} mg_pr_t;

void mg_pr_init(mg_pr_t *controller, float sample_time_s,
                float fundamental_frequency_hz, float minimum_output_v,
                float maximum_output_v);
void mg_pr_reset(mg_pr_t *controller);
float mg_pr_step(mg_pr_t *controller, float error_a, float feedforward_v);

typedef struct {
    float sample_time_s;
    float nominal_frequency_hz;
    float nominal_voltage_rms_v;
    float active_power_reference_w;
    float reactive_power_reference_var;
    float frequency_droop_hz_per_w;
    float voltage_droop_v_per_var;
    float minimum_frequency_hz;
    float maximum_frequency_hz;
    float minimum_voltage_rms_v;
    float maximum_voltage_rms_v;
    float filter_alpha;
    float active_power_filtered_w;
    float reactive_power_filtered_var;
} mg_droop_t;

typedef struct {
    float frequency_reference_hz;
    float voltage_reference_rms_v;
    float active_power_filtered_w;
    float reactive_power_filtered_var;
} mg_droop_output_t;

void mg_droop_init(mg_droop_t *droop, float sample_time_s,
                   float nominal_frequency_hz, float nominal_voltage_rms_v,
                   float rated_active_power_w, float rated_reactive_power_var);
mg_droop_output_t mg_droop_step(mg_droop_t *droop,
                                float measured_active_power_w,
                                float measured_reactive_power_var);

typedef enum {
    MG_GRID_CONNECTED = 0,
    MG_GRID_ISLANDED,
    MG_GRID_SYNCHRONIZING
} mg_grid_mode_t;

typedef struct {
    float sample_time_s;
    float nominal_frequency_hz;
    float nominal_voltage_rms_v;
    float utility_present_fraction;
    float phase_limit_rad;
    float frequency_limit_hz;
    float voltage_limit_fraction;
    uint16_t loss_hold_samples;
    uint16_t reconnect_hold_samples;
    float sync_kp_hz_per_rad;
    float sync_ki_hz_per_rad_s;
    float sync_frequency_limit_hz;
    float sync_voltage_gain;
} mg_grid_relay_config_t;

typedef struct {
    mg_grid_mode_t mode;
    uint16_t loss_counter;
    uint16_t reconnect_counter;
    float sync_integrator_hz;
} mg_grid_relay_t;

typedef struct {
    mg_grid_mode_t mode;
    bool breaker_close_command;
    bool island_detected;
    float synchronization_frequency_bias_hz;
    float synchronization_voltage_bias_v;
} mg_grid_relay_output_t;

void mg_grid_relay_init(mg_grid_relay_t *relay);
mg_grid_relay_output_t mg_grid_relay_step(
    mg_grid_relay_t *relay, const mg_grid_relay_config_t *config,
    float utility_voltage_rms_v, float bus_voltage_rms_v,
    float bus_frequency_hz, float grid_minus_bus_phase_rad);

typedef enum {
    MG_STATE_OFF = 0,
    MG_STATE_PRECHARGE,
    MG_STATE_READY,
    MG_STATE_RUN,
    MG_STATE_FAULT
} mg_operating_state_t;

enum {
    MG_FAULT_NONE = 0u,
    MG_FAULT_ESTOP = 1u << 0,
    MG_FAULT_HARDWARE_TRIP = 1u << 1,
    MG_FAULT_DC_OVERVOLTAGE = 1u << 2,
    MG_FAULT_DC_UNDERVOLTAGE = 1u << 3,
    MG_FAULT_DC_OVERCURRENT = 1u << 4,
    MG_FAULT_GRID_OVERCURRENT = 1u << 5,
    MG_FAULT_OVERTEMPERATURE = 1u << 6,
    MG_FAULT_PRECHARGE_TIMEOUT = 1u << 7,
    MG_FAULT_SENSOR_INVALID = 1u << 8,
    MG_FAULT_DEADLINE_MISSED = 1u << 9
};

typedef struct {
    float dc_bus_undervoltage_v;
    float dc_bus_overvoltage_v;
    float dc_current_trip_a;
    float grid_current_trip_a;
    float temperature_trip_c;
    float precharge_complete_v;
    uint32_t precharge_timeout_ticks;
} mg_supervisor_config_t;

typedef struct {
    bool start_request;
    bool reset_request;
    bool grid_locked;
    bool emergency_stop;
    bool hardware_trip;
    bool sensor_invalid;
    bool deadline_missed;
    float dc_bus_voltage_v;
    float dc_current_a;
    float grid_current_a;
    float maximum_temperature_c;
} mg_supervisor_input_t;

typedef struct {
    mg_operating_state_t state;
    uint32_t latched_faults;
    uint32_t state_ticks;
    bool precharge_relay;
    bool main_contactor;
    bool pwm_enable;
} mg_supervisor_t;

void mg_supervisor_init(mg_supervisor_t *supervisor);
void mg_supervisor_step(mg_supervisor_t *supervisor,
                        const mg_supervisor_config_t *config,
                        const mg_supervisor_input_t *input);

#endif
