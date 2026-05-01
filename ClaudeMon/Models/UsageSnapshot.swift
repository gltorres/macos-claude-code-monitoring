import Foundation

// Schema captured live from claude.ai/api/organizations/{uuid}/usage on 2026-04-30.
// All fields optional so unknown / per-account-missing fields degrade gracefully.
struct UsageSnapshot: Decodable, Equatable {
    let fiveHour: Bucket?
    let sevenDay: Bucket?
    let sevenDaySonnet: Bucket?
    let sevenDayOpus: Bucket?
    let sevenDayOmelette: Bucket?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour          = "five_hour"
        case sevenDay          = "seven_day"
        case sevenDaySonnet    = "seven_day_sonnet"
        case sevenDayOpus      = "seven_day_opus"
        case sevenDayOmelette  = "seven_day_omelette"
        case extraUsage        = "extra_usage"
    }

    // Lossy decode: a malformed or schema-drifted nested field produces nil
    // rather than aborting the whole snapshot, so one bad bucket can't freeze
    // the polling loop. See: docs/manual-smoke-test.md "schema drift" step.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour         = try? c.decodeIfPresent(Bucket.self,     forKey: .fiveHour)
        sevenDay         = try? c.decodeIfPresent(Bucket.self,     forKey: .sevenDay)
        sevenDaySonnet   = try? c.decodeIfPresent(Bucket.self,     forKey: .sevenDaySonnet)
        sevenDayOpus     = try? c.decodeIfPresent(Bucket.self,     forKey: .sevenDayOpus)
        sevenDayOmelette = try? c.decodeIfPresent(Bucket.self,     forKey: .sevenDayOmelette)
        extraUsage       = try? c.decodeIfPresent(ExtraUsage.self, forKey: .extraUsage)
    }
}

struct Bucket: Decodable, Equatable {
    let utilization: Double
    let resetsAt: Date?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var utilizationInt: Int { Int(utilization.rounded()) }
}

struct ExtraUsage: Decodable, Equatable {
    let isEnabled: Bool
    let monthlyLimit: Double
    let usedCredits: Double
    let utilization: Double
    let currency: String

    enum CodingKeys: String, CodingKey {
        case isEnabled    = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits  = "used_credits"
        case utilization
        case currency
    }

    var utilizationInt: Int { Int(utilization.rounded()) }
}
