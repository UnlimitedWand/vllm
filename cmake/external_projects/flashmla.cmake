include(FetchContent)

# If FLASH_MLA_SRC_DIR is set, flash-mla is installed from that directory 
# instead of downloading.
# It can be set as an environment variable or passed as a cmake argument.
# The environment variable takes precedence.
if (DEFINED ENV{FLASH_MLA_SRC_DIR})
  set(FLASH_MLA_SRC_DIR $ENV{FLASH_MLA_SRC_DIR})
endif()

if(FLASH_MLA_SRC_DIR)
  FetchContent_Declare(
        flashmla 
        SOURCE_DIR ${FLASH_MLA_SRC_DIR}
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
  )
else()
  FetchContent_Declare(
        flashmla
        GIT_REPOSITORY https://github.com/LagPixelLOL/FlashMLA.git
        GIT_TAG 7defea0b1bad78f2ca3abaa43b59392594c42c5d
        GIT_PROGRESS TRUE
        CONFIGURE_COMMAND ""
        BUILD_COMMAND ""
  )
endif()


FetchContent_MakeAvailable(flashmla)
message(STATUS "FlashMLA is available at ${flashmla_SOURCE_DIR}")

# The FlashMLA kernels only work on hopper and require CUDA 12.3 or later.
# Only build FlashMLA kernels if we are building for something compatible with 
# sm90a
cuda_archs_loose_intersection(FLASH_MLA_ARCHS "8.0;9.0a" "${CUDA_ARCHS}")
if(${CMAKE_CUDA_COMPILER_VERSION} VERSION_GREATER 12.3 AND FLASH_MLA_ARCHS)
    set(FlashMLA_SOURCES
        ${flashmla_SOURCE_DIR}/csrc/flash_api.cpp
        ${flashmla_SOURCE_DIR}/csrc/flash_fwd_mla_metadata.cu)

    set(FlashMLA_SM80_SOURCES
        ${flashmla_SOURCE_DIR}/csrc/flash_fwd_mla_bf16_sm80.cu)

#    set(FlashMLA_SM90_SOURCES
#        ${flashmla_SOURCE_DIR}/csrc/flash_fwd_mla_bf16_sm90.cu
#        ${flashmla_SOURCE_DIR}/csrc/flash_fwd_mla_fp16_sm90.cu)

    set(FlashMLA_INCLUDES
        ${flashmla_SOURCE_DIR}/csrc/cutlass/include
        ${flashmla_SOURCE_DIR}/csrc/include)

    set_gencode_flags_for_srcs(
        SRCS "${FlashMLA_SOURCES}"
        CUDA_ARCHS "${FLASH_MLA_ARCHS}")

    cuda_archs_loose_intersection(FLASH_MLA_SM80 "8.0" "${CUDA_ARCHS}")
    if(FLASH_MLA_SM80)
        set_gencode_flags_for_srcs(
            SRCS "${FlashMLA_SM80_SOURCES}"
            CUDA_ARCHS "${FLASH_MLA_SM80}")
    endif()

#    cuda_archs_loose_intersection(FLASH_MLA_SM90 "9.0a" "${CUDA_ARCHS}")
#    if(FLASH_MLA_SM90)
#        set_gencode_flags_for_srcs(
#            SRCS "${FlashMLA_SM90_SOURCES}"
#            CUDA_ARCHS "${FLASH_MLA_SM90}")
#    endif()

    list(APPEND FlashMLA_SOURCES ${FlashMLA_SM80_SOURCES})
    list(APPEND FlashMLA_SOURCES ${FlashMLA_SM90_SOURCES})

    define_gpu_extension_target(
        _flashmla_C
        DESTINATION vllm
        LANGUAGE ${VLLM_GPU_LANG}
        SOURCES ${FlashMLA_SOURCES}
        COMPILE_FLAGS ${VLLM_GPU_FLAGS}
        ARCHITECTURES ${VLLM_GPU_ARCHES}
        INCLUDE_DIRECTORIES ${FlashMLA_INCLUDES}
        USE_SABI 3
        WITH_SOABI)
else()
    # Create an empty target for setup.py when not targeting sm90a systems
    add_custom_target(_flashmla_C)
endif()
