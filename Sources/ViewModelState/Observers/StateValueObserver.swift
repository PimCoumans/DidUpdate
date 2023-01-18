/// Opaque observer object, removing the its observer from the `StateObserver` when deallocated
public struct StateValueObserver {
	private var observer: AnyObject

	internal init<Value>(
		_ observer: StateObserver.Observer<Value>
	) {
		self.observer = observer
	}
}

extension StateValueObserver: Equatable, Hashable {
	public static func == (lhs: StateValueObserver, rhs: StateValueObserver) -> Bool {
		ObjectIdentifier(lhs.observer) == ObjectIdentifier(rhs.observer)
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(observer))
	}
}

extension StateValueObserver {
	public func add<Observers: RangeReplaceableCollection>(
		to collection: inout Observers
	) where Observers.Element == StateValueObserver {
		collection.append(self)
	}

	public func add(to set: inout Set<StateValueObserver>) {
		set.insert(self)
	}
}

@resultBuilder
public struct ObserverBuilder {
	public static func buildBlock(_ components: StateValueObserver...) -> [StateValueObserver] {
		components
	}
}

public extension RangeReplaceableCollection where Element == StateValueObserver {
	/// Adds all resulting observers created in the builder closure
	mutating func add(@ObserverBuilder _ builder: () -> [StateValueObserver]) {
		append(contentsOf: builder())
	}
}
