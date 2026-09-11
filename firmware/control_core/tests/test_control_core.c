#include "microgrid_control.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>

static void test_pi_anti_windup(void)
{
    mg_pi_t pi;
    mg_pi_init(&pi, 1.0f, 10.0f, 0.001f, -1.0f, 1.0f);
    for (int k = 0; k < 1000; ++k) {
        assert(mg_pi_step(&pi, 10.0f, 0.0f) == 1.0f);
    }
    assert(fabsf(pi.integrator) < 1.0e-6f);
    assert(mg_pi_step(&pi, -0.5f, 0.0f) < 0.0f);
}

static void test_po_mppt_tracks_peak(void)
{
    mg_po_mppt_t tracker;
    mg_po_mppt_init(&tracker, 0.2f, 5.0f, 57.0f);
    float voltage_v = 20.0f;
    for (int k = 0; k < 400; ++k) {
        const float power_w = 500.0f - 0.8f * (voltage_v - 46.5f)
                            * (voltage_v - 46.5f);
        voltage_v = mg_po_mppt_step(&tracker, voltage_v,
                                    power_w / voltage_v);
    }
    assert(fabsf(voltage_v - 46.5f) <= 0.4f);
}

static void test_buck_boost_modes_and_bounds(void)
{
    mg_buck_boost_t control;
    mg_buck_boost_init(&control, 50.0e-6f);
    mg_buck_boost_output_t output = mg_buck_boost_step(
        &control, false, 52.0f, 8.0f, 48.0f, 8.0f, 46.0f);
    assert(output.mode == MG_CONVERTER_OFF);
    assert(output.duty_input_leg == 0.0f && output.duty_output_leg == 0.0f);

    /* Excess inductor current requires negative inductor voltage and selects
       the buck switching state at this PV-above-bus operating point. */
    output = mg_buck_boost_step(&control, true, 54.0f, 8.0f,
                                48.0f, 18.0f, 46.0f);
    assert(output.mode == MG_CONVERTER_BUCK);
    assert(output.duty_input_leg >= 0.0f && output.duty_input_leg <= 0.98f);
    assert(output.duty_output_leg >= 0.0f && output.duty_output_leg <= 0.98f);

    mg_buck_boost_init(&control, 50.0e-6f);
    output = mg_buck_boost_step(&control, true, 42.0f, 8.0f,
                                48.0f, 0.0f, 46.0f);
    assert(output.mode == MG_CONVERTER_BOOST);
    assert(output.duty_input_leg >= 0.0f && output.duty_input_leg <= 0.98f);
    assert(output.duty_output_leg >= 0.0f && output.duty_output_leg <= 0.98f);
    assert(output.inductor_current_command_a <= 18.0f);
}

static mg_supervisor_config_t default_supervisor_config(void)
{
    const mg_supervisor_config_t config = {
        .dc_bus_undervoltage_v = 38.0f,
        .dc_bus_overvoltage_v = 56.0f,
        .dc_current_trip_a = 22.0f,
        .grid_current_trip_a = 28.0f,
        .temperature_trip_c = 90.0f,
        .precharge_complete_v = 43.0f,
        .precharge_timeout_ticks = 5u
    };
    return config;
}

static void test_supervisor_sequence_and_latched_trip(void)
{
    mg_supervisor_t supervisor;
    mg_supervisor_init(&supervisor);
    const mg_supervisor_config_t config = default_supervisor_config();
    mg_supervisor_input_t input = {
        .start_request = true, .grid_locked = false,
        .dc_bus_voltage_v = 0.0f, .maximum_temperature_c = 25.0f
    };

    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_PRECHARGE);
    assert(supervisor.precharge_relay && !supervisor.pwm_enable);

    input.dc_bus_voltage_v = 45.0f;
    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_READY && supervisor.main_contactor);

    input.grid_locked = true;
    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_RUN && supervisor.pwm_enable);

    input.dc_current_a = 23.0f;
    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_FAULT && !supervisor.pwm_enable);
    assert((supervisor.latched_faults & MG_FAULT_DC_OVERCURRENT) != 0u);

    input.dc_current_a = 0.0f;
    input.start_request = false;
    input.reset_request = true;
    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_OFF);
    assert(supervisor.latched_faults == MG_FAULT_NONE);
}

static void test_precharge_timeout(void)
{
    mg_supervisor_t supervisor;
    mg_supervisor_init(&supervisor);
    const mg_supervisor_config_t config = default_supervisor_config();
    mg_supervisor_input_t input = {
        .start_request = true, .dc_bus_voltage_v = 10.0f,
        .maximum_temperature_c = 25.0f
    };
    for (int k = 0; k < 7; ++k) {
        mg_supervisor_step(&supervisor, &config, &input);
    }
    assert(supervisor.state == MG_STATE_FAULT);
    assert((supervisor.latched_faults & MG_FAULT_PRECHARGE_TIMEOUT) != 0u);
}

static void test_sensor_and_deadline_faults(void)
{
    mg_supervisor_t supervisor;
    mg_supervisor_init(&supervisor);
    const mg_supervisor_config_t config = default_supervisor_config();
    mg_supervisor_input_t input = {
        .sensor_invalid = true, .dc_bus_voltage_v = 48.0f,
        .maximum_temperature_c = 25.0f
    };
    mg_supervisor_step(&supervisor, &config, &input);
    assert(supervisor.state == MG_STATE_FAULT);
    assert((supervisor.latched_faults & MG_FAULT_SENSOR_INVALID) != 0u);
}

static float wrap_angle(float angle)
{
    const float pi = 3.14159265358979323846f;
    while (angle > pi) angle -= 2.0f * pi;
    while (angle < -pi) angle += 2.0f * pi;
    return angle;
}

