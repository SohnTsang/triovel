import Foundation
import Supabase

/// Central Supabase client — single instance shared across the app.
/// Configure your project URL and anon key in environment or xcconfig.
enum SupabaseConfig {
    /// Replace with your Supabase project URL.
    /// In production, load from xcconfig / environment.
    static let projectURL = URL(string: "https://YOUR_PROJECT.supabase.co")!

    /// Replace with your Supabase anon (public) key.
    /// In production, load from xcconfig / environment.
    static let anonKey = "YOUR_ANON_KEY"

    /// The shared Supabase client.
    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )
}
