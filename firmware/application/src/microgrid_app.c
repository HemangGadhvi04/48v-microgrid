#include "microgrid_app.h"
#include "adc_scaling.h"

#include <math.h>

#define MG_CONTROL_TS_S (50.0e-6f)
#define MG_PI_F (3.14159265358979323846f)

static float decode(uint16_t count, float zero, float units_per_count)
{
    return ((float)count-zero)*units_per_count;
}

static float clampf(float value, float minimum, float maximum)
{
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

static float wrap_pi(float angle)
{
    while (angle > MG_PI_F) angle -= 2.0f*MG_PI_F;
    while (angle < -MG_PI_F) angle += 2.0f*MG_PI_F;
    return angle;
}

static bool measurements_invalid(const mg_app_measurement_t *m)
{
    return !isfinite(m->pv_voltage_v) || m->pv_voltage_v < -2.0f || m->pv_voltage_v > 68.0f
        || !isfinite(m->dc_bus_voltage_v) || m->dc_bus_voltage_v < -2.0f || m->dc_bus_voltage_v > 62.0f
        || !isfinite(m->pv_current_a) || m->pv_current_a < -3.0f || m->pv_current_a > 27.0f
        || !isfinite(m->dc_inductor_current_a) || fabsf(m->dc_inductor_current_a) > 27.0f
        || !isfinite(m->grid_voltage_v) || fabsf(m->grid_voltage_v) > 50.0f
        || !isfinite(m->utility_voltage_v) || fabsf(m->utility_voltage_v) > 50.0f
        || !isfinite(m->grid_current_a) || fabsf(m->grid_current_a) > 32.0f
        || !isfinite(m->heatsink_temperature_c)
        || m->heatsink_temperature_c < -30.0f || m->heatsink_temperature_c > 130.0f;
}

static uint16_t sunspec_state(mg_operating_state_t state)
{
    if (state == MG_STATE_RUN) return 4u;
    if (state == MG_STATE_FAULT) return 7u;
    if (state == MG_STATE_PRECHARGE || state == MG_STATE_READY) return 3u;
    return 1u;
}

static uint32_t sunspec_events(uint32_t faults)
{
    uint32_t events = 0u;
    if ((faults & MG_FAULT_DC_OVERVOLTAGE) != 0u) events |= 1u << 1;
    if ((faults & MG_FAULT_GRID_OVERCURRENT) != 0u) events |= 1u << 2;
    if ((faults & MG_FAULT_DC_UNDERVOLTAGE) != 0u) events |= 1u << 3;
    if ((faults & MG_FAULT_ESTOP) != 0u) events |= 1u << 6;
    if ((faults & MG_FAULT_OVERTEMPERATURE) != 0u) events |= 1u << 7;
    if ((faults & (MG_FAULT_HARDWARE_TRIP | MG_FAULT_SENSOR_INVALID
                  | MG_FAULT_DEADLINE_MISSED)) != 0u) events |= 1u << 15;
    return events;
}

void mg_app_init(mg_app_t *app)
{
    mg_buck_boost_init(&app->dc_dc, MG_CONTROL_TS_S);
    mg_sogi_pll_init(&app->bus_pll, MG_CONTROL_TS_S, 50.0f, 40.8f);
    mg_sogi_pll_init(&app->utility_pll, MG_CONTROL_TS_S, 50.0f, 40.8f);
    mg_pr_init(&app->grid_current, MG_CONTROL_TS_S, 50.0f, -45.6f, 45.6f);
    mg_pi_init(&app->dc_bus_power, 40.0f, 400.0f, MG_CONTROL_TS_S, 0.0f, 500.0f);
    mg_po_mppt_init(&app->mppt, 0.2f, 20.0f, 57.0f);
    mg_supervisor_init(&app->supervisor);
    mg_droop_init(&app->droop,MG_CONTROL_TS_S,50.0f,28.85f,500.0f,300.0f);
    mg_grid_relay_init(&app->grid_relay);
    app->grid_relay_config=(mg_grid_relay_config_t){
        .sample_time_s=MG_CONTROL_TS_S,.nominal_frequency_hz=50.0f,
        .nominal_voltage_rms_v=28.85f,.utility_present_fraction=0.80f,
        .phase_limit_rad=2.0f*MG_PI_F/180.0f,.frequency_limit_hz=0.10f,
        .voltage_limit_fraction=0.02f,.loss_hold_samples=400u,
        .reconnect_hold_samples=1000u,.sync_kp_hz_per_rad=3.0f,
        .sync_ki_hz_per_rad_s=8.0f,.sync_frequency_limit_hz=2.0f,
        .sync_voltage_gain=2.0f};
    app->supervisor_config = (mg_supervisor_config_t){
        .dc_bus_undervoltage_v=38.0f,.dc_bus_overvoltage_v=56.0f,
        .dc_current_trip_a=22.0f,.grid_current_trip_a=28.0f,
        .temperature_trip_c=90.0f,.precharge_complete_v=43.0f,
        .precharge_timeout_ticks=40000u};
    mg_sunspec_init(&app->sunspec);
    app->measurement=(mg_app_measurement_t){0};
    app->output=(mg_app_output_t){0};
    app->telemetry_generation=0u;
    app->tick=0u; app->previous_adc_sequence=UINT32_MAX;
    app->stale_sample_count=0u; app->pv_voltage_reference_v=46.0f;
    app->active_power_command_w=0.0f; app->active_power_filtered_w=0.0f;
    app->reactive_power_filtered_var=0.0f; app->lifetime_energy_wh=0.0f;
    app->grid_voltage_squared_filtered_v2=0.0f;
    app->grid_current_squared_filtered_a2=0.0f;
    app->grid_forming_theta_rad=0.0f;
}

mg_app_output_t mg_app_step(mg_app_t *app, const mg_app_raw_input_t *raw)
{
    mg_app_measurement_t *m=&app->measurement;
    m->pv_voltage_v=decode(raw->pv_voltage,MG_ADC_PV_VOLTAGE_ZERO_COUNT,MG_ADC_PV_VOLTAGE_UNITS_PER_COUNT);
    m->dc_bus_voltage_v=decode(raw->dc_bus_voltage,MG_ADC_DC_BUS_VOLTAGE_ZERO_COUNT,MG_ADC_DC_BUS_VOLTAGE_UNITS_PER_COUNT);
    m->pv_current_a=decode(raw->pv_current,MG_ADC_PV_CURRENT_ZERO_COUNT,MG_ADC_PV_CURRENT_UNITS_PER_COUNT);
    m->dc_inductor_current_a=decode(raw->dc_inductor_current,MG_ADC_DC_INDUCTOR_CURRENT_ZERO_COUNT,MG_ADC_DC_INDUCTOR_CURRENT_UNITS_PER_COUNT);
    m->grid_voltage_v=decode(raw->grid_voltage,MG_ADC_GRID_VOLTAGE_ZERO_COUNT,MG_ADC_GRID_VOLTAGE_UNITS_PER_COUNT);
    m->utility_voltage_v=decode(raw->utility_voltage,MG_ADC_UTILITY_VOLTAGE_ZERO_COUNT,MG_ADC_UTILITY_VOLTAGE_UNITS_PER_COUNT);
    m->grid_current_a=decode(raw->grid_current,MG_ADC_GRID_CURRENT_ZERO_COUNT,MG_ADC_GRID_CURRENT_UNITS_PER_COUNT);
    m->heatsink_temperature_c=decode(raw->heatsink_temperature,MG_ADC_HEATSINK_TEMPERATURE_ZERO_COUNT,MG_ADC_HEATSINK_TEMPERATURE_UNITS_PER_COUNT);

    if (raw->sequence == app->previous_adc_sequence) {
        if (app->stale_sample_count < UINT16_MAX) app->stale_sample_count++;
    } else {
        app->stale_sample_count=0u;
        app->previous_adc_sequence=raw->sequence;
    }
    const bool sensor_invalid=raw->adc_invalid || measurements_invalid(m)
        || app->stale_sample_count>=3u;
    const mg_pll_output_t bus_pll=mg_sogi_pll_step(&app->bus_pll,m->grid_voltage_v);
    const mg_pll_output_t utility_pll=mg_sogi_pll_step(&app->utility_pll,m->utility_voltage_v);
    const mg_supervisor_input_t supervisor_input={
        .start_request=raw->start_request,.reset_request=raw->reset_request,
        .grid_locked=utility_pll.locked || app->supervisor.state==MG_STATE_RUN
            || app->grid_relay.mode!=MG_GRID_CONNECTED,
        .emergency_stop=raw->emergency_stop,
        .hardware_trip=raw->hardware_trip,.sensor_invalid=sensor_invalid,
        .deadline_missed=raw->deadline_missed,.dc_bus_voltage_v=m->dc_bus_voltage_v,
        .dc_current_a=m->dc_inductor_current_a,.grid_current_a=m->grid_current_a,
        .maximum_temperature_c=m->heatsink_temperature_c};
    mg_supervisor_step(&app->supervisor,&app->supervisor_config,&supervisor_input);

    if (app->tick%200u==0u && app->supervisor.pwm_enable)
        app->pv_voltage_reference_v=mg_po_mppt_step(&app->mppt,m->pv_voltage_v,m->pv_current_a);
    const mg_buck_boost_output_t dc=mg_buck_boost_step(&app->dc_dc,
        app->supervisor.pwm_enable,m->pv_voltage_v,m->pv_current_a,
        m->dc_bus_voltage_v,m->dc_inductor_current_a,app->pv_voltage_reference_v);

    const float utility_voltage_rms=utility_pll.amplitude_v/sqrtf(2.0f);
    const float bus_voltage_rms=bus_pll.amplitude_v/sqrtf(2.0f);
    mg_grid_relay_output_t relay={MG_GRID_CONNECTED,false,false,0.0f,0.0f};
    if (app->supervisor.pwm_enable) {
        relay=mg_grid_relay_step(&app->grid_relay,&app->grid_relay_config,
            utility_voltage_rms,bus_voltage_rms,bus_pll.frequency_hz,
            wrap_pi(utility_pll.theta_rad-bus_pll.theta_rad));
    } else {
        mg_grid_relay_init(&app->grid_relay);
    }

    float current_reference=0.0f; float modulation=0.0f;
    float voltage_reference_rms=28.85f;
    float frequency_reference_hz=50.0f;
    if (app->supervisor.pwm_enable) {
        if (relay.mode==MG_GRID_CONNECTED) {
            const float pv_power=m->pv_voltage_v*m->pv_current_a;
            app->active_power_command_w=mg_pi_step(&app->dc_bus_power,
                m->dc_bus_voltage_v-48.0f,pv_power);
            const float current_peak=sqrtf(2.0f)*app->active_power_command_w/28.85f;
            current_reference=clampf(current_peak,-27.0f,27.0f)*sinf(bus_pll.theta_rad);
            const float voltage_command=mg_pr_step(&app->grid_current,
                current_reference-m->grid_current_a,m->grid_voltage_v);
            modulation=clampf(voltage_command/fmaxf(m->dc_bus_voltage_v,1.0f),-0.95f,0.95f);
            app->grid_forming_theta_rad=bus_pll.theta_rad;
        } else {
            const mg_droop_output_t droop=mg_droop_step(&app->droop,
                app->active_power_filtered_w,app->reactive_power_filtered_var);
            frequency_reference_hz=clampf(droop.frequency_reference_hz
                +relay.synchronization_frequency_bias_hz,48.0f,52.0f);
            voltage_reference_rms=clampf(droop.voltage_reference_rms_v
                +relay.synchronization_voltage_bias_v,24.5f,31.7f);
            app->grid_forming_theta_rad=wrap_pi(app->grid_forming_theta_rad
                +2.0f*MG_PI_F*frequency_reference_hz*MG_CONTROL_TS_S);
            modulation=clampf(sqrtf(2.0f)*voltage_reference_rms
                *sinf(app->grid_forming_theta_rad)/fmaxf(m->dc_bus_voltage_v,1.0f),
                -0.95f,0.95f);
            mg_pr_reset(&app->grid_current);
            mg_pi_reset(&app->dc_bus_power,0.0f);
            app->active_power_command_w=0.0f;
        }
    } else {
        mg_pr_reset(&app->grid_current); mg_pi_reset(&app->dc_bus_power,0.0f);
        app->active_power_command_w=0.0f;
    }

    const float alpha=1.0f-expf(-2.0f*MG_PI_F*5.0f*MG_CONTROL_TS_S);
    const float instantaneous_power=m->grid_voltage_v*m->grid_current_a;
    app->active_power_filtered_w+=alpha*(instantaneous_power-app->active_power_filtered_w);
    const float quadrature_voltage=40.8f*cosf(bus_pll.theta_rad);
    const float instantaneous_q=quadrature_voltage*m->grid_current_a;
    app->reactive_power_filtered_var+=alpha*(instantaneous_q-app->reactive_power_filtered_var);
    app->grid_voltage_squared_filtered_v2+=alpha*(m->grid_voltage_v*m->grid_voltage_v
        -app->grid_voltage_squared_filtered_v2);
    app->grid_current_squared_filtered_a2+=alpha*(m->grid_current_a*m->grid_current_a
        -app->grid_current_squared_filtered_a2);
    if (app->active_power_filtered_w>0.0f)
        app->lifetime_energy_wh+=app->active_power_filtered_w*MG_CONTROL_TS_S/3600.0f;

    app->output=(mg_app_output_t){
        .dc_duty_input_leg=app->supervisor.pwm_enable?dc.duty_input_leg:0.0f,
        .dc_duty_output_leg=app->supervisor.pwm_enable?dc.duty_output_leg:0.0f,
        .inverter_duty_leg_a=app->supervisor.pwm_enable?0.5f*(1.0f+modulation):0.0f,
        .inverter_duty_leg_b=app->supervisor.pwm_enable?0.5f*(1.0f-modulation):0.0f,
        .pv_voltage_reference_v=app->pv_voltage_reference_v,
        .grid_current_reference_a=current_reference,
        .pwm_enable=app->supervisor.pwm_enable,
        .precharge_relay=app->supervisor.precharge_relay,
        .main_contactor=app->supervisor.main_contactor,
        .grid_breaker_close=app->supervisor.pwm_enable&&relay.breaker_close_command,
        .grid_mode=relay.mode,.ac_voltage_reference_rms_v=voltage_reference_rms,
        .ac_frequency_reference_hz=frequency_reference_hz,
        .state=app->supervisor.state,.faults=app->supervisor.latched_faults};

    if (app->tick%200u==0u) {
        const float apparent=hypotf(app->active_power_filtered_w,app->reactive_power_filtered_var);
        const float ac_voltage_rms=sqrtf(fmaxf(app->grid_voltage_squared_filtered_v2,0.0f));
        const float ac_current_rms=sqrtf(fmaxf(app->grid_current_squared_filtered_a2,0.0f));
        const float pf_percent=apparent>1.0f?clampf(100.0f*app->active_power_filtered_w/apparent,-100.0f,100.0f):0.0f;
        const mg_sunspec_telemetry_t telemetry={
            .ac_current_a=ac_current_rms,.ac_voltage_v=ac_voltage_rms,
            .active_power_w=(int16_t)lroundf(app->active_power_filtered_w),
            .frequency_hz=relay.mode==MG_GRID_CONNECTED?bus_pll.frequency_hz:frequency_reference_hz,
            .reactive_power_var=(int16_t)lroundf(app->reactive_power_filtered_var),
            .power_factor_percent=pf_percent,
            .lifetime_energy_wh=(uint32_t)app->lifetime_energy_wh,
            .dc_current_a=fabsf(m->dc_inductor_current_a),.dc_voltage_v=m->dc_bus_voltage_v,
            .dc_power_w=(int16_t)lroundf(m->dc_bus_voltage_v*m->dc_inductor_current_a),
            .cabinet_temperature_c=m->heatsink_temperature_c,
            .heatsink_temperature_c=m->heatsink_temperature_c,
            .operating_state=sunspec_state(app->supervisor.state),
            .event_bits=sunspec_events(app->supervisor.latched_faults)};
        app->telemetry_generation++;
        mg_sunspec_update(&app->sunspec,&telemetry);
        app->telemetry_generation++;
    }
    app->tick++;
    return app->output;
}
