# Gate 2 Open Design Issues

The following issues were identified during the Gate 0 / 1A pre-hardware audit. They require physical verification, recalculation against the final BOM, or explicit design policy decisions before being blindly implemented. They are currently OPEN blockers for Gate 2.

## 1. Anti-alias Filter Cutoff (PROVISIONAL)
- **Finding:** The current 1 kΩ + 4.7 nF filter provides a cutoff of ~33.9 kHz, which offers minimal attenuation (approx 1.3 dB) against 20 kHz switching aliases.
- **Proposed Fix:** 47 nF (~3.39 kHz cutoff).
- **Status: PROVISIONAL (Not Approved)**
- **Next Action:** Do not arbitrarily change to 47 nF. Must formally recalculate based on:
  - Desired current-loop crossover frequency
  - Maximum tolerable sensor phase lag
  - PWM sampling strategy
  - Switching-ripple magnitude
  - ADC acquisition/settling constraints (per TI's input model)
  - Acceptable aliasing limits

## 2. Bootstrap Capacitor Margin (PROVISIONAL)
- **Finding:** The selected 100 nF bootstrap capacitor (with 118 nC MOSFET gate charge) predicts ~1.18 V ideal droop, leaving minimal margin for DC-bias capacitance derating, aging, or temperature effects.
- **Proposed Fix:** 1 µF minimum (10× Qg rule of thumb).
- **Status: PROVISIONAL (Not Approved)**
- **Next Action:** Do not automatically increase to 1 µF. TI's typical range for the UCC27211A is 0.022–0.1 µF. Formally recalculate based on:
  - High-side gate charge
  - Bootstrap leakage and driver quiescent current
  - Switching frequency and maximum high-side on-time
  - Permitted HB–HS droop and UVLO margin
  - Exact capacitor DC-bias derating curves from the manufacturer

## 3. LCL Return Path Filtering (UNVERIFIED)
- **Finding:** The schematic specification lists L2 on the `AC_INV` to `AC_PCC` path, but `AC_RETURN` connects directly to the switch node, exposing the grid emulator to unfiltered common-mode switching noise.
- **Proposed Fix:** Symmetric LCL filter design (split L1 and L2).
- **Status: UNVERIFIED**
- **Next Action:** Verify actual topology against the generated KiCad schematic and TI's single-phase grid-connected reference designs (e.g., TIDM-HV-1PH-DCAC). Redesign for symmetric filtering if the unbalanced layout is confirmed to violate emulator limits.

## 4. Grid Contactor Economizer (OPEN)
- **Finding:** The G9KA-1A1B grid contactor is driven by GPIO67 (no ePWM support). The Omron coil requires a reduced holding voltage (45–60%) after initial pull-in to prevent overheating.
- **Proposed Fix:** Software PWM or hardware RC step-down.
- **Status: OPEN**
- **Next Action:** Design an economizer strategy for Gate 2. Prefer a dedicated hardware coil-driver/economizer circuit (e.g., peak-and-hold relay driver IC or RC step-down) over consuming another real-time MCU PWM channel.

## 5. Switching-Loss Equations (OPEN)
- **Finding:** Python calculation `calculate_power_stage.py` multiplies switching loss by 2.0 (converter) and 4.0 (inverter), which may double-count if `mosfet_total_rise_fall_s` already represents the sum of both transitions.
- **Proposed Fix:** Remove multipliers if double-counting.
- **Status: OPEN**
- **Next Action:** Audit the exact definition of `mosfet_total_rise_fall_s` and the switching loss equation. Define whether the calculation is per-device, per-transition, or per-leg. Do not modify until the loss convention is verified against the reference MOSFET datasheet.

## 6. Watchdog in FAULT State (DESIGN POLICY)
- **Finding:** Watchdog is not serviced in `MG_STATE_FAULT`, causing an uncontrolled MCU reset ~160 ms after a trip and erasing post-fault telemetry.
- **Status: DESIGN POLICY DECISION**
- **Next Action:** Decide on the fundamental post-fault recovery strategy. For a research platform with telemetry, it is generally preferable to keep the watchdog alive in FAULT to transmit diagnostics, provided the hardware Trip Zone (OST) independently latches the power stage safe. Document this policy explicitly before changing the watchdog servicing logic.
