CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror -pedantic
CPPFLAGS += -Iinclude
BUILD_DIR := build
TARGET := $(BUILD_DIR)/test_sunspec
SOURCES := src/microgrid_sunspec.c tests/test_sunspec.c

.PHONY: all test clean
all: $(TARGET)
$(TARGET): $(SOURCES) include/microgrid_sunspec.h
	mkdir -p $(BUILD_DIR)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SOURCES) -lm -o $(TARGET)
test: $(TARGET)
	./$(TARGET)
clean:
	rm -rf $(BUILD_DIR)
