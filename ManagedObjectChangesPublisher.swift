//

import Foundation
import Combine
import CoreData

public struct ManagedObjectChangesPublisher<Object: NSManagedObject>: Publisher {
    public typealias Output = [Object]
    public typealias Failure = Never

    let fetchRequest: NSFetchRequest<Object>
    let context: NSManagedObjectContext

    init(fetchRequest: NSFetchRequest<Object>,
         context: NSManagedObjectContext) {
        self.fetchRequest = fetchRequest
        self.context = context
    }

    public func receive<S: Subscriber>(subscriber: S) where Output == S.Input, Failure == S.Failure {
        let inner = Inner(downstream: subscriber,
                          fetchRequest: self.fetchRequest,
                          context: self.context)

        subscriber.receive(subscription: inner)
    }
}

public extension ManagedObjectChangesPublisher {

    private final class Inner<Downstream: Subscriber>: NSObject, Subscription, NSFetchedResultsControllerDelegate where Downstream.Input == [Object], Downstream.Failure == Never {

        private let downstream: Downstream
        private var fetchedResultsController: NSFetchedResultsController<Object>?
        private var demand: Subscribers.Demand = .none

        init(downstream: Downstream,
             fetchRequest: NSFetchRequest<Object>,
             context: NSManagedObjectContext) {

            self.downstream = downstream

            self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                       managedObjectContext: context,
                                                                       sectionNameKeyPath: nil,
                                                                       cacheName: nil)

            super.init()

            self.fetchedResultsController!.delegate = self

            try? fetchedResultsController!.performFetch()
            self.fulfillDemand()
        }

        func request(_ demand: Subscribers.Demand) {
            self.demand += demand

           self.fulfillDemand()
        }

        func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
            self.fulfillDemand()
        }

        private func fulfillDemand() {
            guard self.demand > 0 else {
                return
            }

            let newValue = Array(fetchedResultsController?.fetchedObjects ?? [])
            let newDemand = downstream.receive(newValue)

            self.demand += newDemand
            self.demand -= 1
        }

        func cancel() {
            self.fetchedResultsController?.delegate = nil
            self.fetchedResultsController = nil
        }
    }
}

extension Publisher {
    func applyingChanges<Changes: Publisher, ChangeItem>(
        _ changes: Changes,
        _ transform: @escaping (ChangeItem) -> Output.Element
    ) -> AnyPublisher<Output, Failure>
    where Output: RangeReplaceableCollection,
        Output.Index == Int,
        Changes.Output == CollectionDifference<ChangeItem>,
        Changes.Failure == Failure {

        zip(changes) { existing, changes -> Output in
            var objects = existing
            for change in changes {
                switch change {
                case .remove(let offset, _, _):
                    objects.remove(at: offset)
                case .insert(let offset, let obj, _):
                    let transformed = transform(obj)
                    objects.insert(transformed, at: offset)
                }
            }
            return objects
        }.eraseToAnyPublisher()
    }
}
