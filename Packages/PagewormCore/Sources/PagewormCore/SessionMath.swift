import Foundation

public struct SessionDraft: Equatable {
    public var startPage: Int
    public var endPage: Int
    public var startedAt: Date
    public var endedAt: Date

    public init(startPage: Int, endPage: Int, startedAt: Date, endedAt: Date) {
        self.startPage = startPage
        self.endPage = endPage
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct SessionResult: Equatable {
    public var pages: Int
    public var minutes: Double
    public var pagesPerHour: Double?
    public var grantsUnlock: Bool

    public init(pages: Int, minutes: Double, pagesPerHour: Double?, grantsUnlock: Bool) {
        self.pages = pages
        self.minutes = minutes
        self.pagesPerHour = pagesPerHour
        self.grantsUnlock = grantsUnlock
    }
}

public enum SessionMath {
    public enum Validation: Error, Equatable {
        case negativePage
        case endBeforeStart
        case endBeforeStartTime
    }

    public static func result(_ draft: SessionDraft) throws -> SessionResult {
        guard draft.startPage >= 0, draft.endPage >= 0 else { throw Validation.negativePage }
        guard draft.endPage >= draft.startPage else { throw Validation.endBeforeStart }
        guard draft.endedAt >= draft.startedAt else { throw Validation.endBeforeStartTime }
        let pages = draft.endPage - draft.startPage
        let minutes = draft.endedAt.timeIntervalSince(draft.startedAt) / 60
        return SessionResult(
            pages: pages,
            minutes: minutes,
            pagesPerHour: ReadingStats.pagesPerHour(pages: pages, minutes: minutes),
            grantsUnlock: UnlockPolicy.grantsUnlock(elapsed: draft.endedAt.timeIntervalSince(draft.startedAt))
        )
    }
}
