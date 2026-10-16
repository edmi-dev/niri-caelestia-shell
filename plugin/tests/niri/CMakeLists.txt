find_package(Qt6 REQUIRED COMPONENTS Test)

set(CAELESTIA_NIRI_FIXTURES_DIR "${PROJECT_SOURCE_DIR}/tests/fixtures/niri"
    CACHE PATH "Recorded niri IPC fixtures for unit tests")

add_executable(tst_niriipc tst_niriipc.cpp)
target_link_libraries(tst_niriipc PRIVATE caelestia-niri Qt::Test Qt::Qml Qt::Network)
target_compile_definitions(tst_niriipc PRIVATE CAELESTIA_NIRI_FIXTURES_DIR="${CAELESTIA_NIRI_FIXTURES_DIR}")

add_test(NAME niriipc COMMAND tst_niriipc)
set_tests_properties(niriipc PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
