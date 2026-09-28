import Testing
@testable import MyFridge

struct WeightUnitTests {
    @Test func convertsOuncesToPoundsAndBack() {
        #expect(WeightUnit.ounces.toPounds(24) == 1.5)
        #expect(WeightUnit.ounces.value(fromPounds: 1.5) == 24)
        #expect(WeightUnit.pounds.toPounds(1.52) == 1.52)
    }

    @Test func formatsInItsOwnUnit() {
        #expect(WeightUnit.pounds.formatted(pounds: 1.52) == "1.52 lb")
        #expect(WeightUnit.pounds.formatted(pounds: 2) == "2 lb")
        #expect(WeightUnit.ounces.formatted(pounds: 1.5) == "24 oz")
        #expect(WeightUnit.ounces.formatted(pounds: 0.25) == "4 oz")
        #expect(WeightUnit.ounces.formatted(pounds: 1.0 / 3) == "5.33 oz")
    }
}
