import Foundation

/// Which version of Passing is installed, from the project's MARKETING_VERSION (1.0.1, 1.0.2, …;
/// 1.1 for a bigger batch) and CURRENT_PROJECT_VERSION (the build, up by one every update).
/// Shown in Settings → About and stamped in the drive log.
enum AppVersion {
    static var current: String {
        text(
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    /// "1.0.1 (build 2)".
    static func text(version: String?, build: String?) -> String {
        "\(version ?? "?") (build \(build ?? "?"))"
    }
}
