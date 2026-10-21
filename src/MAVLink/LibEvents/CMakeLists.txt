# ============================================================================
# LibEvents - MAVLink Event Handling
# Event logging, health reporting, and arming checks
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        EventHandler.cc
        EventHandler.h
        HealthAndArmingCheckReport.cc
        HealthAndArmingCheckReport.h
        logging.cpp
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# ============================================================================
# LibEvents Library Integration
# ============================================================================

CPMAddPackage(
    NAME libevents
    GITHUB_REPOSITORY mavlink/libevents
    # main since 0ef305f (2026-09-28, 32-bit system ids) needs MAVLink helpers
    # newer than QGC_MAVLINK_GIT_TAG; pinned to its parent
    GIT_TAG 077677a7d2f48f0af0eb8a4e4a7b6310956728bc
    SOURCE_SUBDIR libs/cpp
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE libevents)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${libevents_SOURCE_DIR}/libs/cpp)
