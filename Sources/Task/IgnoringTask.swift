//
//  IgnoringTask.swift
//  Deferred
//
//  Created by Zachary Waldowski on 4/15/16.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Foundation

/// A `FutureType` whose determined element is that of a `Base` future passed
/// through a transform function returning `NewValue`. This value is computed
/// each time it is read through a call to `upon(queue:body:)`.
private struct LazyMapFuture<Base: FutureType, NewValue>: FutureType {

    let base: Base
    let transform: Base.Value -> NewValue
    init(_ base: Base, transform: Base.Value -> NewValue) {
        self.base = base
        self.transform = transform
    }

    /// Call some function `body` once the value becomes determined.
    ///
    /// If the value is determined, the function will be submitted to the
    /// queue immediately. An upon call is always executed asynchronously.
    ///
    /// - parameter queue: A dispatch queue to execute the function `body` on.
    /// - parameter body: A function that uses the delayed value.
    func upon(executor: ExecutorType, body: NewValue -> Void) {
        return base.upon(executor) { [transform] in
            body(transform($0))
        }
    }

    /// Waits synchronously, for a maximum `time`, for the calculated value to
    /// become determined; otherwise, returns `nil`.
    func wait(time: Timeout) -> NewValue? {
        return base.wait(time).map(transform)
    }
    
}

extension Future where Value: ResultType {
    /// Create a future having the same underlying task as `other`.
    public init<Other: FutureType where Other.Value: ResultType, Other.Value.Value == Value.Value>(task other: Other) {
        self.init(LazyMapFuture(other) {
            Value(with: $0.extract)
        })
    }
}

extension Task {
    /// Returns a task that ignores the successful completion of this task.
    ///
    /// This is semantically identical to the following:
    ///
    ///     myTask.map { _ in }
    ///
    /// But behaves more efficiently.
    ///
    /// The resulting task is cancellable in the same way the recieving task is.
    ///
    /// - seealso: map(_:)
    public func ignored() -> Task<Void> {
        let future = Future(LazyMapFuture(self) { (result) -> TaskResult<Void> in
            result.withValues(ifSuccess: { _ in TaskResult.Success() }, ifFailure: TaskResult.Failure)
        })

        return Task<Void>(future: future, progress: progress)
    }
}
