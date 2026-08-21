// DeepLinkHandler.swift
// Pure parsing of the app's custom-scheme deep links. No side effects, no I/O —
// so it's fully unit-testable. The only link we handle today is an invite.

import Foundation

/// A recognized deep link into the app.
enum DeepLink: Equatable {
    case invite(token: String)
}

enum DeepLinkHandler {
    /// Parses a `banyan://invite?token=<token>` URL. Returns nil for anything
    /// that isn't a well-formed invite link (wrong scheme/host, missing or empty
    /// token).
    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == "banyan",
              url.host == "invite",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty
        else { return nil }
        return .invite(token: token)
    }
}
