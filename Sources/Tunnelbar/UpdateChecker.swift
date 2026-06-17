import Foundation

/// Lightweight update check against the GitHub Releases API. No framework, no
/// signing keys — it compares the latest published release to the running
/// bundle version and reports whether a newer one exists.
enum UpdateChecker {
    static let repo = "ayush-sharaf/tunnelbar"

    struct Release {
        let version: String
        let url: URL
    }

    enum Outcome {
        case upToDate(current: String)
        case updateAvailable(Release)
        case failed(String)
    }

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// Query the latest release; the completion is always called on the main thread.
    static func check(completion: @escaping (Outcome) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            finish(completion, .failed("Invalid update URL."))
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Tunnelbar", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                finish(completion, .failed(error.localizedDescription))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                finish(completion, .failed("Couldn't read the latest release."))
                return
            }
            let latest = normalize(tag)
            let releaseURL = (json["html_url"] as? String).flatMap { URL(string: $0) }
                ?? URL(string: "https://github.com/\(repo)/releases/latest")!

            if compare(latest, currentVersion) == .orderedDescending {
                finish(completion, .updateAvailable(Release(version: latest, url: releaseURL)))
            } else {
                finish(completion, .upToDate(current: currentVersion))
            }
        }.resume()
    }

    /// Strip a leading "v" from a tag like "v1.3".
    static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Numeric, component-wise version comparison ("1.10" > "1.9").
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    private static func finish(_ completion: @escaping (Outcome) -> Void, _ outcome: Outcome) {
        DispatchQueue.main.async { completion(outcome) }
    }
}
