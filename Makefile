.PHONY: test test-python test-firmware test-matlab regenerate clean

test: regenerate test-python test-firmware

regenerate:
	python3 hardware/calculate_power_stage.py
	python3 hardware/calculate_sensing.py
	python3 hardware/calculate_magnetics.py
	python3 hardware/calculate_magnetics_thermal.py
	python3 hardware/calculate_passive_protection.py
	python3 hardware/calculate_gate_drive.py
	python3 hardware/calculate_pcb_constraints.py
	python3 hardware/validate_connectivity.py
	python3 hardware/kicad/verify_schematic.py

test-python:
	python3 -m unittest discover -s hardware/tests -v
	python3 -m unittest discover -s comms/tests -v
	python3 -m py_compile hardware/*.py hardware/tests/*.py comms/*.py comms/tests/*.py
	python3 -m json.tool comms/sunspec_map.json >/dev/null
	python3 -m json.tool comms/grafana_dashboard.json >/dev/null

test-firmware:
	$(MAKE) -C firmware/control_core test
	$(MAKE) -C firmware/modbus_sunspec test
	$(MAKE) -C firmware/application test
	$(MAKE) -C firmware/c2000_port test

test-matlab:
	/Applications/MATLAB_R2025b.app/bin/matlab -batch "addpath(fullfile(pwd,'simulations')); run_phase1_validation(); run_phase3_validation();"

clean:
	$(MAKE) -C firmware/control_core clean
	$(MAKE) -C firmware/modbus_sunspec clean
	$(MAKE) -C firmware/application clean
