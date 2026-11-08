/// A network the game does not have yet, listed under "Coming next".
public enum UpcomingNetwork: String, Sendable, Hashable, CaseIterable, Identifiable {
    case be
    case de
    case ch
    case jp

    public var id: Self { self }
}
