cmake_minimum_required(VERSION 3.24)
set(CMAKE_OSX_DEPLOYMENT_TARGET "14.2" CACHE STRING "Minimum macOS version")
project(MilkDropMac VERSION 0.1.0 LANGUAGES C CXX OBJCXX)
if(NOT APPLE)
  message(FATAL_ERROR "This frontend requires macOS")
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(ENABLE_PLAYLIST OFF CACHE BOOL "" FORCE)
set(ENABLE_SYSTEM_PROJECTM_EVAL OFF CACHE BOOL "" FORCE)
set(ENABLE_SDL_UI OFF CACHE BOOL "" FORCE)
set(ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(ENABLE_DEBUG_POSTFIX OFF CACHE BOOL "" FORCE)
set(CMAKE_DISABLE_FIND_PACKAGE_FLEX TRUE)
set(CMAKE_DISABLE_FIND_PACKAGE_BISON TRUE)

add_subdirectory(vendor/projectm)

add_executable(MilkDropMac MACOSX_BUNDLE src/main.mm)
target_compile_options(MilkDropMac PRIVATE -fobjc-arc -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations)
target_compile_definitions(MilkDropMac PRIVATE GL_SILENCE_DEPRECATION)
target_link_libraries(MilkDropMac PRIVATE projectM "-framework AppKit" "-framework OpenGL" "-framework UniformTypeIdentifiers")
set_target_properties(MilkDropMac PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/resources/Info.plist.in"
  MACOSX_BUNDLE_BUNDLE_NAME "MilkDrop macOS"
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "@executable_path/../Frameworks")
set_target_properties(projectM PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "")
# Refresh resources even when only a preset changed. Link projectM dynamically
# and put it inside the bundle so moving the app does not break the renderer.
add_custom_target(bundle_resources ALL
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Frameworks"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "$<TARGET_FILE:projectM>" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Frameworks/$<TARGET_SONAME_FILE_NAME:projectM>"
  COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/resources/presets" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/presets"
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses/Frontend.txt"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/vendor/projectm/LICENSE.txt" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses/projectM.txt"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/vendor/projectm/vendor/projectm-eval/LICENSE.md" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses/projectM-eval.txt"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/vendor/projectm/vendor/hlslparser/LICENSE" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses/hlslparser.txt"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/THIRD_PARTY.md" "$<TARGET_BUNDLE_DIR:MilkDropMac>/Contents/Resources/Licenses/THIRD_PARTY.md"
  DEPENDS MilkDropMac)

target_sources(MilkDropMac PRIVATE src/AudioCapture.mm)
target_link_libraries(MilkDropMac PRIVATE "-framework CoreAudio")
enable_testing()
add_executable(audio_pipeline_test tests/audio_pipeline.cpp)
target_include_directories(audio_pipeline_test PRIVATE src)
add_test(NAME audio_pipeline COMMAND audio_pipeline_test)

target_sources(MilkDropMac PRIVATE src/VisualizerView.mm src/PresetLibrary.mm src/PresetBrowser.mm)
add_executable(preset_library_test tests/preset_library.mm src/PresetLibrary.mm)
target_compile_options(preset_library_test PRIVATE -fobjc-arc)
target_include_directories(preset_library_test PRIVATE src)
target_link_libraries(preset_library_test PRIVATE "-framework Foundation")
add_test(NAME preset_library COMMAND preset_library_test)
