// GeneratedConfig.swift — values injected via LocalConfig.xcconfig locally (gitignored,
// included optionally by TestApp.xcconfig),
// or overwritten at build time by CI.
import Foundation

enum GeneratedConfig {
    static let tsBaseURL      = Bundle.main.object(forInfoDictionaryKey: "TSBaseURL")      as? String ?? ""
    static let tsAuthBaseURL  = Bundle.main.object(forInfoDictionaryKey: "TSAuthBaseURL")  as? String ?? ""
    static let tsServiceId    = Bundle.main.object(forInfoDictionaryKey: "TSServiceId")    as? String ?? ""
    static let tsUnitId       = Bundle.main.object(forInfoDictionaryKey: "TSUnitId")       as? String ?? ""
    static let tsClientId     = Bundle.main.object(forInfoDictionaryKey: "TSClientId")     as? String ?? ""
    static let tsClientSecret = Bundle.main.object(forInfoDictionaryKey: "TSClientSecret") as? String ?? ""
}
