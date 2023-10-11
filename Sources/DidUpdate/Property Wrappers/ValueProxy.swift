/// Forwards value getting and setting to its originating ``ObservableState`` class, wrapped by an ``ObservedState`` property wrapper,
/// and provides the functionality to subscribe to value updates through methods like ``UpdateObservable/didUpdate(withCurrent:handler:)-3mf14``
@propertyWrapper @dynamicMemberLookup
public struct ValueProxy<Value>: UpdateObservable {
	let get: () -> Value
	let set: (_ newValue: Value) -> ()
	let updateHandler: (UpdateHandler<Value>) -> StateValueObserver

	public var wrappedValue: Value {
		get { get() }
		nonmutating set { set(newValue) }
	}

	/// Use the `$` syntax to access the `ValueProxy` itself to add update handlers or pass it on to other views, optionally appending any child values through dynamic member lookup
	public var projectedValue: Self { self }

	public subscript<Subject>(
		dynamicMember keyPath: WritableKeyPath<Value, Subject>
	) -> ValueProxy<Subject> {
		ValueProxy<Subject>(self, keyPath: keyPath)
	}

	@_disfavoredOverload
	public subscript<Subject>(
		dynamicMember keyPath: KeyPath<Value, Subject>
	) -> ReadOnlyProxy<Subject> {
		ReadOnlyProxy(
			get: { wrappedValue[keyPath: keyPath] },
			updateHandler: { update in
				updateHandler(update.passThrough(from: keyPath))
			}
		)
	}
}

extension ValueProxy {
	public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer {
		updateHandler(handler)
	}

	public func map<MappedValue>(_ transform: @escaping (Value) -> MappedValue) -> ReadOnlyProxy<MappedValue> {
		.init(
			get: { transform(wrappedValue) },
			updateHandler: { update in
				updateHandler(update.mapped(using: transform))
			}
		)
	}
}

extension ValueProxy {
	/// Creates a new ValueProxy from an existing proxy,  applying the provided keyPath to its value and `StateUpdate`
	init<RootValue>(_ proxy: ValueProxy<RootValue>, keyPath: WritableKeyPath<RootValue, Value>) {
		self.get = { proxy.wrappedValue[keyPath: keyPath] }
		self.set = { proxy.wrappedValue[keyPath: keyPath] = $0 }
		self.updateHandler = { update in
			proxy.updateHandler(update.passThrough(from: keyPath))
		}
	}
}
