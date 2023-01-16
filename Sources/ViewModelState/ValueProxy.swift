/// Forwards value getting and setting to its originating ``StateContainer`` class, wrapped by a ``ViewModel`` property wrapper,
/// and provides the functionality to subscribe to value changes through the `didChange` method.
@propertyWrapper @dynamicMemberLookup
public struct ValueProxy<Value>: ChangeObservable {
	public func addChangeHandler(_ handler: ChangeHandler<Value>) -> Observer {
		changeHandler(handler)
	}

	/// Closure accepting all available arguments for changes: the previous value, the new value and wether the handler was called with just the current value
	public typealias DidChangeHandler = (_ oldValue: Value, _ newValue: Value, _ isInitial: Bool) -> Void
	/// Closure providing just the new value of the change as it's only argument
	public typealias SingleValueDidChangeHandler = (_ newValue: Value) -> Void

	let get: () -> Value
	let set: (_ newValue: Value) -> ()
	let changeHandler: (ChangeHandler<Value>) -> ViewStateObserver

	public var wrappedValue: Value {
		get { get() }
		nonmutating set { set(newValue) }
	}

	/// Use the `$` syntax to access the `ValueProxy` itself to add change handlers or pass it on to other views, optionally appending any sub values through dynamic member lookup
	public var projectedValue: Self { self }

	public subscript<Subject>(
		dynamicMember keyPath: WritableKeyPath<Value, Subject>
	) -> ValueProxy<Subject> {
		ValueProxy<Subject>(self, keyPath: keyPath)
	}
}

extension ChangeHandler {
	/// New change handler, forwarding closures with  keyPath to applied to change
	func passThrough<RootValue>(from keyPath: WritableKeyPath<RootValue, Value>) -> ChangeHandler<RootValue> {
		.init(
			shouldHandleChange: shouldHandleChange.map { handler in
				{ handler($0.converted(with: keyPath)) }
			},
			updateWithCurrentValue: updateWithCurrentValue,
			handler: { change in
				// Pass through handler with keyPath applied to values
				handler(change.converted(with: keyPath))
			}
		)
	}
}

extension ValueProxy {
	/// Creates a new ValueProxy from an existing proxy,  applying the provided keyPath to its value and `StateChange`
	init<RootValue>(_ proxy: ValueProxy<RootValue>, keyPath: WritableKeyPath<RootValue, Value>) {
		self.get = { proxy.wrappedValue[keyPath: keyPath] }
		self.set = { proxy.wrappedValue[keyPath: keyPath] = $0 }
		self.changeHandler = { change in
			proxy.changeHandler(change.passThrough(from: keyPath))
		}
	}
}
