/// Opaque observer object, removing the its observer from the `StateContainerObserver` when deallocated
public struct ViewStateObserver {
	private var observer: AnyObject

	internal init<Value>(
		_ observer: StateContainerObserver.Observer<Value>
	) {
		self.observer = observer
	}
}

extension ViewStateObserver: Equatable, Hashable {
	public static func == (lhs: ViewStateObserver, rhs: ViewStateObserver) -> Bool {
		ObjectIdentifier(lhs.observer) == ObjectIdentifier(rhs.observer)
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(ObjectIdentifier(observer))
	}
}

extension ViewStateObserver {
	public func add<Observers: RangeReplaceableCollection>(
		to collection: inout Observers
	) where Observers.Element == ViewStateObserver {
		collection.append(self)
	}

	public func add(to set: inout Set<ViewStateObserver>) {
		set.insert(self)
	}
}

@resultBuilder
public struct ObserverBuilder {
	public static func buildBlock(_ components: ViewStateObserver...) -> [ViewStateObserver] {
		components
	}
}

public extension RangeReplaceableCollection where Element == ViewStateObserver {
	/// Adds all resulting observers created in the builder closure
	mutating func add(@ObserverBuilder _ builder: () -> [ViewStateObserver]) {
		append(contentsOf: builder())
	}
}
