/// Instructions on how to handle a state update
public struct UpdateHandler<Value> {
	let updateWithCurrentValue: Bool
	private let shouldHandleUpdate: ((_ update: StateUpdate<Value>) -> Bool)?
	private let handler: (_ update: StateUpdate<Value>) -> Void

	func handle(update: StateUpdate<Value>) {
		guard shouldHandleUpdate?(update) ?? true else {
			return
		}
		handler(update)
	}
}

extension UpdateHandler {
	typealias FullDidUpdateHandler = (_ oldValue: Value, _ newValue: Value, _ isCurrent: Bool) -> Void
	/// Convenience initializer converting a ``StateUpdate`` to a ``UpdateObservable/DidUpdateHandler``
	init(
		shouldHandleUpdate: ((_ update: StateUpdate<Value>) -> Bool)? = nil,
		updateWithCurrent: Bool = false,
		handler : @escaping FullDidUpdateHandler
	) {
		self.shouldHandleUpdate = shouldHandleUpdate
		self.updateWithCurrentValue = updateWithCurrent
		self.handler = { update in
			switch update {
			case .current(let value):
				handler(value, value, true)
			case .updated(let old, let new):
				handler(old, new, false)
			}
		}
	}

	/// Creates update handler forwarding closures with keyPath applied to update
	func passThrough<RootValue>(from keyPath: KeyPath<RootValue, Value>) -> UpdateHandler<RootValue> {
		.init(
			updateWithCurrentValue: updateWithCurrentValue,
			shouldHandleUpdate: shouldHandleUpdate.map { handler in
				{ handler($0.converted(with: keyPath)) }
			},
			handler: { update in
				// Pass through handler with keyPath applied to values
				handler(update.converted(with: keyPath))
			}
		)
	}
}

/// Methods for adding update handlers to state container values through methods providing just a closure
public protocol UpdateObservable {
	associatedtype Value
	typealias Observer = StateValueObserver

	/// Not to be called directly, but rather implemented by types conforming to `UpdateObservable`.
	/// Implement this method to create a ``StateValueObserver`` with the provided ``UpdateHandler``
	/// - Parameter handler: Update handler, properly configured through one of the `didUpdate` methods
	/// - Returns: Newly created ``StateValueObserver`` that calls the provide update handler
	func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer
}

public extension UpdateObservable {
	/// Closure providing just the new value of the update as it's only argument
	typealias DidUpdateHandler = (_ newValue: Value) -> Void
	/// Closure accepting all available arguments for updates: the previous value, the new value and wether the handler was called with just the current value
	typealias FullDidUpdateHandler = (_ oldValue: Value, _ newValue: Value, _ isCurrent: Bool) -> Void

	/// Adds an update handler called whenever the observed value updates
	/// - Parameters:
	///   - provideLatestValue: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didUpdate(withCurrent provideCurrent: Bool = false, handler: @escaping DidUpdateHandler) -> Observer {
		addUpdateHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds an update handler called whenever the observed value updates
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didUpdate(withCurrent provideCurrent: Bool = false, handler: @escaping FullDidUpdateHandler) -> Observer {
		addUpdateHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

public extension UpdateObservable where Value: Equatable {
	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer {
		addUpdateHandler(.init(
			compareEquality: true,
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping FullDidUpdateHandler
	) -> Observer {
		addUpdateHandler(.init(
			compareEquality: true,
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

extension StateUpdate where Value: Equatable {
	@inlinable var hasChangedValue: Bool {
		switch self {
		case .current: return true
		case .updated(let old, let new): return old != new
		}
	}
}

extension UpdateHandler where Value: Equatable {

	/// Convenience initializer setting the shouldChangeHandler to compare old and new values
	init(
		compareEquality: Bool,
		updateWithCurrent: Bool = false,
		handler : @escaping FullDidUpdateHandler
	) {
		self.init(
			shouldHandleUpdate: compareEquality ? { $0.hasChangedValue } : nil,
			updateWithCurrent: updateWithCurrent,
			handler: handler
		)
	}
}

extension StateUpdate {
	/// Converts the update's values to the value at provided keyPath
	@inlinable
	func converted<Subject>(with keyPath: KeyPath<Value, Subject>) -> StateUpdate<Subject> {
		switch self {
		case .current(let value):
			return .current(value: value[keyPath: keyPath])
		case .updated(let old, let new):
			return .updated(old: old[keyPath: keyPath], new: new[keyPath: keyPath])
		}
	}
}

extension StateUpdate where Value: ExpressibleByNilLiteral {

	/// Converts the update's values to the value at provided keyPath
	@inlinable
	func converted<Wrapped, Subject>(with keyPath: KeyPath<Wrapped, Subject>) -> StateUpdate<Subject?> where Value == Optional<Wrapped> {
		switch self {
		case .current(let value):
			return .current(value: value?[keyPath: keyPath])
		case .updated(let old, let new):
			return .updated(old: old?[keyPath: keyPath], new: new?[keyPath: keyPath])
		}
	}
}

public extension UpdateObservable where Value: ExpressibleByNilLiteral {
	/// Adds an update handler called whenever the observed value has changed at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Wrapped, Subject: Equatable>(
		comparing keyPath: KeyPath<Wrapped, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidUpdateHandler
	) -> StateValueObserver where Value == Optional<Wrapped> {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new) }
		))
	}

	/// Adds an update handler called whenever the observed value has changed at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Wrapped, Subject: Equatable>(
		comparing keyPath: KeyPath<Wrapped, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping FullDidUpdateHandler
	) -> StateValueObserver where Value == Optional<Wrapped> {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

public extension UpdateObservable {
	/// Adds an update handler called whenever the observed value has changed at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject: Equatable>(
		comparing keyPath: KeyPath<Value, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidUpdateHandler
	) -> StateValueObserver {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: { _, new, _ in handler(new)}
		))
	}

	/// Adds an update handler called whenever the observed value has changed at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Wether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and wether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	func didChange<Subject: Equatable>(
		comparing keyPath: KeyPath<Value, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping FullDidUpdateHandler
	) -> StateValueObserver {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}
