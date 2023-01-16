import Foundation

/// Observer attached to any class conforming to ``StateContainer``, used together with the ``ViewModel`` property wrapper observer to be added for any values.
public class StateChangeObserver {

	private var observers: [WeakObserver] = []
	private var receivedPing: Bool = false
	
	private var validatedObservedValues: Set<AnyKeyPath> = []

	/// Signals a property getter was intercepted by a ``ViewState`` property wrapper
	internal func ping() {
		receivedPing = true
	}
	/// Logs a warning when getter of property at given keyPath isn‘t wrapper by ``ViewState``, so change handler would never be called
	fileprivate func expectPing(for keyPath: AnyKeyPath, from getter: () -> Void) {
		guard !validatedObservedValues.contains(keyPath) else {
			return
		}
		receivedPing = false
		getter()
		if !receivedPing {
			print("Warning: change handlers for property \(keyPath) won‘t be called as it doesn‘t have a @ViewState property wrapper!")
		} else {
			validatedObservedValues.insert(keyPath)
		}
	}
}

// Forwarding calls to StateChangeObserver
internal extension StateContainer {

	/// Calls all observers for the given keyPath with new and old value
	func notifyChange<Value>(
		at keyPath: ReferenceWritableKeyPath<Self, Value>,
		from oldValue: Value,
		to newValue: Value
	) {
		changeObserver.handleChange(keyPath: keyPath, from: oldValue, to: newValue)
	}

	/// Creates an observer for the value at the given keyPath
	func addObserver<Value>(
		keyPath: ReferenceWritableKeyPath<Self, Value>,
		handler: ChangeHandler<Value>
	) -> ViewStateObserver {
		changeObserver.expectPing(for: keyPath) {
			_ = self[keyPath: keyPath]
		}
		let observer = changeObserver.addObserver(keyPath: keyPath, handler: handler)
		if handler.acceptsInitialValue {
			observer.handleChange(.initial(value: self[keyPath: keyPath]))
		}
		return ViewStateObserver(observer)
	}
}

/// Type of change an observer is called with
internal enum StateChange<Value> {
	/// Called when initial value should be provided
	case initial(value: Value)
	/// Called when state was updated but not necessarily to different value
	case changed(old: Value, new: Value)
}

/// Instructions on how to handle a state change
internal struct ChangeHandler<Value> {
	let shouldHandleChange: ((_ change: StateChange<Value>) -> Bool)?
	let acceptsInitialValue: Bool
	let handler: (_ change: StateChange<Value>) -> Void

	func handles(_ change: StateChange<Value>) -> Bool {
		shouldHandleChange?(change) ?? true
	}
}

/// Any observer capable of handling a state change
internal protocol StateObserver {
	func handleChange<Value>(_ change: StateChange<Value>)
}

internal extension StateChangeObserver {

	fileprivate func handleChange<Container: StateContainer, Value>(
		keyPath: ReferenceWritableKeyPath<Container, Value>,
		from oldValue: Value,
		to newValue: Value
	) {
		for observer in observers.filter({ $0.keyPath == keyPath }) {
			observer.handleChange(.changed(old: oldValue, new: newValue))
		}
	}

	fileprivate func addObserver<Container: StateContainer, Value>(
		keyPath: ReferenceWritableKeyPath<Container, Value>,
		handler: ChangeHandler<Value>
	) -> Observer<Value> {
		let observer = Observer(keyPath: keyPath, handler: handler)
		observer.onRelease = { [weak self] id in
			self?.observers.removeAll(where: { $0.id == id })
		}
		observers.append(WeakObserver(observer))
		return observer
	}

	/// The actual observer of any state change, including its full key path and conditionally calls the change handler
	class Observer<Value>: StateObserver {
		typealias ID = UUID

		let id: ID = UUID()
		let keyPath: AnyKeyPath
		let changeHandler: ChangeHandler<Value>

		/// Closure called when observer is deallocated
		var onRelease: ((_ id: ID) -> Void)?

		init(keyPath: AnyKeyPath, handler: ChangeHandler<Value>) {
			self.keyPath = keyPath
			self.changeHandler = handler
		}

		deinit {
			onRelease?(id)
		}

		func handleChange<ChangedValue>(_ change: StateChange<ChangedValue>) {
			guard let change = change as? StateChange<Value> else {
				preconditionFailure("Updated called with wrong type: \(change)")
			}
			if changeHandler.handles(change) {
				changeHandler.handler(change)
			}
		}
	}

	/// Weak wrapper for observer, capable of forwarding state changes
	struct WeakObserver: StateObserver, Equatable, Hashable {

		let id: UUID
		let keyPath: AnyKeyPath
		let observer: () -> (any StateObserver)?

		init<Value>(_ observer: Observer<Value>) {
			self.id = observer.id
			self.keyPath = observer.keyPath as AnyKeyPath
			self.observer = { [weak observer] in
				observer
			}
		}

		@inlinable
		func handleChange<Value>(_ change: StateChange<Value>) {
			observer()?.handleChange(change)
		}

		static func == (left: WeakObserver, right: WeakObserver) -> Bool {
			return left.id == right.id
		}

		func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}
	}
}
