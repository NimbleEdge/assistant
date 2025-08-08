cmake_minimum_required(VERSION 3.22.1)

project("espeak_jni")

# Find required packages
find_library(log-lib log)
find_library(android-lib android)

# Import the pre-built eSpeak library
add_library(ttsespeak_imported SHARED IMPORTED)
set_target_properties(ttsespeak_imported PROPERTIES
    IMPORTED_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libttsespeak.so
)

# Add the JNI bridge library
add_library(
    espeak_jni
    SHARED
    espeak_jni.c
)

# Set include directories (headers should be placed in cpp/include)
target_include_directories(espeak_jni PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Link the imported eSpeak library and system libraries
target_link_libraries(espeak_jni
    # Pre-built eSpeak library
    ttsespeak_imported
    
    # System libraries
    ${log-lib}
    ${android-lib}
)

# Set C standard
set_property(TARGET espeak_jni PROPERTY C_STANDARD 99) 
