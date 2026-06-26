import Foundation

class SensitiveDataFilter {
    static let shared = SensitiveDataFilter()

    // Password-manager bundle IDs — clipboard events from these apps are always skipped
    private let passwordManagerBundles: Set<String> = [
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal",
        "net.macflux.NordPass",
        "com.keepassxc.keepassxc",
    ]

    private let patterns: [NSRegularExpression] = {
        let raw = [
            // Credit card (Visa/MC/Amex/Discover bare numbers)
            #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#,
            // AWS access key ID
            #"(?:A3T[A-Z0-9]|AKIA|AGPA|AROA|ASCA|ASIA)[A-Z0-9]{16}"#,
            // GitHub personal access token
            #"gh[pousr]_[A-Za-z0-9]{36,}"#,
            // Stripe secret/publishable key
            #"(?:sk|pk)_(?:test|live)_[A-Za-z0-9]{24,}"#,
            // Generic secret/api-key assignment
            #"(?i)(?:api[_-]?key|secret[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key)\s*[=:]\s*['\"]?[A-Za-z0-9\-_\.]{20,}"#,
            // PEM private key block
            #"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private init() {}

    func shouldSkip(_ clip: ClipItem) -> Bool {
        if let bundle = clip.sourceAppBundle,
           passwordManagerBundles.contains(bundle) { return true }

        guard let text = clip.textContent, !text.isEmpty else { return false }
        let r = NSRange(text.startIndex..., in: text)
        return patterns.contains { $0.firstMatch(in: text, range: r) != nil }
    }
}
