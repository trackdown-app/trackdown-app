import Analytics
import Foundation
import TrackdownAPI

/// Build-time settings read from Info.plist, which gets them from the xcconfig files in `Config/`.
struct AppConfiguration: Equatable {
    var api: APIConfiguration
    var analytics: AnalyticsConfiguration

    static func fromMainBundle() -> AppConfiguration {
        fromInfoDictionary(Bundle.main.infoDictionary ?? [:])
    }

    static func fromInfoDictionary(_ info: [String: Any]) -> AppConfiguration {
        AppConfiguration(
            api: APIConfiguration(
                baseURL: url(for: "TrackdownAPIBaseURL", in: info),
                clientKey: info["TrackdownClientKey"] as? String ?? ""
            ),
            analytics: AnalyticsConfiguration(
                projectToken: info["PostHogProjectToken"] as? String ?? "",
                host: url(for: "PostHogHost", in: info)
            )
        )
    }

    private static func url(for key: String, in info: [String: Any]) -> URL {
        guard let value = info[key] as? String, let url = URL(string: value), url.scheme != nil else {
            preconditionFailure("Info.plist key \(key) must be an absolute URL. Check Config/*.xcconfig.")
        }
        return url
    }
}
