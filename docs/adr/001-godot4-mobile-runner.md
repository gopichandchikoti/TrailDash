# ADR 001: Godot 4 mobile runner

Decision (2026-11-06): preserve Godot and typed GDScript; use installed Godot 4.7.2 and matching
templates. Use the Compatibility renderer (OpenGL ES 3) for inexpensive original low-poly art and
Android emulator compatibility. Vulkan Mobile is an alternative requiring separate hardware profiling.
Unity adds licensing and build complexity without a demonstrated need.

The player stays near the origin; a fixed pool of track pieces and obstacle rows scrolls past it.
Deterministic crossing tests avoid tunneling as speed rises. A seeded generator always leaves an
adjacent safe lane. Domain state, input, save data, visuals and UI have separate owners.

Target Android 7 / API 24 and newer, ARM64 phones plus x86_64 emulator. Prebuilt templates avoid
unnecessary Gradle dependencies. Target 60 FPS with optional 30 FPS battery mode; this is a budget,
not a measured physical-device claim. Local debug APKs are validation artifacts, not store releases.
