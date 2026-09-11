#include "microgrid_control.h"

#include <math.h>

static float clampf(float value, float minimum, float maximum)
{
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

void mg_pi_init(mg_pi_t *controller, float kp, float ki,
                float sample_time_s, float minimum, float maximum)
{
    controller->kp = kp;
    controller->ki = ki;
    controller->sample_time_s = sample_time_s;
    controller->minimum = minimum;
    controller->maximum = maximum;
    controller->integrator = 0.0f;
}

void mg_pi_reset(mg_pi_t *controller, float output)
{
    controller->integrator = clampf(output, controller->minimum,
                                    controller->maximum);
}

float mg_pi_step(mg_pi_t *controller, float error, float feedforward)
{
    const float unsaturated = feedforward + controller->kp * error
                            + controller->integrator;
    const float output = clampf(unsaturated, controller->minimum,
                                controller->maximum);
    const bool drives_out_of_saturation =
        (unsaturated > controller->maximum && error < 0.0f)
        || (unsaturated < controller->minimum && error > 0.0f);
    if (output == unsaturated || drives_out_of_saturation) {
        controller->integrator += controller->ki
                                * controller->sample_time_s * error;
        controller->integrator = clampf(controller->integrator,
                                        controller->minimum,
                                        controller->maximum);
    }
    return output;
}

void mg_po_mppt_init(mg_po_mppt_t *tracker, float initial_step_v,
                     float minimum_v, float maximum_v)
{
    tracker->previous_voltage_v = 0.0f;
    tracker->previous_power_w = 0.0f;
    tracker->step_v = fabsf(initial_step_v);
    tracker->direction_v = tracker->step_v;
    tracker->minimum_v = minimum_v;
    tracker->maximum_v = maximum_v;
    tracker->initialized = false;
}

float mg_po_mppt_step(mg_po_mppt_t *tracker, float voltage_v, float current_a)
{
    const float power_w = voltage_v * current_a;
    if (tracker->initialized) {
        const float delta_power = power_w - tracker->previous_power_w;
        const float delta_voltage = voltage_v - tracker->previous_voltage_v;
        if (delta_voltage != 0.0f && delta_power < 0.0f) {
            tracker->direction_v = -tracker->direction_v;
        }
    } else {
        tracker->initialized = true;
    }
    tracker->previous_voltage_v = voltage_v;
    tracker->previous_power_w = power_w;

    float command_v = clampf(voltage_v + tracker->direction_v,
                             tracker->minimum_v, tracker->maximum_v);
    if (command_v <= tracker->minimum_v) {
        tracker->direction_v = tracker->step_v;
    } else if (command_v >= tracker->maximum_v) {
        tracker->direction_v = -tracker->step_v;
    }
    return command_v;
}

void mg_buck_boost_init(mg_buck_boost_t *controller,
                        float control_sample_time_s)
{
    mg_pi_init(&controller->pv_voltage, 1.0f, 150.0f,
               control_sample_time_s * 20.0f, 0.0f, 18.0f);
    mg_pi_init(&controller->inductor_current, 3.0f, 500.0f,
               control_sample_time_s, -60.0f, 60.0f);
    controller->maximum_inductor_current_a = 18.0f;
    controller->maximum_duty = 0.98f;
    controller->outer_loop_divider = 20u;
    controller->outer_loop_counter = 0u;
    controller->input_current_command_a = 0.0f;
    controller->inductor_current_command_a = 0.0f;
}

mg_buck_boost_output_t mg_buck_boost_step(
    mg_buck_boost_t *controller, bool enabled, float pv_voltage_v,
    float pv_current_a, float dc_bus_voltage_v, float inductor_current_a,
    float pv_voltage_reference_v)
{
    mg_buck_boost_output_t output = {0.0f, 0.0f, 0.0f, MG_CONVERTER_OFF};
    if (!enabled || pv_voltage_v < 1.0f || dc_bus_voltage_v < 1.0f) {
        mg_pi_reset(&controller->pv_voltage, 0.0f);
        mg_pi_reset(&controller->inductor_current, 0.0f);
        controller->outer_loop_counter = 0u;
        controller->input_current_command_a = 0.0f;
        controller->inductor_current_command_a = 0.0f;
        return output;
    }

    if (controller->outer_loop_counter == 0u) {
        const float voltage_error_v = pv_voltage_v - pv_voltage_reference_v;
        controller->input_current_command_a = mg_pi_step(
            &controller->pv_voltage, voltage_error_v, pv_current_a);
    }
    controller->outer_loop_counter = (uint16_t)(
        (controller->outer_loop_counter + 1u)
        % controller->outer_loop_divider);

    const float input_duty_estimate = clampf(dc_bus_voltage_v / pv_voltage_v,
                                             0.1f, 1.0f);
    controller->inductor_current_command_a = clampf(
        controller->input_current_command_a / input_duty_estimate,
        0.0f, controller->maximum_inductor_current_a);

    const float current_error_a = controller->inductor_current_command_a
                                - inductor_current_a;
    const float requested_inductor_voltage_v = mg_pi_step(
        &controller->inductor_current, current_error_a, 0.0f);

    if (pv_voltage_v - dc_bus_voltage_v >= requested_inductor_voltage_v) {
        output.mode = MG_CONVERTER_BUCK;
        output.duty_input_leg = clampf(
            (dc_bus_voltage_v + requested_inductor_voltage_v) / pv_voltage_v,
            0.0f, controller->maximum_duty);
        output.duty_output_leg = controller->maximum_duty;
    } else {
        output.mode = MG_CONVERTER_BOOST;
        output.duty_input_leg = controller->maximum_duty;
        output.duty_output_leg = clampf(
            (pv_voltage_v - requested_inductor_voltage_v) / dc_bus_voltage_v,
            0.0f, controller->maximum_duty);
    }
    output.inductor_current_command_a =
        controller->inductor_current_command_a;
    return output;
}

void mg_sogi_pll_init(mg_sogi_pll_t *pll, float sample_time_s,
                      float nominal_frequency_hz, float nominal_peak_voltage_v)
{
    const float pi = 3.14159265358979323846f;
    const float loop_bandwidth_rad_s = 2.0f * pi * 12.0f;
    pll->sample_time_s = sample_time_s;
    pll->nominal_omega_rad_s = 2.0f * pi * nominal_frequency_hz;
    pll->minimum_omega_rad_s = 2.0f * pi * 45.0f;
    pll->maximum_omega_rad_s = 2.0f * pi * 55.0f;
    pll->nominal_peak_voltage_v = nominal_peak_voltage_v;
    pll->sogi_gain = 1.41421356237f;
    pll->proportional_gain = 2.0f * 0.707f * loop_bandwidth_rad_s;
    pll->integral_gain = loop_bandwidth_rad_s * loop_bandwidth_rad_s;
    pll->alpha_v = 0.0f;
    pll->beta_v = 0.0f;
    pll->theta_rad = 0.0f;
    pll->omega_rad_s = pll->nominal_omega_rad_s;
    pll->loop_integrator = 0.0f;
    pll->lock_counter = 0u;
    pll->lock_samples = (uint16_t)(0.010f / sample_time_s + 0.5f);
    pll->locked = false;
}

mg_pll_output_t mg_sogi_pll_step(mg_sogi_pll_t *pll, float grid_voltage_v)
{
    const float pi = 3.14159265358979323846f;
    const float two_pi = 2.0f * pi;
    const float ts = pll->sample_time_s;
    const float da = pll->sogi_gain * pll->omega_rad_s
                   * (grid_voltage_v - pll->alpha_v)
                   - pll->omega_rad_s * pll->beta_v;
    const float db = pll->omega_rad_s * pll->alpha_v;
    const float alpha_predict = pll->alpha_v + ts * da;
    const float beta_predict = pll->beta_v + ts * db;
    pll->alpha_v += 0.5f * ts * (da
        + pll->sogi_gain * pll->omega_rad_s
        * (grid_voltage_v - alpha_predict)
        - pll->omega_rad_s * beta_predict);
    pll->beta_v += 0.5f * ts * (db
        + pll->omega_rad_s * alpha_predict);

    const float amplitude_v = hypotf(pll->alpha_v, pll->beta_v);
    const float normalization_v = fmaxf(amplitude_v,
                                        0.1f * pll->nominal_peak_voltage_v);
    const float q_error = (pll->alpha_v * cosf(pll->theta_rad)
                         + pll->beta_v * sinf(pll->theta_rad))
                        / normalization_v;
    const float unconstrained_omega = pll->nominal_omega_rad_s
                                    + pll->proportional_gain * q_error
                                    + pll->loop_integrator;
    pll->omega_rad_s = clampf(unconstrained_omega,
                              pll->minimum_omega_rad_s,
                              pll->maximum_omega_rad_s);
    const bool drives_out_of_saturation =
        (unconstrained_omega > pll->maximum_omega_rad_s && q_error < 0.0f)
        || (unconstrained_omega < pll->minimum_omega_rad_s && q_error > 0.0f);
    if (pll->omega_rad_s == unconstrained_omega || drives_out_of_saturation) {
        pll->loop_integrator += ts * pll->integral_gain * q_error;
    }

    pll->theta_rad += ts * pll->omega_rad_s;
    while (pll->theta_rad >= two_pi) pll->theta_rad -= two_pi;
    while (pll->theta_rad < 0.0f) pll->theta_rad += two_pi;

    const bool valid_signal = amplitude_v > 0.7f * pll->nominal_peak_voltage_v;
    const bool valid_phase = fabsf(q_error) < 0.04f;
    const bool valid_frequency = pll->omega_rad_s
        > pll->minimum_omega_rad_s + two_pi * 0.1f
        && pll->omega_rad_s < pll->maximum_omega_rad_s - two_pi * 0.1f;
    if (valid_signal && valid_phase && valid_frequency) {
        if (pll->lock_counter < pll->lock_samples) pll->lock_counter++;
    } else {
        pll->lock_counter = 0u;
    }
    pll->locked = pll->lock_counter >= pll->lock_samples;

    const mg_pll_output_t output = {
        .theta_rad = pll->theta_rad,
        .frequency_hz = pll->omega_rad_s / two_pi,
        .normalized_q_error = q_error,
        .amplitude_v = amplitude_v,
        .locked = pll->locked
    };
    return output;
}

void mg_pr_init(mg_pr_t *controller, float sample_time_s,
                float fundamental_frequency_hz, float minimum_output_v,
                float maximum_output_v)
{
    const float pi = 3.14159265358979323846f;
    controller->sample_time_s = sample_time_s;
    controller->proportional_gain = 0.65f;
    controller->resonant_gain = 28.0f;
    controller->resonant_bandwidth_rad_s = 2.0f * pi * 5.0f;
    controller->fundamental_omega_rad_s = 2.0f * pi
                                        * fundamental_frequency_hz;
    controller->state_1 = 0.0f;
    controller->state_2 = 0.0f;
    controller->minimum_output_v = minimum_output_v;
    controller->maximum_output_v = maximum_output_v;
}

void mg_pr_reset(mg_pr_t *controller)
{
    controller->state_1 = 0.0f;
    controller->state_2 = 0.0f;
}

float mg_pr_step(mg_pr_t *controller, float error_a, float feedforward_v)
{
    const float resonant_output_v = 2.0f * controller->resonant_bandwidth_rad_s
                                  * controller->state_2;
    const float unconstrained_v = feedforward_v
        + controller->proportional_gain * error_a
        + controller->resonant_gain * resonant_output_v;
    const float output_v = clampf(unconstrained_v, controller->minimum_output_v,
                                  controller->maximum_output_v);
    const bool drives_out_of_saturation =
        (unconstrained_v > controller->maximum_output_v && error_a < 0.0f)
        || (unconstrained_v < controller->minimum_output_v && error_a > 0.0f);
    if (output_v == unconstrained_v || drives_out_of_saturation) {
        const float ts = controller->sample_time_s;
        const float omega = controller->fundamental_omega_rad_s;
        const float d1 = controller->state_2;
        const float d2 = error_a
            - 2.0f * controller->resonant_bandwidth_rad_s * controller->state_2
            - omega * omega * controller->state_1;
        const float state_1_predict = controller->state_1 + ts * d1;
        const float state_2_predict = controller->state_2 + ts * d2;
        controller->state_1 += 0.5f * ts * (d1 + state_2_predict);
        controller->state_2 += 0.5f * ts * (d2 + error_a
            - 2.0f * controller->resonant_bandwidth_rad_s * state_2_predict
            - omega * omega * state_1_predict);
    }
    return output_v;
}

void mg_droop_init(mg_droop_t *droop, float sample_time_s,
                   float nominal_frequency_hz, float nominal_voltage_rms_v,
                   float rated_active_power_w, float rated_reactive_power_var)
{
    droop->sample_time_s=sample_time_s;
    droop->nominal_frequency_hz=nominal_frequency_hz;
    droop->nominal_voltage_rms_v=nominal_voltage_rms_v;
    droop->active_power_reference_w=0.4f*rated_active_power_w;
    droop->reactive_power_reference_var=0.0f;
    droop->frequency_droop_hz_per_w=1.0f/rated_active_power_w;
    droop->voltage_droop_v_per_var=1.5f/rated_reactive_power_var;
    droop->minimum_frequency_hz=nominal_frequency_hz-1.0f;
    droop->maximum_frequency_hz=nominal_frequency_hz+1.0f;
    droop->minimum_voltage_rms_v=0.85f*nominal_voltage_rms_v;
    droop->maximum_voltage_rms_v=1.10f*nominal_voltage_rms_v;
    droop->filter_alpha=1.0f-expf(-sample_time_s/0.020f);
    droop->active_power_filtered_w=droop->active_power_reference_w;
    droop->reactive_power_filtered_var=0.0f;
}

mg_droop_output_t mg_droop_step(mg_droop_t *droop,
                                float measured_active_power_w,
                                float measured_reactive_power_var)
{
    droop->active_power_filtered_w+=droop->filter_alpha
        *(measured_active_power_w-droop->active_power_filtered_w);
    droop->reactive_power_filtered_var+=droop->filter_alpha
        *(measured_reactive_power_var-droop->reactive_power_filtered_var);
    const float frequency=clampf(droop->nominal_frequency_hz
        -droop->frequency_droop_hz_per_w
        *(droop->active_power_filtered_w-droop->active_power_reference_w),
        droop->minimum_frequency_hz,droop->maximum_frequency_hz);
    const float voltage=clampf(droop->nominal_voltage_rms_v
        -droop->voltage_droop_v_per_var
        *(droop->reactive_power_filtered_var-droop->reactive_power_reference_var),
        droop->minimum_voltage_rms_v,droop->maximum_voltage_rms_v);
    const mg_droop_output_t output={frequency,voltage,
        droop->active_power_filtered_w,droop->reactive_power_filtered_var};
    return output;
}

void mg_grid_relay_init(mg_grid_relay_t *relay)
{
    relay->mode=MG_GRID_CONNECTED;
    relay->loss_counter=0u;
    relay->reconnect_counter=0u;
    relay->sync_integrator_hz=0.0f;
}

mg_grid_relay_output_t mg_grid_relay_step(
    mg_grid_relay_t *relay, const mg_grid_relay_config_t *config,
    float utility_voltage_rms_v, float bus_voltage_rms_v,
    float bus_frequency_hz, float grid_minus_bus_phase_rad)
{
    const bool utility_present=utility_voltage_rms_v
        >=config->utility_present_fraction*config->nominal_voltage_rms_v;
    bool island_detected=false;
    float frequency_bias=0.0f;
    float voltage_bias=0.0f;
    if(relay->mode==MG_GRID_CONNECTED){
        if(!utility_present){
            if(relay->loss_counter<config->loss_hold_samples)relay->loss_counter++;
            if(relay->loss_counter>=config->loss_hold_samples){
                relay->mode=MG_GRID_ISLANDED;relay->loss_counter=0u;
                island_detected=true;
            }
        }else relay->loss_counter=0u;
    }else if(relay->mode==MG_GRID_ISLANDED){
        if(utility_present){
            relay->mode=MG_GRID_SYNCHRONIZING;
            relay->reconnect_counter=0u;relay->sync_integrator_hz=0.0f;
        }
    }else{
        if(!utility_present){
            relay->mode=MG_GRID_ISLANDED;
            relay->reconnect_counter=0u;relay->sync_integrator_hz=0.0f;
        }else{
            relay->sync_integrator_hz+=config->sync_ki_hz_per_rad_s
                *grid_minus_bus_phase_rad*config->sample_time_s;
            relay->sync_integrator_hz=clampf(relay->sync_integrator_hz,
                -config->sync_frequency_limit_hz,config->sync_frequency_limit_hz);
            frequency_bias=clampf(config->sync_kp_hz_per_rad
                *grid_minus_bus_phase_rad+relay->sync_integrator_hz,
                -config->sync_frequency_limit_hz,config->sync_frequency_limit_hz);
            voltage_bias=clampf(config->sync_voltage_gain
                *(config->nominal_voltage_rms_v-bus_voltage_rms_v),-3.0f,3.0f);
            const bool qualified=fabsf(grid_minus_bus_phase_rad)<=config->phase_limit_rad
                &&fabsf(bus_frequency_hz-config->nominal_frequency_hz)
                    <=config->frequency_limit_hz
                &&fabsf(bus_voltage_rms_v-config->nominal_voltage_rms_v)
                    <=config->voltage_limit_fraction*config->nominal_voltage_rms_v;
            if(qualified){
                if(relay->reconnect_counter<config->reconnect_hold_samples)
                    relay->reconnect_counter++;
            }else relay->reconnect_counter=0u;
            if(relay->reconnect_counter>=config->reconnect_hold_samples){
                relay->mode=MG_GRID_CONNECTED;relay->reconnect_counter=0u;
                relay->sync_integrator_hz=0.0f;frequency_bias=0.0f;voltage_bias=0.0f;
            }
        }
    }
    const mg_grid_relay_output_t output={relay->mode,
        relay->mode==MG_GRID_CONNECTED,island_detected,frequency_bias,voltage_bias};
    return output;
}

void mg_supervisor_init(mg_supervisor_t *supervisor)
{
    supervisor->state = MG_STATE_OFF;
    supervisor->latched_faults = MG_FAULT_NONE;
    supervisor->state_ticks = 0u;
    supervisor->precharge_relay = false;
    supervisor->main_contactor = false;
    supervisor->pwm_enable = false;
}

static uint32_t active_faults(const mg_supervisor_config_t *config,
                              const mg_supervisor_input_t *input,
                              bool running)
{
    uint32_t faults = MG_FAULT_NONE;
    if (input->emergency_stop) faults |= MG_FAULT_ESTOP;
    if (input->hardware_trip) faults |= MG_FAULT_HARDWARE_TRIP;
    if (input->sensor_invalid) faults |= MG_FAULT_SENSOR_INVALID;
    if (input->deadline_missed) faults |= MG_FAULT_DEADLINE_MISSED;
    if (input->dc_bus_voltage_v > config->dc_bus_overvoltage_v)
        faults |= MG_FAULT_DC_OVERVOLTAGE;
    if (running && input->dc_bus_voltage_v < config->dc_bus_undervoltage_v)
        faults |= MG_FAULT_DC_UNDERVOLTAGE;
    if (fabsf(input->dc_current_a) > config->dc_current_trip_a)
        faults |= MG_FAULT_DC_OVERCURRENT;
    if (fabsf(input->grid_current_a) > config->grid_current_trip_a)
        faults |= MG_FAULT_GRID_OVERCURRENT;
    if (input->maximum_temperature_c > config->temperature_trip_c)
        faults |= MG_FAULT_OVERTEMPERATURE;
    return faults;
}

void mg_supervisor_step(mg_supervisor_t *supervisor,
                        const mg_supervisor_config_t *config,
                        const mg_supervisor_input_t *input)
{
    supervisor->state_ticks++;
    const uint32_t faults = active_faults(config, input,
                                          supervisor->state == MG_STATE_RUN);
    if (faults != MG_FAULT_NONE) {
        supervisor->latched_faults |= faults;
        supervisor->state = MG_STATE_FAULT;
        supervisor->state_ticks = 0u;
    }

    switch (supervisor->state) {
    case MG_STATE_OFF:
        if (input->start_request) {
            supervisor->state = MG_STATE_PRECHARGE;
            supervisor->state_ticks = 0u;
        }
        break;
    case MG_STATE_PRECHARGE:
        if (!input->start_request) {
            supervisor->state = MG_STATE_OFF;
            supervisor->state_ticks = 0u;
        } else if (input->dc_bus_voltage_v >= config->precharge_complete_v) {
            supervisor->state = MG_STATE_READY;
            supervisor->state_ticks = 0u;
        } else if (supervisor->state_ticks >= config->precharge_timeout_ticks) {
            supervisor->latched_faults |= MG_FAULT_PRECHARGE_TIMEOUT;
            supervisor->state = MG_STATE_FAULT;
            supervisor->state_ticks = 0u;
        }
        break;
    case MG_STATE_READY:
        if (!input->start_request) {
            supervisor->state = MG_STATE_OFF;
            supervisor->state_ticks = 0u;
        } else if (input->grid_locked) {
            supervisor->state = MG_STATE_RUN;
            supervisor->state_ticks = 0u;
        }
        break;
    case MG_STATE_RUN:
        if (!input->start_request || !input->grid_locked) {
            supervisor->state = MG_STATE_READY;
            supervisor->state_ticks = 0u;
        }
        break;
    case MG_STATE_FAULT:
        if (input->reset_request && faults == MG_FAULT_NONE
            && !input->start_request) {
            supervisor->latched_faults = MG_FAULT_NONE;
            supervisor->state = MG_STATE_OFF;
            supervisor->state_ticks = 0u;
        }
        break;
    default:
        supervisor->latched_faults |= MG_FAULT_HARDWARE_TRIP;
        supervisor->state = MG_STATE_FAULT;
        supervisor->state_ticks = 0u;
        break;
    }

    supervisor->precharge_relay = supervisor->state == MG_STATE_PRECHARGE;
    supervisor->main_contactor = supervisor->state == MG_STATE_READY
                              || supervisor->state == MG_STATE_RUN;
    supervisor->pwm_enable = supervisor->state == MG_STATE_RUN
                          && supervisor->latched_faults == MG_FAULT_NONE;
}
