qml_module(caelestia-niri
    URI Caelestia.Niri
    INCLUDE_PREFIX niri
    SOURCES
        nirisocket.cpp
        niriipc.cpp
    LIBRARIES
        Qt::Network
)
