/// Forwards value getting and setting to its originating ``StateContainer`` class, wrapped by a ``ViewModel`` property wrapper,
/// and provides the functionality to subscribe to value changes through the `didChange` method.
@propertyWrapper @dynamicMemberLookup
public struct ValueProxy<Value> {
	/// Closure accepting all available arguments for changes: the previous value, the new value and wether the handler was called with just the current value
	public typealias DidChangeHandler = (_ oldValue: Value, _ newValue: Value, _ isInitial: Bool) -> Void
	/// Closure providing just the new value of the change as it's only argument
	public typealias SingleValueDidChangeHandler = (_ newValue: Value) -> Void

	let get: () -> Value
	let set: (_ newValue: Value) -> ()
	let addChangeHandler: (ChangeHandler<Value>) -> ViewStateObserver

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

public extension ValueProxy {
	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withLatest provideLatestValue: Bool = false,
		_ handler: @escaping DidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			acceptsInitialValue: provideLatestValue,
			handler: handler
		))
	}

	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withLatest provideLatestValue: Bool = false,
		_ handler: @escaping SingleValueDidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			acceptsInitialValue: provideLatestValue,
			handler: { _, new, _ in handler(new) }
		))
	}
}
public extension ValueProxy {
	/// Adds a change handler called whenever the observed value changes at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject>(
		comparing keyPath: KeyPath<Value, Subject>,
		withLatest provideLatestValue: Bool = false,
		_ handler: @escaping DidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValueIfEquatable },
			acceptsInitialValue: provideLatestValue,
			handler: handler
		))
	}

	/// Adds a change handler called whenever the observed value changes at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject>(
		comparing keyPath: KeyPath<Value, Subject>,
		withLatest provideLatestValue: Bool = false,
		_ handler: @escaping SingleValueDidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValueIfEquatable },
			acceptsInitialValue: provideLatestValue,
			handler: { _, new, _ in handler(new)}
		))
	}
}

extension StateChange {
	/// Converts the change's values to the value at provided keyPath
	@inlinable
	func converted<Subject>(with keyPath: KeyPath<Value, Subject>) -> StateChange<Subject> {
		switch self {
		case .initial(let value):
			return .initial(value: value[keyPath: keyPath])
		case .changed(let old, let new):
			return .changed(old: old[keyPath: keyPath], new: new[keyPath: keyPath])
		}
	}
}

extension Equatable {
	func equals(_ other: Any) -> Bool {
		other as? Self == self
	}
}

extension StateChange {
	/// Wether the values of the StateChange are different when `Value` conforms to `Equatable`
	/// - Note: `.initial` is always regarded as having a changed value
	@inlinable
	var hasChangedValueIfEquatable: Bool {
		switch self {
		case .initial: return true
		case .changed(let old as any Equatable, let new as any Equatable):
			return !old.equals(new)
		case .changed: return true
		}
	}
}

extension ChangeHandler {

	/// Convenience initializer converting a ``StateChange`` to a ``ValueProxy/DidChangeHandler```
	init(
		shouldHandleChange: ((_ change: StateChange<Value>) -> Bool)? = nil,
		acceptsInitialValue: Bool = false,
		handler : @escaping ValueProxy<Value>.DidChangeHandler
	) {
		self.shouldHandleChange = shouldHandleChange ?? { _ in true }
		self.acceptsInitialValue = acceptsInitialValue
		self.handler = { change in
			switch change {
			case .initial(let value):
				handler(value, value, true)
			case .changed(let old, let new):
				handler(old, new, false)
			}
		}
	}

	/// New change handler, forwarding closures with  keyPath to applied to change
	@inlinable
	func passThrough<RootValue>(from keyPath: WritableKeyPath<RootValue, Value>) -> ChangeHandler<RootValue> {
		.init(
			shouldHandleChange: { change in
				shouldHandleChange(change.converted(with: keyPath))
			},
			acceptsInitialValue: acceptsInitialValue,
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
		self.addChangeHandler = { change in
			proxy.addChangeHandler(change.passThrough(from: keyPath))
		}
	}
}
