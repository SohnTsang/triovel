import Foundation
import Supabase

/// Central Supabase client — single instance shared across the app.
/// Configure your project URL and anon key in environment or xcconfig.
enum SupabaseConfig {
    /// Replace with your Supabase project URL.
    /// In production, load from xcconfig / environment.
    static let projectURL = URL(string: "https://yvlahvxytlvdqmicojcm.supabase.co")!

    /// Replace with your Supabase anon (public) key.
    /// In production, load from xcconfig / environment.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2bGFodnh5dGx2ZHFtaWNvamNtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzNjM5NDEsImV4cCI6MjA4OTkzOTk0MX0.A1augm441HcAVrbuLYhV2_wUMIyCWmNPlUqqzr2EYtI"

    /// The shared Supabase client.
    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )
}
