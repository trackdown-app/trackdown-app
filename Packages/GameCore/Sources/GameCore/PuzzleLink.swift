import Foundation

/// A website link's destination. Unknown website paths return to today's current network.
public enum PuzzleLink: Sendable, Equatable {
    case today(Network?)
    case archive(Network, number: Int)

    /// Ignores URLs outside the associated website. Query strings and fragments do not affect routing.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == "https", url.host()?.lowercased() == "trackdown.nl",
            url.port == nil || url.port == 443
        else { return nil }

        var parts = url.path().split(separator: "/", omittingEmptySubsequences: false)
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        // Dutch has no prefix; the website's other languages each have one. No network's id is one of them.
        if let first = parts.first, Self.languagePrefixes.contains(first) { parts.removeFirst() }
        guard let first = parts.first, let network = Network(rawValue: String(first)) else {
            self = .today(nil)
            return
        }
        if parts.count == 1 {
            self = .today(network)
        } else if parts.count == 3, parts[1] == "archief",
            !parts[2].isEmpty, parts[2].allSatisfy({ $0 >= "0" && $0 <= "9" }),
            let number = Int(parts[2]), number > 0
        {
            self = .archive(network, number: number)
        } else {
            self = .today(nil)
        }
    }

    /// The website's language prefixes: `/en`, `/de` and `/fr`.
    static let languagePrefixes: Set<Substring> = ["en", "de", "fr"]
}
