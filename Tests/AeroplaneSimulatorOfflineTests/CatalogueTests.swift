import XCTest
@testable import AeroplaneSimulatorOffline

final class CatalogueTests: XCTestCase {
    func testSixUniquePlanes() {
        let ids = KidPlane.all.map(\.id)
        XCTAssertEqual(KidPlane.all.count, 6)
        XCTAssertEqual(Set(ids).count, 6)
    }

    func testSpeedsInKidSafeRange() {
        for p in KidPlane.all {
            XCTAssertTrue((20...46).contains(p.topSpeed), "\(p.id) speed out of range")
            XCTAssertTrue((1.0...1.6).contains(p.turnSpeed), "\(p.id) handling out of range")
        }
    }

    func testStarCollectionCelebratesAtTen() {
        let game = GameState()
        for _ in 1...9 { game.collectStar() }
        XCTAssertFalse(game.showCelebration)
        game.collectStar()
        XCTAssertEqual(game.stars, 10)
        XCTAssertTrue(game.showCelebration)
    }
}
