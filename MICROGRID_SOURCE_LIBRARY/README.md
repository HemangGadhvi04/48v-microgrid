# 48 V microgrid source library

Start with the [master research map](00_Master/research_map.md), then use the [annotated source index](00_Master/source_index.md) to obtain the original material.

This first pass maps all 27 project topics to 35 curated source records, with reading priorities, learning exercises, access notes and explicit research gaps. Some records are portals or companion documents rather than independent studies. Sources were discovered and checked at the level indicated on 6 September 2026; this is not a full-text review of all 35 entries.

## Suggested notebook organization

| Notebook | Sources to start with | Project material |
|---|---|---|
| Master architecture | S03, S21, S26 scope; add selected legally accessible textbook material | README, research map, roadmap |
| Inverter and islanded control | S04, S07, S02, S13 | Controller notes, parameters, model explanation and test results |
| Filters, PLL and grid following | S08, S09, S10, S12 | Separate subsystem derivations and tests as developed |
| PV, MPPT and battery | S15, S11, S16, S18 | PV implementation and future converter/energy-balance notes |
| C2000 and hardware | S17, S19, S20, S04; later S24/S25 | Exact schematics, firmware revision and device datasheets |
| Grid forming and transitions | S21, S22; S23 after full-text retrieval | Droop and supervisory-control design/test evidence |
| Standards | S26–S30 plus applicable state/DISCOM and adopted standards when identified | Applicability matrix; separate drafts from operative rules |
| Communications and monitoring | S31–S35 | Register map, units, API versions and logs |

These are suggested groupings; notebooks have not been created and PDFs have not been downloaded. Import the underlying source documents where accessible. Importing this index alone supplies a reading map, not the contents of the linked references. For code and models, supply an accompanying plain-text explanation with the exact revision and assumptions.

## Prompt to use with each source collection

> Help me understand this subsystem of a 48 V nominal, 500 W, single-phase 50 Hz research microgrid. The present inverter targets about 28.85 V RMS at 20 kHz switching. Cite the supplied sources for technical claims. Distinguish what the reference demonstrates from what our saved project implements. Identify differences in phase count, bus voltage, control architecture, sampling rate and operating mode. Label derivations and inferences. If a source or test result is missing, say so. Teach prerequisites first, then ask me to derive one result and propose a simulation that could disprove my understanding. Treat AI notes as commentary and source documents as evidence; do not infer compliance from simulation metrics.

## Acquisition record for future packs

For each document, record source ID, exact title/authors, revision/date, original URL, retrieval date, local filename, access rights, relevant sections, operating assumptions and review status. Keep one canonical copy and reference it across notebooks. Add page-specific notes only after reading the document. Prefer the original publisher, university, laboratory or standards body over reposts.
