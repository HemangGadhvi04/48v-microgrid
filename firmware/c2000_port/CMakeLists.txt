cmake_minimum_required(VERSION 3.20)
project(microgrid_c2000 C ASM)

# Add directories

# Driverlib inclusion
# Expects C2000WARE_DIR to be set via environment or command line
if(NOT DEFINED ENV{C2000WARE_DIR})
    message(WARNING "C2000WARE_DIR environment variable not set. Using stub paths.")
    set(C2000WARE_DIR "C:/ti/c2000/C2000Ware_4_02_00_00")
else()
    set(C2000WARE_DIR $ENV{C2000WARE_DIR})
endif()

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/generated
    ${CMAKE_CURRENT_SOURCE_DIR}/../application/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../control_core/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../modbus_sunspec/include
    ${C2000WARE_DIR}/driverlib/f2837xd/driverlib
    ${C2000WARE_DIR}/device_support/f2837xd/common/include
    ${C2000WARE_DIR}/device_support/f2837xd/headers/include
)

set(CORE_SOURCES
    ../application/src/microgrid_app.c
    ../control_core/src/microgrid_control.c
    ../modbus_sunspec/src/microgrid_sunspec.c
    src/microgrid_c2000_port.c
    src/microgrid_rtu_transport.c
)

add_library(microgrid_core STATIC ${CORE_SOURCES})

# Hardware executable target
add_executable(microgrid_target_f28379d main_cpu1.c board.c adc.c pwm.c protection.c interrupts.c communications.c f28379d_driverlib_hal.c)
target_compile_definitions(microgrid_target_f28379d PRIVATE MG_C2000_TARGET)
target_link_libraries(microgrid_target_f28379d microgrid_core)

# C2000Ware pre-built driverlib
target_link_libraries(microgrid_target_f28379d ${C2000WARE_DIR}/driverlib/f2837xd/driverlib/ccs/Debug/driverlib.lib)

# Linker command file for F28379D CPU1
set(CMD_FILE "${C2000WARE_DIR}/device_support/f2837xd/common/cmd/2837xD_FLASH_lnk_cpu1.cmd")
target_link_options(microgrid_target_f28379d PRIVATE ${CMD_FILE})
