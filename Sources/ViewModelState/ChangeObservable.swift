/// Instructions on how to handle a state change
public struct ChangeHandler<Value> {
	let updateWithCurrentValue: Bool
	private let shouldHandleChange: ((_ change: StateChange<Value>) -> Bool)?
	private let handler: (_ change: StateChange<Value>) -> Void

	func handle(change: StateChange<Value>) {
		guard shouldHandleChange?(change) ?? true else {
			return
		}
		handler(change)
	}
}

extension ChangeHandler {
	/// Convenience initializer converting a ``StateChange`` to a ``ValueProxy/DidChangeHandler```
	init(
		shouldHandleChange: ((_ change: StateChange<Value>) -> Bool)? = nil,
		updateWithCurrent: Bool = false,
		handler : @escaping ValueProxy<Value>.DidChangeHandler
	) {
		self.shouldHandleChange = shouldHandleChange
		self.updateWithCurrentValue = updateWithCurrent
		self.handler = { change in
			switch change {
			case .current(let value):
				handler(value, value, true)
			case .changed(let old, let new):
				handler(old, new, false)
			}
		}
	}

	/// Creates change handler forwarding closures with keyPath applied to change
	func passThrough<RootValue>(from keyPath: KeyPath<RootValue, Value>) -> ChangeHandler<RootValue> {
		.init(
			updateWithCurrentValue: updateWithCurrentValue,
			shouldHandleChange: shouldHandleChange.map { handler in
				{ handler($0.converted(with: keyPath)) }
			},
			handler: { change in
				// Pass through handler with keyPath applied to values
				handler(change.converted(with: keyPath))
			}
		)
	}
}

/// Methods for adding change handlers to state container values through methods providing just a closure
public protocol ChangeObservable {
	associatedtype Value
	typealias Observer = ViewStateObserver

	/// Not to be called directly, but rather implemented by types conforming to `ChangeObservable`.
	/// Implement this method to create a ``ViewStateObserver`` with the provided ``ChangeHandler``
	/// - Parameter handler: Change handler, properly configured through one of the `didChange` methods
	/// - Returns: Newly created ``ViewStateObserver`` that calls the provide change handler
	func addChangeHandler(_ handler: ChangeHandler<Value>) -> Observer
}

public extension ChangeObservable {
	/// Closure providing just the new value of the change as it's only argument
	typealias DidChangeHandler = (_ newValue: Value) -> Void
	/// Closure accepting all available arguments for changes: the previous value, the new value and wether the handler was called with just the current value
	typealias FullDidChangeHandler = (_ oldValue: Value, _ newValue: Value, _ isInitial: Bool) -> Void

	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(withCurrent provideCurrent: Bool = false, handler: @escaping DidChangeHandler) -> Observer {
		addChangeHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(withCurrent provideCurrent: Bool = false, handler: @escaping FullDidChangeHandler) -> Observer {
		addChangeHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

public extension ChangeObservable where Value: Equatable {
	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withCurrent provideCurrent: Bool = false,
		compareEqual: Bool = true,
		handler: @escaping DidChangeHandler
	) -> Observer {
		addChangeHandler(.init(
			compareEquality: compareEqual,
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds a change handler called whenever the observed value changes
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withCurrent provideCurrent: Bool = false,
		compareEqual: Bool = true,
		handler: @escaping FullDidChangeHandler
	) -> Observer {
		addChangeHandler(.init(
			compareEquality: compareEqual,
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

extension StateChange where Value: Equatable {
	@inlinable var hasChangedValue: Bool {
		switch self {
		case .current: return true
		case .changed(let old, let new): return old != new
		}
	}
}

extension ChangeHandler where Value: Equatable {

	/// Convenience initializer setting the shouldChangeHandler to compare old and new values
	init(
		compareEquality: Bool,
		updateWithCurrent: Bool = false,
		handler : @escaping ValueProxy<Value>.DidChangeHandler
	) {
		self.init(
			shouldHandleChange: compareEquality ? { $0.hasChangedValue } : nil,
			updateWithCurrent: updateWithCurrent,
			handler: handler
		)
	}
}

extension StateChange {
	/// Converts the change's values to the value at provided keyPath
	@inlinable
	func converted<Subject>(with keyPath: KeyPath<Value, Subject>) -> StateChange<Subject> {
		switch self {
		case .current(let value):
			return .current(value: value[keyPath: keyPath])
		case .changed(let old, let new):
			return .changed(old: old[keyPath: keyPath], new: new[keyPath: keyPath])
		}
	}
}

extension StateChange where Value: ExpressibleByNilLiteral {

	/// Converts the change's values to the value at provided keyPath
	@inlinable
	func converted<Wrapped, Subject>(with keyPath: KeyPath<Wrapped, Subject>) -> StateChange<Subject?> where Value == Optional<Wrapped> {
		switch self {
		case .current(let value):
			return .current(value: value?[keyPath: keyPath])
		case .changed(let old, let new):
			return .changed(old: old?[keyPath: keyPath], new: new?[keyPath: keyPath])
		}
	}
}

public extension ChangeObservable where Value: ExpressibleByNilLiteral {
	/// Adds a change handler called whenever the observed value changes at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Wrapped, Subject: Equatable>(
		comparing keyPath: KeyPath<Wrapped, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidChangeHandler
	) -> ViewStateObserver where Value == Optional<Wrapped> {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds a change handler called whenever the observed value changes at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Wrapped, Subject: Equatable>(
		comparing keyPath: KeyPath<Wrapped, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping FullDidChangeHandler
	) -> ViewStateObserver where Value == Optional<Wrapped> {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

public extension ChangeObservable {
	/// Adds a change handler called whenever the observed value changes at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject: Equatable>(
		comparing keyPath: KeyPath<Value, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new)}
		))
	}

	/// Adds a change handler called whenever the observed value changes at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the change handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject: Equatable>(
		comparing keyPath: KeyPath<Value, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping FullDidChangeHandler
	) -> ViewStateObserver {
		addChangeHandler(.init(
			shouldHandleChange: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}
