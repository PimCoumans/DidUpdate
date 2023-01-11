/// Forwards value getting and setting to its originating ``StateContainer`` class wrapper by a ``ViewModel`` property wrapper,
/// and provides the functionality to subscribe to value changes true the `didChange` method.
@propertyWrapper @dynamicMemberLookup
public struct ValueProxy<Value: Equatable> {

	public typealias DidChangeHandler = (_ oldValue: Value, _ newValue: Value, _ isInitial: Bool) -> Void
	public typealias SingleValueDidChangeHandler = (_ newValue: Value) -> Void
	public typealias SingleValueDidChangeWithInitialHandler = (_ newValue: Value, _ isInitial: Bool) -> Void
	public typealias OldNewDidChangeHandler = (_ oldValue: Value, _ newValue: Value) -> Void

	let get: () -> Value
	let set: (_ newValue: Value) -> ()
	let addChangeHandler: (ChangeHandler<Value>) -> ViewStateObserver

	public var wrappedValue: Value {
		get { get() }
		nonmutating set { set(newValue) }
	}

	public var projectedValue: Self { self }

	public subscript<Subject>(
		dynamicMember keyPath: WritableKeyPath<Value, Subject>
	) -> ValueProxy<Subject> {
		ValueProxy<Subject>(self, keyPath: keyPath)
	}
}

public extension ValueProxy {
	func didChange(comparing keyPath: KeyPath<Value, some Equatable>, withLatest: Bool = false, _ handler: @escaping DidChangeHandler) -> ViewStateObserver {
		addChangeHandler(.init(shouldHandleChange: { $0.converted(with: keyPath).hasChanged }, acceptsInitialValue: withLatest, handler: handler))
	}

	func didChange(_ handler: @escaping DidChangeHandler) -> ViewStateObserver {
		addChangeHandler(.init(shouldHandleChange: { $0.hasChanged }, acceptsInitialValue: false, handler: handler))
	}
}

extension StateChange {
	@inlinable
	func converted<Subject: Equatable>(with keyPath: KeyPath<Value, Subject>) -> StateChange<Subject> {
		switch self {
		case .initial(let value):
			return .initial(value: value[keyPath: keyPath])
		case .changed(let old, let new):
			return .changed(old: old[keyPath: keyPath], new: new[keyPath: keyPath])
		}
	}

	@inlinable
	var hasChanged:  Bool {
		switch self {
		case .initial(_): return true
		case .changed(let old, let new) where old != new: return true
		default: return false
		}
	}
}

extension ChangeHandler {

	init(
		shouldHandleChange: @escaping (_ change: StateChange<Value>) -> Bool,
		acceptsInitialValue: Bool,
		handler : @escaping ValueProxy<Value>.DidChangeHandler
	) {
		self.shouldHandleChange = shouldHandleChange
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

	@inlinable
	func passThrough<RootValue: Equatable>(from keyPath: WritableKeyPath<RootValue, Value>) -> ChangeHandler<RootValue> {
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
	init<RootValue>(_ proxy: ValueProxy<RootValue>, keyPath: WritableKeyPath<RootValue, Value>) {
		self.get = { proxy.wrappedValue[keyPath: keyPath] }
		self.set = { proxy.wrappedValue[keyPath: keyPath] = $0 }
		self.addChangeHandler = { change in
			proxy.addChangeHandler(change.passThrough(from: keyPath))
		}
	}
}
