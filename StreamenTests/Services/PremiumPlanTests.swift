//
//  PremiumPlanTests.swift
//  StreamenTests
//
//  Contract tests for the plan catalogue: they pin the product IDs and the
//  renewable/purchasable split, so a future edit can't quietly mistype an ID or
//  mark the one-time unlock as renewable. A plan advertised as renewing must be
//  a real auto-renewable subscription in App Store Connect, or buyers get renewal
//  copy for something they can never cancel under App Store ▸ Subscriptions.
//

@testable import Streamen
import Testing

@MainActor
struct PremiumPlanTests {
    /// The IDs must match App Store Connect exactly — a typo here means
    /// `Product.products(for:)` silently returns fewer products and the paywall
    /// renders a spinner forever.
    @Test func `product ids match app store connect`() {
        #expect(PremiumManager.Plan.monthly.rawValue == "com.hardheaded.streamen.pro.monthly")
        #expect(PremiumManager.Plan.lifetime.rawValue == "com.hardheaded.streamen.premium.lifetime")
    }

    /// The paywall offers every plan, the subscription before the lifetime unlock.
    @Test func `every plan is purchasable`() {
        #expect(PremiumManager.Plan.purchasable == [.monthly, .lifetime])
        #expect(Set(PremiumManager.Plan.purchasable) == Set(PremiumManager.Plan.allCases))
    }

    /// Exactly one plan is a real subscription; anything else claiming to renew
    /// would get renewal copy and a cancel button it can't honour.
    @Test func `only the subscription is renewable`() {
        let renewable = PremiumManager.Plan.allCases.filter(\.isRenewable)
        #expect(renewable == [.monthly])
        #expect(!PremiumManager.Plan.lifetime.isRenewable)
    }
}