static void test_sogi_pll_frequency_step(void)
{
    const float pi = 3.14159265358979323846f;
    const float ts = 50.0e-6f;
    mg_sogi_pll_t pll;
    mg_sogi_pll_init(&pll, ts, 50.0f, 40.8f);
    float actual_theta = 0.0f;
    mg_pll_output_t output = {0};
    for (int k = 0; k < 10000; ++k) {
        const float frequency_hz = k < 4000 ? 50.0f : 52.0f;
        actual_theta += ts * 2.0f * pi * frequency_hz;
        output = mg_sogi_pll_step(&pll, 40.8f * sinf(actual_theta));
    }
    const float phase_error_deg = fabsf(wrap_angle(output.theta_rad
                                      - actual_theta)) * 180.0f / pi;
    printf("PLL final: %.4f Hz, %.3f deg phase error\n",
           output.frequency_hz, phase_error_deg);
    assert(output.locked);
    assert(fabsf(output.frequency_hz - 52.0f) < 0.05f);
    assert(phase_error_deg < 2.0f);
}

static void test_pr_tracks_rl_current(void)
{
    const float pi = 3.14159265358979323846f;
    const float ts = 50.0e-6f;
    const float omega = 2.0f * pi * 50.0f;
    const float inductance_h = 245.0e-6f;
    const float resistance_ohm = 0.08f;
    mg_pr_t controller;
    mg_pr_init(&controller, ts, 50.0f, -45.6f, 45.6f);
    float current_a = 0.0f;
    float squared_error_sum = 0.0f;
    int samples = 0;
    for (int k = 0; k < 4000; ++k) {
        const float time_s = k * ts;
        const float grid_v = 40.8f * sinf(omega * time_s);
        const float reference_a = 10.0f * sinf(omega * time_s);
        const float derivative_reference = 10.0f * omega * cosf(omega * time_s);
        const float feedforward_v = grid_v + resistance_ohm * reference_a
                                  + inductance_h * derivative_reference;
        const float command_v = mg_pr_step(&controller,
                                            reference_a - current_a,
                                            feedforward_v);
        current_a += ts * (command_v - grid_v - resistance_ohm * current_a)
                   / inductance_h;
        assert(isfinite(current_a));
        assert(command_v >= -45.6f && command_v <= 45.6f);
        if (k >= 2000) {
            const float error_a = reference_a - current_a;
            squared_error_sum += error_a * error_a;
            samples++;
        }
    }
    const float rms_error_a = sqrtf(squared_error_sum / samples);
    printf("PR/RL current tracking RMS error: %.4f A\n", rms_error_a);
    assert(rms_error_a < 0.20f);
}

static void test_scaled_droop_sharing_commands(void)
{
    mg_droop_t first,second;
    mg_droop_init(&first,50.0e-6f,50.0f,28.85f,300.0f,180.0f);
    mg_droop_init(&second,50.0e-6f,50.0f,28.85f,200.0f,120.0f);
    mg_droop_output_t a={0},b={0};
    for(int k=0;k<4000;++k){
        a=mg_droop_step(&first,300.0f,90.0f);
        b=mg_droop_step(&second,200.0f,60.0f);
    }
    assert(fabsf(a.frequency_reference_hz-b.frequency_reference_hz)<0.001f);
    assert(fabsf(a.voltage_reference_rms_v-b.voltage_reference_rms_v)<0.001f);
    assert(fabsf(a.frequency_reference_hz-49.4f)<0.01f);
    assert(fabsf(a.voltage_reference_rms_v-28.10f)<0.01f);
}

static void test_grid_loss_and_qualified_reconnection(void)
{
    const float pi=3.14159265358979323846f;
    const mg_grid_relay_config_t config={
        .sample_time_s=50.0e-6f,.nominal_frequency_hz=50.0f,.nominal_voltage_rms_v=28.85f,
        .utility_present_fraction=0.8f,.phase_limit_rad=2.0f*pi/180.0f,
        .frequency_limit_hz=0.1f,.voltage_limit_fraction=0.02f,
        .loss_hold_samples=400u,.reconnect_hold_samples=1000u,
        .sync_kp_hz_per_rad=3.0f,.sync_ki_hz_per_rad_s=8.0f,
        .sync_frequency_limit_hz=2.0f,.sync_voltage_gain=2.0f};
    mg_grid_relay_t relay;mg_grid_relay_init(&relay);
    mg_grid_relay_output_t output={0};
    for(int k=0;k<400;++k)
        output=mg_grid_relay_step(&relay,&config,0.0f,28.0f,49.5f,1.0f);
    assert(output.mode==MG_GRID_ISLANDED&&output.island_detected);
    output=mg_grid_relay_step(&relay,&config,28.85f,28.0f,49.5f,1.0f);
    assert(output.mode==MG_GRID_SYNCHRONIZING&&!output.breaker_close_command);
    output=mg_grid_relay_step(&relay,&config,28.85f,28.0f,49.5f,1.0f);
    assert(output.synchronization_frequency_bias_hz>0.0f);
    for(int k=0;k<1000;++k)
        output=mg_grid_relay_step(&relay,&config,28.85f,28.85f,50.0f,0.0f);
    assert(output.mode==MG_GRID_CONNECTED&&output.breaker_close_command);
}

int main(void)
{
    test_pi_anti_windup();
    test_po_mppt_tracks_peak();
    test_buck_boost_modes_and_bounds();
    test_supervisor_sequence_and_latched_trip();
    test_precharge_timeout();
    test_sensor_and_deadline_faults();
    test_sogi_pll_frequency_step();
    test_pr_tracks_rl_current();
    test_scaled_droop_sharing_commands();
    test_grid_loss_and_qualified_reconnection();
    puts("PASS: control core and protection tests");
    return 0;
}
