/// Instructions on how to handle a state update
public struct UpdateHandler<Value> {
	let updateWithCurrentValue: Bool
	let shouldHandleUpdate: ((_ update: StateUpdate<Value>) -> Bool)?
	let handler: (_ update: StateUpdate<Value>) -> Void

	func handle(update: StateUpdate<Value>) {
		guard shouldHandleUpdate?(update) ?? true else {
			return
		}
		handler(update)
	}
}

extension UpdateHandler {
	typealias DidUpdateHandler = (_ newValue: Value) -> Void
	typealias FullDidUpdateHandler = (_ oldValue: Value, _ newValue: Value, _ isCurrent: Bool) -> Void
	/// Convenience initializer converting a ``StateUpdate`` to a ``UpdateObservable/DidUpdateHandler``
	init(
		shouldHandleUpdate: ((_ update: StateUpdate<Value>) -> Bool)? = nil,
		updateWithCurrent: Bool = false,
		handler : @escaping DidUpdateHandler
	) {
		self.shouldHandleUpdate = shouldHandleUpdate
		self.updateWithCurrentValue = updateWithCurrent
		self.handler = { update in
			switch update {
			case .current(let value):
				handler(value)
			case .updated(_, let new):
				handler(new)
			}
		}
	}
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
	/// Creates update handler forwarding closures with transform applied to update
	func mapped<RootValue>(using transform: @escaping (RootValue) -> Value) -> UpdateHandler<RootValue> {
		.init(
			updateWithCurrentValue: updateWithCurrentValue,
			shouldHandleUpdate: shouldHandleUpdate.map { handler in
				{ handler($0.mapped(using: transform)) }
			},
			handler: { update in
				handler(update.mapped(using: transform))
			}
		)
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
public protocol UpdateObservable<Value> {
	associatedtype Value
	typealias Observer = StateValueObserver

	/// Retrieves the current or most recent value of the observable
	var currentValue: Value { get }

	/// Not to be called directly, but rather implemented by types conforming to `UpdateObservable`.
	/// Implement this method to create a ``StateValueObserver`` with the provided ``UpdateHandler``
	/// - Parameter handler: Update handler, properly configured through one of the `didUpdate` methods
	/// - Returns: Newly created ``StateValueObserver`` that calls the provide update handler
	func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer
	
	/// Maps the value of the receiving observable to `MappedValue`
	/// - Parameter transform: Closure that maps from `Value` to a new `MappedValue`
	/// - Returns: ``ReadOnlyProxy`` with new value
	func map<MappedValue>(_ transform: @escaping (Value) -> MappedValue) -> ReadOnlyProxy<MappedValue>
}

extension UpdateObservable where Value: Equatable {
	public static func ==(left: Self, right: Self) -> Bool {
		left.currentValue == right.currentValue
	}
}

extension UpdateObservable {
	/// Closure providing just the new value of the update as it’s only argument
	public typealias DidUpdateHandler = (_ newValue: Value) -> Void
	/// Closure accepting all available arguments for updates: the previous value, the new value and whether the handler was called with just the current value
	public typealias FullDidUpdateHandler = (_ oldValue: Value, _ newValue: Value, _ isCurrent: Bool) -> Void

	/// Adds an update handler called whenever the observed value updates
	/// - Parameters:
	///   - provideLatestValue: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didUpdate(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer {
		addUpdateHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value updates
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didUpdate(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping FullDidUpdateHandler
	) -> Observer {
		addUpdateHandler(.init(
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

extension UpdateObservable where Value: Equatable {
	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer {
		addUpdateHandler(.init(
			compareEquality: true,
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange(
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
		hasChangedValue(comparing: { $0 != $1 })
	}
}

extension StateUpdate {
	@inlinable func hasChangedValue(comparing comparer: (Value, Value) -> Bool) -> Bool {
		switch self {
		case .current: return true
		case .updated(let old, let new): return comparer(old, new)
		}
	}
}

extension UpdateHandler where Value: Equatable {
	/// Convenience initializer setting the shouldChangeHandler to compare old and new values
	init(
		compareEquality: Bool,
		updateWithCurrent: Bool = false,
		handler : @escaping DidUpdateHandler
	) {
		self.init(
			shouldHandleUpdate: compareEquality ? { $0.hasChangedValue } : nil,
			updateWithCurrent: updateWithCurrent,
			handler: handler
		)
	}

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
	/// Converts the update’s values using the provided transform closure
	@inlinable
	func mapped<Subject>(using transform: (Value) -> Subject) -> StateUpdate<Subject> {
		switch self {
		case .current(let value):
			return .current(value: transform(value))
		case .updated(let old, let new):
			return .updated(old: transform(old), new: transform(new))
		}
	}
	/// Converts the update’s values to the value at provided keyPath
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
	/// Converts the update’s values to the value at provided keyPath
	@inlinable
	func converted<Wrapped, Subject>(
		with keyPath: KeyPath<Wrapped, Subject>
	) -> StateUpdate<Subject?> where Value == Optional<Wrapped> {
		switch self {
		case .current(let value):
			return .current(value: value?[keyPath: keyPath])
		case .updated(let old, let new):
			return .updated(old: old?[keyPath: keyPath], new: new?[keyPath: keyPath])
		}
	}
}

extension UpdateObservable where Value: ExpressibleByNilLiteral {
	/// Adds an update handler called whenever the observed value has changed at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange<Wrapped, Subject: Equatable>(
		comparing keyPath: KeyPath<Wrapped, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidUpdateHandler
	) -> StateValueObserver where Value == Optional<Wrapped> {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed at the provided keyPath, with keyPath pointing to unwrapped value
	/// so it does not need to be composed with a preceding `.?.`
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange<Wrapped, Subject: Equatable>(
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

extension UpdateObservable {
	/// Adds an update handler called whenever the observed value has changed at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange<Subject: Equatable>(
		comparing keyPath: KeyPath<Value, Subject>,
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidUpdateHandler
	) -> StateValueObserver {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.converted(with: keyPath).hasChangedValue },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed at the provided keyPath
	/// - Parameters:
	///   - keyPath: KeyPath to value to compare, making sure the update handler is only executed when value changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange<Subject: Equatable>(
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

extension UpdateObservable {
	/// Adds an update handler called whenever the observed value has changed at the provided keyPaths
	/// - Parameters:
	///   - keyPaths: Array of KeyPaths to values to compare,
	///   making sure the update handler is only executed when at least one of the value has changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange(
		comparing keyPaths: [KeyPath<Value, some Equatable>],
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping DidUpdateHandler
	) -> StateValueObserver {
		addUpdateHandler(.init(
			shouldHandleUpdate: { update in
				keyPaths.contains { update.converted(with: $0).hasChangedValue }
			},
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed at the provided keyPath
	/// - Parameters:
	///   - keyPath: Array of KeyPaths to values to compare,
	///   making sure the update handler is only executed when at least one of the value has changed
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn’t called when deallocated
	public func didChange(
		comparing keyPaths: [KeyPath<Value, some Equatable>],
		withCurrent provideCurrent: Bool = false,
		_ handler: @escaping FullDidUpdateHandler
	) -> StateValueObserver {
		addUpdateHandler(.init(
			shouldHandleUpdate: { update in
				keyPaths.contains { update.converted(with: $0).hasChangedValue }
			},
			handler: handler
		))
	}
}
