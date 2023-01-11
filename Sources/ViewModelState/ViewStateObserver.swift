/// Opaque observer object, removing the observation logic when deallocated
public struct ViewStateObserver {
	private var observer: AnyObject

	internal init<Container, Value: Equatable>(
		_ observer: StateChangeObserver.Observer<Container, Value>
	) {
		self.observer = observer
	}
}

extension ViewStateObserver: Hashable {
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
