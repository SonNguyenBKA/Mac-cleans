import Foundation

public struct DevJunkScanner: Sendable {
    /// Cache trong ~/Library/Caches do nhóm dev quản lý, nhóm hệ thống bỏ qua để không đếm trùng.
    public static let handledCacheNames: Set<String> = ["CocoaPods", "Yarn"]
    static let projectJunkPaths = ["node_modules", "android/app/build", "android/build", "android/.gradle", "ios/build", "ios/Pods"]
    static let skipWhenWalking: Set<String> = ["node_modules", "Pods", "build", "DerivedData"]

    let home: URL
    let tmpDir: URL
    let projectRoots: [URL]
    let now: Date
    let staleDays: Int
    let checkSimulators: Bool

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                tmpDir: URL = URL(fileURLWithPath: NSTemporaryDirectory()),
                projectRoots: [URL], now: Date = Date(), staleDays: Int = 30, checkSimulators: Bool = true) {
        self.home = home
        self.tmpDir = tmpDir
        self.projectRoots = projectRoots
        self.now = now
        self.staleDays = staleDays
        self.checkSimulators = checkSimulators
    }

    var cutoff: Date { now.addingTimeInterval(-Double(staleDays) * 86400) }

    public func scan() -> [JunkGroup] {
        let xcode = home.appendingPathComponent("Library/Developer/Xcode")
        let derived = xcode.appendingPathComponent("DerivedData")
        let archives = xcode.appendingPathComponent("Archives")
        let deviceSupport = xcode.appendingPathComponent("iOS DeviceSupport")

        let d = ScanSupport.items(in: derived)
        let ds = ScanSupport.items(in: deviceSupport)
        let m = ScanSupport.items(in: tmpDir) { url in
            SystemJunkScanner.metroPrefixes.contains(where: url.lastPathComponent.hasPrefix)
        }

        var groups = [
            JunkGroup(id: "derivedData", title: "Xcode DerivedData", icon: "hammer",
                      items: d.items.map(Self.derivedDataItem), allowedRoots: [derived], note: d.note),
            JunkGroup(id: "archives", title: "Xcode Archives (> \(staleDays) ngày)", icon: "archivebox",
                      items: archiveItems(archives), allowedRoots: [archives]),
            JunkGroup(id: "deviceSupport", title: "iOS DeviceSupport", icon: "iphone", items: ds.items,
                      allowedRoots: [deviceSupport], selectedByDefault: false, note: ds.note),
            JunkGroup(id: "packageCaches", title: "Cache Gradle / CocoaPods / npm / Yarn", icon: "shippingbox",
                      items: packageCacheItems(),
                      allowedRoots: [home.appendingPathComponent(".gradle"), home.appendingPathComponent("Library/Caches"),
                                     home.appendingPathComponent(".npm")]),
            JunkGroup(id: "metro", title: "Cache Metro", icon: "tram", items: m.items, allowedRoots: [tmpDir], note: m.note),
            JunkGroup(id: "projects", title: "Build của project không đụng > \(staleDays) ngày", icon: "folder",
                      items: projectItems(), allowedRoots: projectRoots),
        ]
        if checkSimulators {
            groups.insert(JunkGroup(id: "simulators", title: "Simulator không còn dùng", icon: "ipad.and.iphone",
                                    items: simulatorItems(), allowedRoots: []), at: 3)
        }
        return groups
    }

    static func derivedDataItem(_ item: CleanItem) -> CleanItem {
        let parts = item.url.lastPathComponent.split(separator: "-")
        let name = parts.count > 1 ? parts.dropLast().joined(separator: "-") : item.name
        return CleanItem(url: item.url, name: name, size: item.size)
    }

    func archiveItems(_ archives: URL) -> [CleanItem] {
        let dateDirs = (try? ScanSupport.children(of: archives)) ?? []
        return dateDirs.flatMap { (try? ScanSupport.children(of: $0)) ?? [] }
            .filter { $0.pathExtension == "xcarchive" && (ScanSupport.modificationDate($0) ?? now) < cutoff }
            .map { url in
                CleanItem(url: url, size: SizeCalculator.allocatedSize(of: url),
                          detail: ScanSupport.modificationDate(url).map { "\(ScanSupport.daysAgo($0, now: now)) ngày trước" })
            }
    }

    func packageCacheItems() -> [CleanItem] {
        [("Gradle", ".gradle/caches"), ("CocoaPods", "Library/Caches/CocoaPods"),
         ("Yarn", "Library/Caches/Yarn"), ("npm", ".npm/_cacache")]
            .compactMap { name, path in
                let url = home.appendingPathComponent(path)
                let size = SizeCalculator.allocatedSize(of: url)
                return size > 0 ? CleanItem(url: url, name: name, size: size, detail: "~/" + path) : nil
            }
    }

    // MARK: Project

    func projectItems() -> [CleanItem] {
        projectRoots.flatMap { findProjects(in: $0, name: "", depth: 4) }
            .flatMap { project, projectName -> [CleanItem] in
                guard let last = lastActivity(project), last < cutoff else { return [] }
                let days = "\(ScanSupport.daysAgo(last, now: now)) ngày không đụng"
                return Self.projectJunkPaths.compactMap { rel in
                    let url = project.appendingPathComponent(rel)
                    let size = SizeCalculator.allocatedSize(of: url)
                    return size > 0 ? CleanItem(url: url, name: "\(projectName)/\(rel)", size: size, detail: days) : nil
                }
            }
    }

    /// Trả về (thư mục project, đường dẫn tương đối so với project root).
    func findProjects(in dir: URL, name: String, depth: Int) -> [(URL, String)] {
        if FileManager.default.fileExists(atPath: dir.appendingPathComponent("package.json").path) {
            return [(dir, name.isEmpty ? dir.lastPathComponent : name)]
        }
        guard depth > 0, let children = try? ScanSupport.children(of: dir) else { return [] }
        return children
            .filter { !Self.skipWhenWalking.contains($0.lastPathComponent) && (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .flatMap { findProjects(in: $0, name: name.isEmpty ? $0.lastPathComponent : "\(name)/\($0.lastPathComponent)",
                                    depth: depth - 1) }
    }

    /// Lần sửa gần nhất của các mục con trực tiếp (kể cả .git), bỏ qua thư mục build.
    func lastActivity(_ project: URL) -> Date? {
        let ignored: Set<String> = ["node_modules", "build", ".DS_Store"]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: project, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return children.filter { !ignored.contains($0.lastPathComponent) }
            .compactMap(ScanSupport.modificationDate).max()
    }

    // MARK: Simulator

    func simulatorItems() -> [CleanItem] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "list", "devices", "unavailable", "-j"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        struct List: Decodable { let devices: [String: [Device]] }
        struct Device: Decodable { let udid: String }
        guard let list = try? JSONDecoder().decode(List.self, from: data) else { return [] }
        let udids = list.devices.values.flatMap { $0.map(\.udid) }
        guard !udids.isEmpty else { return [] }
        let devices = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        let size = udids.reduce(Int64(0)) { $0 + SizeCalculator.allocatedSize(of: devices.appendingPathComponent($1)) }
        return [CleanItem(url: devices, name: "\(udids.count) simulator unavailable", size: size,
                          detail: "xcrun simctl delete unavailable",
                          command: ["/usr/bin/xcrun", "simctl", "delete", "unavailable"])]
    }
}
