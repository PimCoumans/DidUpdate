/// Opaque observer object, removing its observer from the `StateObserver` when deallocated
public struct StateValueObserver {
	private var observer: AnyObject

	init<Value>(_ observer: StateObserver.Observer<Value>) {
		self.observer = observer
	}

	init(_ observers: [StateValueObserver]) {
		self.observer = observers as AnyObject
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
	public typealias Observer = StateValueObserver
	public static func buildBlock(_ components: Observer...) -> [Observer] { components }
	public static func buildBlock() -> [Observer] { [] }
	public static func buildBlock(_ components: [Observer]...) -> [Observer] { components.flatMap { $0 } }
	public static func buildEither(first components: [Observer]) -> [Observer] { components }
	public static func buildEither(second components: [Observer]) -> [Observer] { components }
	public static func buildOptional(_ components: [Observer]?) -> [Observer] { components ?? [] }
	public static func buildExpression(_ expression: Observer) -> [Observer] { [expression] }
}

extension RangeReplaceableCollection where Element == StateValueObserver {
	/// Adds all resulting observers created in the builder closure
	public mutating func add(@ObserverBuilder _ builder: () -> [StateValueObserver]) {
		append(contentsOf: builder())
	}
}
