# 48 V microgrid — master source index

Research date: 6 September 2026. Scope: a curated discovery map across the project, not a completed literature review or compliance assessment. Source descriptions below are reading recommendations; they do not imply that every linked document has been read in full. No paywalled texts have been acquired.

## How to use this index

Use the source IDs in the companion research map. **A** means primary technical material, publisher-hosted textbook, official documentation, or specification. **B** means university teaching material. Authority is contextual: a manufacturer is authoritative about its device, but its reference design is not a universal design rule. Application notes with derivations and measured results can be core sources.

Verification labels: **document** = document text retrieved; **page** = official page or bibliographic record retrieved; **discovery** = official search result inspected, full document still to review. All entries were located during this research pass. Public landing pages do not guarantee unrestricted downloads or NotebookLM importability. Software and standards should have their exact revision recorded when acquired.

## Foundations and controls

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S01 | [Erickson & Maksimović, Fundamentals of Power Electronics, 3rd ed., 2020](https://link.springer.com/book/10.1007/978-3-030-43881-4). Publisher page; book may require purchase/library access. | A; intermediate; page | Converter averaging, small-signal models, feedback and digital control. Use selected chapters rather than reading cover to cover. |
| S02 | [Åström & Murray, Feedback Systems, second-edition author resource](https://www.cds.caltech.edu/~murray/FBS/Second_Edition.html). Author's university page. | A/B; foundational; discovery | Transfer functions, stability and control architecture. Page points to a newer book site; that destination could not be retrieved in this pass. |
| S03 | [NPTEL: Power Electronics, IIT Delhi](https://www.nptel.ac.in/courses/108102145), G. Bhuvaneshwari. Public course page. | B; foundational; page | DC/DC fundamentals and voltage-source inverter/PWM modules. Select relevant lectures. |
| S04 | [NPTEL: Design of Power Electronic Converters, IIT Guwahati](https://www.nptel.ac.in/courses/117103148), Shabari Nath. Public course page. | B; foundational–intermediate; page | Lectures 5–8: H-bridge and bipolar/unipolar PWM; later modules: drivers, EMI, magnetics and PCB layout. Best practical teaching spine. |
| S05 | [NPTEL: Pulse Width Modulation for Power Electronic Converters — syllabus](https://archive.nptel.ac.in/content/syllabus_pdf/108108035.pdf). Public PDF. | B; intermediate; discovery | PWM, dead time, ripple and switching losses. This is a syllabus, not the lecture content; acquire corresponding lectures when studying PWM. |

## Inverter, filters, PLL and measurement

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S06 | [TI TIDM-HV-1PH-DCAC](https://www.ti.com/tool/TIDM-HV-1PH-DCAC). Public reference-design page. | A; intermediate; page | Navigation hub for S07/S08, firmware and hardware files. Its 380 V input hardware is not a component-level template for this 48 V build. |
| S07 | [TI Voltage Source Inverter Reference Design, TIDUAY6E](https://www.ti.com/lit/pdf/tiduay6), revised March 2020. Public PDF. | A; intermediate; document | LC-filtered inverter, voltage regulation and validation. Compare its resonant-control approach with the project's fundamental-amplitude PI loop; do not equate them. |
| S08 | [TI Grid Connected Inverter Reference Design, TIDUB21D](https://www.ti.com/lit/pdf/tidub21), revised March 2020. Public PDF. | A; advanced; document | LCL filter, grid current control, synchronization and damping. Re-derive gains for project scaling and sample rate. |
| S09 | [TI Software PLL Design Using C2000 MCUs for Single Phase Grid Connected Inverter, SPRABT3A](https://www.ti.com/lit/pdf/sprabt3), revised July 2017. Public PDF. | A; intermediate; discovery | Single-phase phase detection, orthogonal signal generation and SOGI. Historical code must be reconciled with the chosen SDK. |
| S10 | [MathWorks Single-Phase Inverter Current Control](https://www.mathworks.com/help/sps/ug/single-phase-inverter-control.html). Public documentation; model requires software. | A; intermediate; page | Averaged-switch current-control example. It is not evidence of switching-harmonic performance or a complete grid-interconnection design. |
| S11 | [MathWorks Single-Phase Grid-Connected Solar Photovoltaic System](https://www.mathworks.com/help/sps/ug/single-phase-grid-connected-in-pv-system.html). Public documentation. | A; intermediate; document | Integrated single-phase PV/grid system and MPPT. Check release and toolbox requirements before adapting model blocks. |
| S12 | [Liserre, Blaabjerg & Hansen, Design and control of an LCL-filter-based three-phase active rectifier, 2005](https://vbn.aau.dk/en/publications/design-and-control-of-an-lcl-filter-based-three-phase-active-rect-2/). University publication record. | A; advanced; page/abstract only | Foundational LCL design paper, IEEE TIA 41(5), 1281–1291. Three-phase scaling and controller assumptions require adaptation; full paper still to acquire. |
| S13 | [MathWorks Measure Total Harmonic Distortion](https://www.mathworks.com/help/signal/ug/measure-total-harmonic-distortion.html). Public documentation. | A; intermediate; discovery | Measurement method and signal-analysis workflow. Record harmonics, window, sample rate and units for every project result. |
| S14 | [MathWorks Choose Blocks to Model Power Electronic Converters](https://www.mathworks.com/help/sps/ug/choose-power-electronic-converter-block.htm). Public documentation. | A; intermediate; discovery | Choice of average, averaged-switching and switching models. Use model fidelity appropriate to the question being tested. |

## PV, DC/DC, battery and embedded control

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S15 | [Sandia PVPMC Single Diode Equivalent Circuit Models](https://pvpmc.sandia.gov/modeling-guide/2-dc-module-iv/single-diode-equivalent-circuit-models/), contributions from NIST and Sandia. Public article. | A; foundational–intermediate; page | Governing PV equation and cell/module parameter conventions. Compare directly with the project's PV function. |
| S16 | [TI TIDM-BUCKBOOST-BIDIR](https://www.ti.com/tool/TIDM-BUCKBOOST-BIDIR). Public design page. | A; intermediate; discovery | Bidirectional nonisolated DC/DC and battery energy flow. Legacy controlSUITE material; verify hardware limits and software portability. |
| S17 | [TI TIDM-DC-DC-BUCK](https://www.ti.com/tool/TIDM-DC-DC-BUCK). Public design page. | A; intermediate; document | Digital power-control learning platform, voltage/current control and transient experiments. A buck exercise does not resolve the final bidirectional topology. |
| S18 | [MathWorks Battery Equivalent Circuit](https://www.mathworks.com/help/simscape-battery/ref/batteryequivalentcircuit.html). Public documentation; Simscape Battery dependency. | A; intermediate; discovery | SOC-dependent electrical and thermal battery behavior. Requires cell-specific characterization; this is not a BMS design specification. |
| S19 | [TI C2000Ware DigitalPower SDK](https://www.ti.com/tool/C2000WARE-DIGITALPOWER-SDK). Public software portal. | A; intermediate; document | Reference firmware and digital-power libraries. Pin installed version, device support and example revision before implementation. |
| S20 | [TI TMS320F28379D documentation portal](https://www.ti.com/product/TMS320F28379D?qgpn=tms320f28379d). Datasheet and F2837xD TRM entry point. | A; advanced; discovery | ePWM, ADC triggering, interrupts and protection peripherals. Direct product-page fetch timed out; official search listing was available. Acquire TRM and device errata before coding hardware. |

## Grid forming and transitions

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S21 | [Research Roadmap on Grid-Forming Inverters, Lin et al., 2020](https://research-hub.nlr.gov/en/publications/research-roadmap-on-grid-forming-inverters/). Official record with public report links, NREL/TP-5D00-73476. | A; intermediate–advanced; page | System-level grid-forming research map. Read definitions and scope first; it is not a tuned single-phase controller recipe. |
| S22 | [Design Power Control Strategies of Grid-Forming Inverters for Microgrid Application, Wang, 2021](https://research-hub.nlr.gov/en/publications/design-power-control-strategies-of-grid-forming-inverters-for-mic-3/). Official presentation record, NREL/PR-5D00-80718. | A; advanced; page/abstract | Comparison of power tracking and droop across modes. This record is a presentation, not the conference paper. [Government archive](https://www.govinfo.gov/app/details/GOVPUB-E9-PURL-gpo187198) is an alternate access point. |
| S23 | [Design Power Control Strategies — conference-paper PDF, NREL/CP-5D00-78874](https://www.nrel.gov/docs/fy22osti/78874.pdf). | A; advanced; discovery, retrieval failed | Related paper linked in the original notes. Keep separate from S22; full-text review and bibliographic completion remain pending. |

## Hardware and device technology

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S24 | [EPC application-note library](https://epc-co.com/epc/design-support/application-notes). Manufacturer portal. | A within device scope; advanced; discovery | GaN layout, power-loop parasitics and converter examples. Use alongside S01/S04 and measured losses, not as a neutral device-selection verdict. |
| S25 | [EPC: How to Design a 1.5 kW 48 V/12 V Bidirectional Converter, 2021](https://epc-co.com/epc/Portals/0/epc/documents/application-notes/How2AppNote021%20How%20to%20Design%20a%201.5%20kW%2048%20V%2012%20V%20Bi-Directional.pdf). Public application note. | A; advanced; discovery | Concrete low-voltage GaN example. Different power rating and voltage ratio; it is not the project's inverter BOM. |

### Phase 2 candidate component records

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S36 | [TI CSD19536KCS product page and Rev. C datasheet](https://www.ti.com/product/CSD19536KCS). | A within device scope; datasheet checked | 100 V TO-220 MOSFET reference candidate. Thermal resistance, hot resistance, gate charge and measured switching stress still govern suitability. |
| S37 | [TI UCC27211A Rev. D datasheet](https://www.ti.com/lit/ds/symlink/ucc27211a.pdf). | A within device scope; datasheet checked | 120 V bootstrap half-bridge driver reference. Sustained high-side duty, negative switch-node excursions and layout require validation. |
| S38 | [TI TMCS1123 product page and Rev. D datasheet](https://www.ti.com/product/TMCS1123). | A within device scope; datasheet checked | 250 kHz isolated current-sensor family with fast alert. Exact sensitivity variant and ADC interface remain open. |
| S39 | [Magnetics 00F6527E060 product-finder record](https://www.mag-inc.com/advanced-part-number-finder?pn=00F6527) and [PFC boost design guide](https://www.mag-inc.com/design/design-guides/power-factor-correction/pfc-boost). | A within manufacturer scope; page checked | E65 Kool Mu HF geometry and LI-squared selection workflow for the feasibility calculation. DC-bias retention, core loss, winding fill and thermal performance remain release gates. |

## Standards and interoperability

These are source-discovery records, not an applicability determination. Indian installation requirements need the actual state, DISCOM, connection voltage, system configuration and relevant adopted standards.

| ID | Source and access | Level / evidence | Read for / limitation |
|---|---|---|---|
| S26 | [CEA distributed-generation connectivity regulations](https://cea.nic.in/regulations-category/connectivity-of-distributed-generation-resources/?lang=en). Official listing of 2013 regulations and 2019 amendment. | A; specialist; page | Starting point for Indian DG interconnection research. Download both texts and build a clause-by-clause applicability table later. |
| S27 | [CERC current regulations register](https://cercind.gov.in/current_reg.html). Official register. | A; specialist; discovery | Grid Code 2023 and amendments as wider grid context. Do not substitute a Statement of Reasons for the operative regulation; do not infer that every provision applies to a 500 W installation. |
| S28 | [CEA What's New — 2026 connectivity draft notice](https://cea.nic.in/whats-new/?lang=en). Notice dated 4 August 2026. | A; specialist; page | Draft tracking only. The listed proposal concerns connectivity to the grid; this index does not establish that it replaces DG-specific regulations. |
| S29 | [IEEE 1547-2018](https://standards.ieee.org/ieee/1547/5915/). Official scope/status page; full text paid/subscription. | A; specialist; page | International comparison for interconnection, interoperability and islanding. Page describes a 60 Hz source and lists 1547a-2020 amendment. No compliance claim follows from a THD result. |
| S30 | [IEC 62116:2014](https://webstore.iec.ch/en/publication/6479). Official catalogue; full text paid. | A; specialist; page | Islanding-prevention test procedure for utility-interconnected PV inverters. Catalogue verified; detailed test criteria have not been extracted. |
| S31 | [SunSpec Modbus resources](https://sunspec.org/modbus/). Official model/specification portal. | A; intermediate; page | Device and DER model definitions, storage models and conformance resources. Model selection and transport implementation are separate decisions. |
| S32 | [SunSpec specifications and status](https://sunspec.org/specifications/). Official specification portal. | A; intermediate; page | Distinguish approved material from TEST/review specifications; some downloads use forms. |
| S33 | [Modbus Organization specifications](https://www.modbus.org/modbus-specifications). Official protocol portal. | A; intermediate; discovery | Application protocol and Serial Line Protocol/Implementation Guide V1.02. Acquire applicable documents; do not assume all downloads are unrestricted. |
| S34 | [PyModbus stable documentation PDF](https://pymodbus.readthedocs.io/_/downloads/en/stable/pdf/). Maintainer documentation. | A for API; intermediate; discovery | Python gateway implementation. Stable is a moving target: pin the package and documentation version together. |
| S35 | [Grafana InfluxDB data-source documentation](https://grafana.com/docs/grafana/latest/datasources/influxdb/). Official documentation. | A for API; intermediate; discovery | Monitoring integration. Choose database version/query language before writing the gateway. |

## Curation gaps to resolve at the relevant stage

- LCL: add a full-text single-phase passive/active damping paper; S12 supplies foundational context but is three-phase and abstract-reviewed only.
- Grid forming: add full-text single-phase droop/current-limiting studies and measured reconnection experiments. S21–S23 do not establish compatibility with this plant.
- Hardware: acquire exact MOSFET/GaN/SiC, driver, sensor, magnetic-core and capacitor datasheets after ratings are selected. SiC is mapped through S01 for fundamentals; a specific SiC design source is not yet selected.
- Battery: select cell count, cell datasheet, BMS requirements, protection and battery-specific standards. The 42–54 V simulation range does not establish a particular pack's permissible range.
- Standards: resolve state/DISCOM rules, BIS-adopted editions and applicable IEC 61727, IEC 62109 and IEEE 1547.1 records. Those editions/applicability have not been verified in this pass. No numeric trip thresholds should be copied from this index.
- Monitoring: select InfluxDB deployment/version and add its matching official write-API documentation; define timestamp accuracy and data-loss behavior.
