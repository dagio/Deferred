//
//  TaskCollections.swift
//  Deferred
//
//  Created by Zachary Waldowski on 11/18/15.
//  Copyright © 2015-2016 Big Nerd Ranch. Licensed under MIT.
//

#if SWIFT_PACKAGE
import Deferred
import Result
#endif
import Foundation


extension CollectionType where Generator.Element: FutureType, Generator.Element.Value: ResultType {
    /// Compose a number of tasks into a single notifier task.
    ///
    /// If any of the contained tasks fail, the returned task will be determined
    /// with that failure. Otherwise, once all operations succeed, the returned
    /// task will be determined a success.
    public var joinedTasks: Task<Void> {
        if isEmpty {
            return Task(value: ())
        }

        let coalescingDeferred = Deferred<Task<Void>.Result>()
        let outerProgress = NSProgress(parent: nil, userInfo: nil)
        outerProgress.totalUnitCount = numericCast(count)
        let group = dispatch_group_create()

        for task in self {
            let innerProgress = NSProgress.wrapped(task, cancellation: nil)
            outerProgress.adoptChild(innerProgress, orphaned: true, pendingUnitCount: 1)

            dispatch_group_enter(group)
            task.upon { result in
                result.withValues(ifSuccess: { _ in }, ifFailure: { error in
                    _ = coalescingDeferred.fill(.Failure(error))
                })

                dispatch_group_leave(group)
            }
        }

        dispatch_group_notify(group, Task<Void>.genericQueue) {
            _ = coalescingDeferred.fill(.Success())
        }

        return Task(coalescingDeferred, progress: outerProgress)
    }
}
