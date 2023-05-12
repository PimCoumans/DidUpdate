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

	/// Use the `$` syntax to access the `ReadOnlyValueProxy` itself to add update handlers or pass it on to other views, optionally appending any child values through dynamic member lookup
	public var projectedValue: Self { self }

	public subscript<Subject>(
		dynamicMember keyPath: KeyPath<Value, Subject>
	) -> ReadOnlyProxy<Subject> {
		ReadOnlyProxy<Subject>(self, keyPath: keyPath)
	}
}

extension ReadOnlyProxy {
	public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer {
		updateHandler(handler)
	}
}

extension ReadOnlyProxy {
	/// Creates a new ReadOnlyProxy from an existing proxy,  applying the provided keyPath to its value and `StateUpdate`
	init<RootValue>(_ proxy: ReadOnlyProxy<RootValue>, keyPath: KeyPath<RootValue, Value>) {
		self.get = {
			proxy.wrappedValue[keyPath: keyPath]
		}
		self.updateHandler = { update in
			proxy.updateHandler(update.passThrough(from: keyPath))
		}
	}
}
