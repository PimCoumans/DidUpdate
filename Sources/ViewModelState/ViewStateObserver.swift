/// Opaque observer object, removing the its observer from the `StateChangeObserver` when deallocated
public struct ViewStateObserver {
	private var observer: AnyObject

	internal init<Value>(
		_ observer: StateChangeObserver.Observer<Value>
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
