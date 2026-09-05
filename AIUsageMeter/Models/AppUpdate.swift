import Foundation

struct AppVersion: Codable, Comparable, Equatable, Hashable {
    let rawValue: String
    private let components: [Int]

    init?(_ value: String) {
        var core = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if core.hasPrefix("v") || core.hasPrefix("V") {
            core.removeFirst()
        }
        guard !core.contains("-") else { return nil }
        core = core.split(separator: "+", maxSplits: 1).first.map(String.init) ?? core

        let parts = core.split(separator: ".")
        guard !parts.isEmpty,
              parts.allSatisfy({ Int($0) != nil }) else {
            return nil
        }

        rawValue = core
        components = parts.map { Int($0)! }
    }

    var displayName: String { "v\(rawValue)" }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        guard let version = AppVersion(value) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid app version"
            )
        }
        self = version
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension AppVersion {
    static var current: AppVersion {
        let rawValue = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.0.0"
        return AppVersion(rawValue) ?? AppVersion("0.0.0")!
    }
}

struct AppUpdateCandidate: Codable, Equatable {
    let version: AppVersion
    let releaseURL: URL
    let archiveURL: URL
    let checksumURL: URL
}

struct AppUpdateResult: Equatable {
    let latestVersion: AppVersion?
    let candidate: AppUpdateCandidate?
}

enum AppUpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(AppUpdateCandidate)
    case downloading
    case installing
    case failed

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            return true
        case .idle, .upToDate, .available, .failed:
            return false
        }
    }
}
