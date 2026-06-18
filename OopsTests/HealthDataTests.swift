import Foundation
import Testing
@testable import Oops

struct HealthDataTests {
    @Test func mockConformsToHealthDataProtocol() {
        let provider: any HealthData = MockHealthData()
        #expect(provider.dayMetrics(for: .now).steps >= 0)
        #expect(!provider.stepsSeries(days: 7).isEmpty)
    }
}
