CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror -pedantic
CPPFLAGS += -Iinclude -I../control_core/include -I../modbus_sunspec/include -I../c2000_port/generated
BUILD_DIR := build
TARGET := $(BUILD_DIR)/test_application
SOURCES := src/microgrid_app.c tests/test_application.c ../control_core/src/microgrid_control.c ../modbus_sunspec/src/microgrid_sunspec.c
.PHONY: all test clean
all: $(TARGET)
$(TARGET): $(SOURCES) include/microgrid_app.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SOURCES) -lm -o $(TARGET)
test: $(TARGET)
	./$(TARGET)
clean:
	rm -rf $(BUILD_DIR)
