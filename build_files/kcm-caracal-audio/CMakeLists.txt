cmake_minimum_required(VERSION 3.20)

project(kcm_caracal_audio VERSION 1.0 LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${CMAKE_MODULE_PATH})

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

if(NOT CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
endif()
if(NOT CMAKE_RUNTIME_OUTPUT_DIRECTORY)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
endif()
if(NOT CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
endif()

find_package(KF6 REQUIRED COMPONENTS CoreAddons I18n KCMUtils)

kcmutils_add_qml_kcm(kcm_caracal_audio SOURCES kcm_caracal_audio.cpp)

target_link_libraries(kcm_caracal_audio
    PRIVATE
        KF6::CoreAddons
        KF6::KCMUtilsQuick
        KF6::I18n
)
