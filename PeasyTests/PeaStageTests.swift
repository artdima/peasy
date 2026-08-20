import Testing
@testable import Peasy

struct PeaStageTests {
    @Test(arguments: [
        (0, 0, PeaStage.pea),
        (0, 8, .pea),
        (1, 8, .hatched),
        (2, 8, .sprout),
        (3, 8, .sprout),
        (4, 8, .grown),
        (5, 8, .grown),
        (6, 8, .bud),
        (7, 8, .bud),
        (8, 8, .bloom),
        (1, 1, .bloom),
        (24, 100, .hatched),
        (25, 100, .sprout),
        (74, 100, .grown),
        (99, 100, .bud),
    ])
    func stageFollowsTodayProgress(done: Int, total: Int, stage: PeaStage) {
        #expect(PeaStage(done: done, total: total) == stage)
    }
}
