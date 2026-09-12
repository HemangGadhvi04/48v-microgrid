set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR c2000)

# Ensure CMake doesn't try to test the compiler and run executables (since it's a cross-compiler)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Find TI CGT C2000 in standard paths or via environment variable CGT2000_INSTALL_DIR
if(DEFINED ENV{CGT2000_INSTALL_DIR})
    set(TI_CGT_PATH $ENV{CGT2000_INSTALL_DIR})
else()
    # Default common paths for CCS
    set(TI_CGT_PATH "C:/ti/ccs1200/ccs/tools/compiler/ti-cgt-c2000_22.6.0.LTS")
endif()

set(CMAKE_C_COMPILER "${TI_CGT_PATH}/bin/cl2000")
set(CMAKE_CXX_COMPILER "${TI_CGT_PATH}/bin/cl2000")
set(CMAKE_ASM_COMPILER "${TI_CGT_PATH}/bin/cl2000")
set(CMAKE_LINKER "${TI_CGT_PATH}/bin/cl2000")
set(CMAKE_AR "${TI_CGT_PATH}/bin/ar2000")

# F28379D specific flags
set(TI_MCU_FLAGS "-v28 -ml -mt --cla_support=cla1 --float_support=fpu32 --tmu_support=tmu0 --vcu_support=vcu2")

set(CMAKE_C_FLAGS "${TI_MCU_FLAGS} -O2 --opt_for_speed=2 --symdebug:dwarf --c11 --diag_warning=225 --diag_wrap=off --display_error_number --abi=eabi --define=uint8_t=uint16_t --include_path=\"${TI_CGT_PATH}/include\"")
set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS}")
set(CMAKE_ASM_FLAGS "${TI_MCU_FLAGS}")

# Linker flags (ROM model, map file generation, stack size)
set(CMAKE_EXE_LINKER_FLAGS "-z -m microgrid_f28379d.map --stack_size=0x300 --warn_sections -i ${TI_CGT_PATH}/lib -i ${TI_CGT_PATH}/include --reread_libs --rom_model")
