# Mem Reduct — Snapdragon 860 / Windows on ARM64

## Prepared portable build

This directory contains the native **Windows ARM64** executable from Mem Reduct v3.5.2. It is for a Snapdragon 860 device only when it is running **Windows 10/11 ARM64**. It is not an Android executable.

- Executable: `memreduct-3.5.2-arm64/memreduct.exe`
- PE machine: `0xAA64` (Windows ARM64)
- Verified SHA-256: `4c5cd83e0ff5c973278cef5ad107fad7080ba30c0b4008f6e7f0e88c209e6ea2`
- The adjacent `memreduct.exe.sig` is the upstream detached signature.

## Important architecture distinction

The upstream `32/memreduct.exe` is **x86 Win32**, not ARM32. It can run through x86 emulation in some Windows-on-ARM or Wine/Winlator environments.

Use the included ARM64 executable only on native Windows ARM64. If the Snapdragon 860 device is running Android plus Winlator/Wine, a Windows ARM64 executable cannot run directly; use the x86 build in that compatibility layer or use a native Android memory-management app.

## Extract/run checklist

1. Copy `memreduct-3.5.2-arm64-portable.7z` (or the uncompressed folder) to the Windows ARM64 device.
2. Extract it with current 7-Zip. The upstream archive uses BCJ2 compression, which some lightweight extractors cannot handle correctly.
3. Confirm `memreduct.exe` is exactly 389,120 bytes before starting it.
4. Run `memreduct.exe` as Administrator, because memory-cleaning operations require elevation.

The upstream source already includes a `Release|ARM64` Visual Studio configuration and an ARM64 build step; no PE architecture conversion is required or safe.
