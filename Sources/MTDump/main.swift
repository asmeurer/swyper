// Standalone multitouch record dumper.
//
// Prints the raw fields of every contact the trackpad reports so we can figure
// out how to distinguish a resting palm from a swiping finger (palms have a
// much larger contact area). Run with:
//
//     swift run MTDump
//
// Then rest your palm on the trackpad and do a three-finger swipe. Copy the
// output. Ctrl-C to stop.

import Foundation

private typealias MTDeviceRef = UnsafeMutableRawPointer

private typealias MTContactFrameCallback = @convention(c) (
    MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32, UnsafeMutableRawPointer?
) -> Int32

private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>
private typealias MTRegisterCallbackFn = @convention(c) (
    MTDeviceRef, MTContactFrameCallback, UnsafeMutableRawPointer?
) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Int32

#if arch(arm64)
private let kStride = 96
#else
private let kStride = 0
#endif

// Known fields (arm64, macOS 26 layout used by the main app).
private let kOffPathIndex = 16   // Int32 — finger identifier
private let kOffState = 20       // Int32 — touch phase

// Throttle so we don't flood the terminal.
private var lastPrint = Date.distantPast

private let callback: MTContactFrameCallback = { _, data, nFingers, timestamp, _, _ in
    let count = Int(nFingers)
    guard count > 0 else { return 0 }

    let now = Date()
    guard now.timeIntervalSince(lastPrint) > 0.1 else { return 0 }
    lastPrint = now

    let raw = UnsafeRawPointer(data)
    print(String(format: "── frame  t=%.3f  contacts=%d", timestamp, count))
    for i in 0..<count {
        let base = raw + i * kStride
        let path = base.load(fromByteOffset: kOffPathIndex, as: Int32.self)
        let state = base.load(fromByteOffset: kOffState, as: Int32.self)

        // Dump every Float32 from offset 24 through the end of the record so we
        // can spot the size/area/major-axis fields by eye.
        var floats: [String] = []
        var off = 24
        while off + 4 <= kStride {
            let v = base.load(fromByteOffset: off, as: Float.self)
            floats.append(String(format: "@%02d=%+.4f", off, v))
            off += 4
        }
        print("  id=\(path) state=\(state)  " + floats.joined(separator: " "))
    }
    return 0
}

// Disable stdout buffering so output appears immediately even when redirected.
setvbuf(stdout, nil, _IONBF, 0)

guard kStride > 0 else {
    FileHandle.standardError.write(Data("Only arm64 is supported.\n".utf8))
    exit(1)
}

guard let handle = dlopen(
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
    RTLD_LAZY
) else {
    FileHandle.standardError.write(Data("Failed to load MultitouchSupport.\n".utf8))
    exit(1)
}

guard let pCreate = dlsym(handle, "MTDeviceCreateList"),
      let pRegister = dlsym(handle, "MTRegisterContactFrameCallbackWithRefcon"),
      let pStart = dlsym(handle, "MTDeviceStart") else {
    FileHandle.standardError.write(Data("Failed to resolve MultitouchSupport symbols.\n".utf8))
    exit(1)
}

private let createList = unsafeBitCast(pCreate, to: MTDeviceCreateListFn.self)
private let register = unsafeBitCast(pRegister, to: MTRegisterCallbackFn.self)
private let start = unsafeBitCast(pStart, to: MTDeviceStartFn.self)

let devices = createList().takeUnretainedValue() as [AnyObject]
guard !devices.isEmpty else {
    FileHandle.standardError.write(Data("No multitouch devices found.\n".utf8))
    exit(1)
}

for device in devices {
    let ref = Unmanaged.passUnretained(device).toOpaque()
    register(ref, callback, nil)
    _ = start(ref, 0)
}

print("Monitoring \(devices.count) device(s). Rest your palm and do a 3-finger swipe. Ctrl-C to stop.\n")
RunLoop.current.run()
