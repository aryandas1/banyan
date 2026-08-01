// SupabaseConfig.swift
// Loads the Supabase project URL and anon (public) key from Supabase.plist —
// a gitignored file bundled into the app.
//
// The anon key is safe to ship in the client: Row Level Security enforces
// access, so this key is public by design. It's kept out of git only for
// hygiene. NEVER place the service_role key here or anywhere in the app — it
// bypasses RLS and must stay server-side.
//
// Supabase.plist (not committed) must define:
//   SupabaseURL     — https://<project>.supabase.co
//   SupabaseAnonKey — the anon / public key from Project Settings → API

import Foundation

enum SupabaseConfig {
    /// The project's base URL. Traps at first use if the plist is absent or malformed.
    static let url: URL = {
        guard let value = string(for: "SupabaseURL"), let url = URL(string: value) else {
            fatalError("Supabase.plist is missing a valid SupabaseURL — see SupabaseConfig.swift.")
        }
        return url
    }()

    /// The anon / public key. Traps at first use if it hasn't been filled in.
    static let anonKey: String = {
        guard let key = string(for: "SupabaseAnonKey"),
              !key.isEmpty, key != "PASTE_YOUR_ANON_PUBLIC_KEY_HERE" else {
            fatalError("Supabase.plist is missing SupabaseAnonKey — paste your anon key from Project Settings → API.")
        }
        return key
    }()

    /// Reads a string value from the bundled Supabase.plist.
    private static func string(for key: String) -> String? {
        guard let fileURL = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: fileURL),
              let raw = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let plist = raw as? [String: Any] else {
            return nil
        }
        return plist[key] as? String
    }
}
