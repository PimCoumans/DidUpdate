/// Forwards value getting and setting to a weakly referenced originating ``ObservableState`` class, wrapped by an ``ObservedState`` property wrapper,
/// and provides the functionality to subscribe to value updates through methods like ``UpdateObservable/didUpdate(withCurrent:handler:)-3mf14``
@propertyWrapper @dynamicMemberLookup
public class WeakValueProxy<Value>: UpdateObservable {
	let get: () -> Value?
	let set: (Value) -> Void
	let updateHandler: (UpdateHandler<Value>) -> StateValueObserver?
	
	/// Value used as caching when observed class is no longer availableff
	private var storedValue: Value

	public var wrappedValue: Value {
		get {
			if let value = get() {
				storedValue = value
				return value
			}
			return storedValue
		}
		set {
			storedValue = newValue
			set(newValue)
		}
	}

	public var projectedValue: WeakValueProxy<Value> { self }

	init(
		currentValue: Value,
		get: @escaping () -> Value?,
		set: @escaping (Value) -> Void,
		updateHandler: @escaping(UpdateHandler<Value>) -> StateValueObserver?
	) {
		self.get = get
		self.set = set
		self.updateHandler = updateHandler
		self.storedValue = currentValue
	}

	public subscript<Subject>(
		dynamicMember keyPath: WritableKeyPath<Value, Subject>
	) -> WeakValueProxy<Subject> {
		WeakValueProxy<Subject>(self, keyPath: keyPath)
	}

	@_disfavoredOverload
	public subscript<Subject>(
		dynamicMember keyPath: KeyPath<Value, Subject>
	) -> WeakReadOnlyProxy<Subject> {
		WeakReadOnlyProxy(
			currentValue: wrappedValue[keyPath: keyPath],
			get: { self.wrappedValue[keyPath: keyPath] },
			updateHandler: { update in
				self.updateHandler(update.passThrough(from: keyPath))
			}
		)
	}
}

extension WeakValueProxy {
	public var currentValue: Value {
		wrappedValue
	}

	public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> StateValueObserver {
		let observer = updateHandler(handler)
		if let observer {
			return observer
		}
		print("Can’t add handler for released ObservableState object, change handler won’t be called other than with current value")
		if handler.updateWithCurrentValue {
			handler.handle(update: .current(value: currentValue))
		}
		let emptyObserver = StateObserver.Observer(keyPath: \Self.currentValue, handler: handler)
		return StateValueObserver(emptyObserver)
	}

	public func map<MappedValue>(_ transform: @escaping (Value) -> MappedValue) -> ReadOnlyProxy<MappedValue> {
		.init(
			get: { transform(self.wrappedValue) },
			updateHandler: { update in
				self.addUpdateHandler(update.mapped(using: transform))
			}
		)
	}
}

extension WeakValueProxy {
	convenience init<RootValue>(_ proxy: WeakValueProxy<RootValue>, keyPath: WritableKeyPath<RootValue, Value>) {
		self.init(
			currentValue: proxy.currentValue[keyPath: keyPath],
			get: { proxy.wrappedValue[keyPath: keyPath] },
			set: { proxy.wrappedValue[keyPath: keyPath] = $0 },
			updateHandler: { update in
				proxy.updateHandler(update.passThrough(from: keyPath))
			}
		)
	}
}
