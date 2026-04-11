import SwiftUI

/// Computes the app version string shown in the About screen.
///
/// Extracted as a free function so the three branches can be tested
/// without touching `Bundle.main`.
///
/// - Parameters:
///   - shortVersion: `CFBundleShortVersionString` value, e.g. `"1.0.0"`.
///   - build: `CFBundleVersion` value, e.g. `"1"`.
/// - Returns: `"1.0.0 (1)"` when both are present, `"1.0.0"` when only
///   the short version is present, `"—"` when neither is available.
func aboutVersionString(shortVersion: String?, build: String?) -> String {
    switch (shortVersion, build) {
    case let (version?, build?):
        return "\(version) (\(build))"
    case let (version?, nil):
        return version
    default:
        return "—"
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    /// Verbatim public-domain license declaration from radio-browser.info's homepage.
    ///
    /// **Do not paraphrase or summarize.** Faithful reproduction of the license
    /// text is the whole point of this section; the upstream project publishes
    /// this exact wording as its data-license declaration.
    private let radioBrowserLicenseQuote: String = """
    This is a community driven effort (like wikipedia) with the aim of collecting as many internet radio and TV stations as possible. Any help is appreciated! Free for ALL! Data license: public domain, software license: GPL, server software: open source Open API for usage in own apps. Everyone is free to use the collected data (station names, tags, links to stream, links to homepages, language, country, state) in their works. I give all the rights I have at the accumulated data to the public domain.
    """

    private var appVersion: String {
        aboutVersionString(
            shortVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        )
    }

    var body: some View {
        NavigationStack {
            List {
                banner
                aboutSection
                dataSourceSection
                dataLicenseSection
                attributionSection
                libreRadioSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var banner: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                Text("LibreRadio")
                    .font(.title2.bold())
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Free and open-source internet radio")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var aboutSection: some View {
        Section("About LibreRadio") {
            Text("Internet radio player with zero ads, trackers, and telemetry. LibreRadio is free software (GPL-3.0) and the iOS counterpart to RadioDroid on Android.")
                .font(.body)
        }
    }

    private var dataSourceSection: some View {
        Section("Data Source") {
            Text("LibreRadio uses information provided by **radio-browser.info**, a community-driven database of more than 30,000 internet radio and TV stations.")
                .font(.body)

            Link(destination: URL(string: "https://www.radio-browser.info")!) {
                Label("Visit radio-browser.info", systemImage: "globe")
            }
        }
    }

    private var dataLicenseSection: some View {
        Section("Data License") {
            Text("All station data used by LibreRadio — including station names, tags, stream URLs, homepage URLs, language, country, and state — is released into the **public domain** by the radio-browser.info project. No account, API key, or individual permission is required to use this data. The declaration below is published on radio-browser.info's homepage:")
                .font(.body)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: 4)
                    Text(radioBrowserLicenseQuote)
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("— radio-browser.info")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.vertical, 4)

            Link(destination: URL(string: "https://www.radio-browser.info")!) {
                Label("View license on radio-browser.info", systemImage: "doc.text")
            }
        }
    }

    private var attributionSection: some View {
        Section("Attribution") {
            Text("Station data from [radio-browser.info](https://www.radio-browser.info). Consider [donating](https://ko-fi.com/segleralex) or [contributing](https://www.radio-browser.info/faq) to support the project.")
                .font(.body)

            Text("Inspired by [RadioDroid](https://github.com/segler-alex/RadioDroid) for Android.")
                .font(.body)

            Text("App icon based on the [Levitating, Meditating, Flute-playing Gnu](https://www.gnu.org/graphics/meditate.html) (GNU Project).")
                .font(.body)
        }
    }

    private var libreRadioSection: some View {
        Section("LibreRadio") {
            Text("LibreRadio is free and open-source software licensed under GPL-3.0.")
                .font(.body)

            Link(destination: URL(string: "https://github.com/sanbor/libreradio")!) {
                Label("View on GitHub", systemImage: "chevron.left.slash.chevron.right")
            }

            Link(destination: URL(string: "https://github.com/sanbor/libreradio/issues/new")!) {
                Label("Report an Issue", systemImage: "exclamationmark.bubble")
            }

            Link(destination: URL(string: "mailto:hello+libreradio@borrazas.org")!) {
                Label("Contact", systemImage: "envelope")
            }
        }
    }
}

#Preview {
    AboutView()
}
