/// Forwards only the value getter to its originating ``ObservedValue`` property wrapper,
/// and provides the functionality to subscribe to value updates through methods like ``UpdateObservable/didUpdate(withCurrent:handler:)-3mf14``
@propertyWrapper @dynamicMemberLookup
public struct ReadOnlyProxy<Value>: UpdateObservable {
	let get: () -> Value
	let updateHandler: (UpdateHandler<Value>) -> StateValueObserver

	public var wrappedValue: Value {
		get {
			get()
		}
	}

	/// Use the `$` syntax to access the `ReadOnlyProxy` itself to add update handlers or pass it on to other views, optionally appending any child values through dynamic member lookup
	public var projectedValue: Self { self }

	public subscript<Subject>(
		dynamicMember keyPath: KeyPath<Value, Subject>
	) -> ReadOnlyProxy<Subject> {
		ReadOnlyProxy<Subject>(self, keyPath: keyPath)
	}
}

extension ReadOnlyProxy {
	/// Creates a `ReadOnlyProxy` that always returns the same value. Mostly useful for development and testing
	/// - Parameter value: Initial value that never changes
	public init(always value: Value) {
		self.get = { value }
		self.updateHandler = { handler in
			if handler.updateWithCurrentValue {
				handler.handle(update: .current(value: value))
			}
			return .init([])
		}
	}
}

extension ReadOnlyProxy {
	public var currentValue: Value {
		wrappedValue
	}

	public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer {
		updateHandler(handler)
	}

	public func map<MappedValue>(_ transform: @escaping (Value) -> MappedValue) -> ReadOnlyProxy<MappedValue> {
		ReadOnlyProxy<MappedValue>(
			get: { transform(wrappedValue) },
			updateHandler: { update in
				updateHandler(update.mapped(using: transform))
			}
		)
	}
}

extension ReadOnlyProxy: Equatable where Value: Equatable { }

extension ReadOnlyProxy {
	/// Creates a new ReadOnlyProxy from an existing proxy,  applying the provided keyPath to its value and `StateUpdate`
	init<Proxy: UpdateObservable>(_ proxy: Proxy, keyPath: KeyPath<Proxy.Value, Value>) {
		self.get = {
			proxy.currentValue[keyPath: keyPath]
		}
		self.updateHandler = { update in
			proxy.addUpdateHandler(update.passThrough(from: keyPath))
		}
	}
}
