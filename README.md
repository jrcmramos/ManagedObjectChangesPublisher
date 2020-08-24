# Description

`ManagedObjectChangesPublisher` exposes a `Publisher` to receive Core Data notifications associated with a ` NSFetchRequest<Object>` and `ManagedObjectChangesPublisher`.

# Usage

```Swift
let fetchRequest = self.newFetchRequest()
fetchRequest.predicate = Predicate.noEndingDate
fetchRequest.sortDescriptors = [SortDescriptor.startingTime(ascending: false)]

let currentValue: [ActivityMO] = (try? self.managedContext.fetch(fetchRequest)) ?? []
let currentActivity = ManagedObjectChangesPublisher(fetchRequest: fetchRequest,
                                                    context: self.managedContext)
```