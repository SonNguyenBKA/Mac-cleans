import Foundation
import IOKit

// Dùng chung cho app (đọc) và helper root (ghi). Layout khớp struct SMCKeyData_t (80 byte) của AppleSMC.
struct SMCVersion { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0, release: UInt16 = 0 }
struct SMCPLimit { var version: UInt16 = 0, length: UInt16 = 0, cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
struct SMCKeyInfo {
    var dataSize: UInt32 = 0, dataType: UInt32 = 0, dataAttributes: UInt8 = 0
    var padding: (UInt8, UInt8, UInt8) = (0, 0, 0) // Swift không tự thêm tail padding như C
}
typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                      UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
struct SMCParam {
    var key: UInt32 = 0
    var version = SMCVersion()
    var pLimit = SMCPLimit()
    var keyInfo = SMCKeyInfo()
    var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

public enum SMCError: Error, LocalizedError {
    case openFailed(kern_return_t)
    case call(kern_return_t)
    case smc(UInt8)
    case unsupportedType(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let r): "Không mở được SMC (0x\(String(r, radix: 16)))"
        case .call(let r): r == kIOReturnNotPrivileged ? "Cần quyền root để ghi SMC" : "Lỗi gọi SMC (0x\(String(r, radix: 16)))"
        case .smc(let r): "SMC trả lỗi \(r)"
        case .unsupportedType(let t): "Kiểu dữ liệu SMC chưa hỗ trợ: \(t)"
        }
    }
}

public final class SMC: @unchecked Sendable {
    private enum Command: UInt8 { case read = 5, write = 6, keyAtIndex = 8, keyInfo = 9 }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: SMCKeyInfo] = [:]
    private let lock = NSLock()

    public init() throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        defer { IOObjectRelease(service) }
        let r = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard r == KERN_SUCCESS else { throw SMCError.openFailed(r) }
    }

    deinit { IOServiceClose(connection) }

    // MARK: Đọc / ghi

    public func read(_ key: String) throws -> (type: String, bytes: [UInt8]) {
        try lock.withLock {
            let info = try keyInfo(Self.fourCC(key))
            var p = SMCParam()
            p.key = Self.fourCC(key)
            p.keyInfo.dataSize = info.dataSize
            p.data8 = Command.read.rawValue
            try call(&p)
            let bytes = withUnsafeBytes(of: p.bytes) { Array($0.prefix(Int(info.dataSize))) }
            return (Self.string(info.dataType), bytes)
        }
    }

    public func value(_ key: String) -> Double? {
        guard let (type, bytes) = try? read(key) else { return nil }
        return Self.decode(type: type, bytes: bytes)
    }

    public func write(_ key: String, value: Double) throws {
        try lock.withLock {
            let info = try keyInfo(Self.fourCC(key))
            let type = Self.string(info.dataType)
            guard let bytes = Self.encode(type: type, value: value, size: Int(info.dataSize)) else {
                throw SMCError.unsupportedType(type)
            }
            var p = SMCParam()
            p.key = Self.fourCC(key)
            p.keyInfo.dataSize = info.dataSize
            p.data8 = Command.write.rawValue
            withUnsafeMutableBytes(of: &p.bytes) { buf in for (i, b) in bytes.enumerated() { buf[i] = b } }
            try call(&p)
        }
    }

    public func has(_ key: String) -> Bool {
        lock.withLock { (try? keyInfo(Self.fourCC(key))) != nil }
    }

    /// Toàn bộ tên key trong SMC (#KEY phần tử, vài nghìn key).
    public func allKeys() -> [String] {
        guard let count = value("#KEY") else { return [] }
        return lock.withLock {
            (0..<Int(count)).compactMap { i in
                var p = SMCParam()
                p.data8 = Command.keyAtIndex.rawValue
                p.data32 = UInt32(i)
                return (try? call(&p)) != nil ? Self.string(p.key) : nil
            }
        }
    }

    private func keyInfo(_ key: UInt32) throws -> SMCKeyInfo {
        if let cached = infoCache[key] { return cached }
        var p = SMCParam()
        p.key = key
        p.data8 = Command.keyInfo.rawValue
        try call(&p)
        infoCache[key] = p.keyInfo
        return p.keyInfo
    }

    private func call(_ p: inout SMCParam) throws {
        var output = SMCParam()
        var size = MemoryLayout<SMCParam>.size
        let r = IOConnectCallStructMethod(connection, 2, &p, MemoryLayout<SMCParam>.size, &output, &size)
        guard r == KERN_SUCCESS else { throw SMCError.call(r) }
        guard output.result == 0 else { throw SMCError.smc(output.result) }
        p = output
    }

    // MARK: Mã hoá

    public static func fourCC(_ s: String) -> UInt32 {
        s.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    public static func string(_ v: UInt32) -> String {
        String(bytes: [24, 16, 8, 0].map { UInt8((v >> $0) & 0xFF) }, encoding: .ascii) ?? "????"
    }

    public static func decode(type: String, bytes: [UInt8]) -> Double? {
        func be(_ n: Int) -> UInt64? { bytes.count >= n ? bytes.prefix(n).reduce(0) { $0 << 8 | UInt64($1) } : nil }
        switch type {
        case "flt ": return bytes.count >= 4 ? Double(bytes.withUnsafeBytes { $0.loadUnaligned(as: Float.self) }) : nil
        case "fpe2": return be(2).map { Double($0) / 4 }
        case "sp78": return be(2).map { Double(Int16(bitPattern: UInt16($0))) / 256 }
        case "ui8 ": return be(1).map { Double($0) }
        case "ui16": return be(2).map { Double($0) }
        case "ui32": return be(4).map { Double($0) }
        default: return nil
        }
    }

    public static func encode(type: String, value: Double, size: Int) -> [UInt8]? {
        switch type {
        case "flt " where size == 4: return withUnsafeBytes(of: Float(value)) { Array($0) }
        case "fpe2" where size == 2: let v = UInt16(max(0, value) * 4); return [UInt8(v >> 8), UInt8(v & 0xFF)]
        case "ui8 " where size == 1: return [UInt8(max(0, min(255, value)))]
        default: return nil
        }
    }
}
