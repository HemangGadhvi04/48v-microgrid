CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror -pedantic
CPPFLAGS += -Iinclude -I../application/include -I../control_core/include -I../modbus_sunspec/include -Igenerated
BUILD_DIR := build
TARGET := $(BUILD_DIR)/test_c2000_port
SOURCES := src/microgrid_c2000_port.c src/microgrid_rtu_transport.c tests/test_c2000_port.c ../application/src/microgrid_app.c ../control_core/src/microgrid_control.c ../modbus_sunspec/src/microgrid_sunspec.c
.PHONY: all test clean validate-pins validate-config validate-driverlib validate-driverlib-upstream
all: $(TARGET)
$(TARGET): $(SOURCES) include/microgrid_c2000_port.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SOURCES) -lm -o $(TARGET)
test: validate-config validate-pins validate-driverlib $(TARGET)
	./$(TARGET)
validate-config:
	python3 calculate_peripheral_timing.py
validate-driverlib:
	python3 verify_driverlib_manifest.py
validate-driverlib-upstream:
	test -n "$(C2000WARE_SDK)"
	python3 verify_against_c2000ware.py "$(C2000WARE_SDK)"
validate-pins:
	python3 validate_pin_allocation.py
clean:
	rm -rf $(BUILD_DIR)
