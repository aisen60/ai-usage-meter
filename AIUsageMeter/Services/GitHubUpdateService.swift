import Foundation

protocol UpdateDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionUpdateDataLoader: UpdateDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

struct GitHubUpdateService {
    static let repository = "aisen60/ai-usage-meter"

    struct Release: Decodable, Equatable {
        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft, prerelease, assets
        }
    }

    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    struct Tag: Decodable, Equatable {
        let name: String
    }

    private let loader: UpdateDataLoading

    init(loader: UpdateDataLoading = URLSessionUpdateDataLoader()) {
        self.loader = loader
    }

    func check(currentVersion: AppVersion) async throws -> AppUpdateResult {
        async let releaseData = fetch(path: "/releases?per_page=30")
        async let tagData = fetch(path: "/tags?per_page=30")

        let releases = try await decode([Release].self, from: releaseData)
        let tags = (try? await decode([Tag].self, from: tagData)) ?? []
        return Self.selectResult(
            releases: releases,
            tags: tags,
            currentVersion: currentVersion
        )
    }

    static func selectResult(
        releases: [Release],
        tags: [Tag],
        currentVersion: AppVersion
    ) -> AppUpdateResult {
        let releaseVersions = releases.compactMap { release -> (Release, AppVersion)? in
            guard !release.draft, !release.prerelease,
                  let version = AppVersion(release.tagName) else { return nil }
            return (release, version)
        }
        let sortedReleases = releaseVersions.sorted { $0.1 > $1.1 }
        let latestRelease = sortedReleases.first
        let latestTag = tags
            .compactMap { AppVersion($0.name) }
            .max()
        let latestVersion = [latestRelease?.1, latestTag]
            .compactMap { $0 }
            .max()

        let installableCandidate: AppUpdateCandidate? = sortedReleases.lazy
            .filter { $0.1 > currentVersion }
            .compactMap { releasePair -> AppUpdateCandidate? in
                Self.candidate(from: releasePair.0, version: releasePair.1)
            }
            .first
        return AppUpdateResult(latestVersion: latestVersion, candidate: installableCandidate)
    }

    private static func candidate(
        from release: Release,
        version: AppVersion
    ) -> AppUpdateCandidate? {
        let normalizedVersion = version.rawValue.lowercased()
        let archive = release.assets.first {
            let name = $0.name.lowercased()
            return name.hasSuffix(".zip") &&
                name.contains(normalizedVersion)
        }
        guard let archive else { return nil }

        let checksum = release.assets.first {
            let name = $0.name.lowercased()
            return name == "\(archive.name.lowercased()).sha256" ||
                (name.contains("sha256") && name.contains(normalizedVersion))
        }
        guard let checksum else { return nil }

        return AppUpdateCandidate(
            version: version,
            releaseURL: release.htmlURL,
            archiveURL: archive.browserDownloadURL,
            checksumURL: checksum.browserDownloadURL
        )
    }

    private func fetch(path: String) async throws -> Data {
        let url = URL(string: "https://api.github.com/repos/\(Self.repository)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AIUsageMeter/\(AppVersion.current.rawValue)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await loader.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw UpdateServiceError.httpFailure
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

enum UpdateServiceError: Error {
    case httpFailure
    case invalidResponse
}
