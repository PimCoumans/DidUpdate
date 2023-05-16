import Foundation

/// Observer attached to any class conforming to ``ObservableState``, used together with the ``ObservedState`` property wrapper observer to be added for any values.
public class StateObserver {

	private var observers: [WeakObserver] = []

	private var receivedPing: Bool = false
	private var validatedObservedValues: Set<AnyKeyPath> = []

	/// Signals a property getter was intercepted by a ``ObservedValue`` property wrapper
	func ping() {
		receivedPing = true
	}

	/// Logs a warning when getter of property at given keyPath isn’t wrapped by ``ObservedValue``, so update handler would never be called
	/// Does not attempt to cast result to `Value`, instead also accepts when result is an `ObservedValue` itself
	fileprivate func validateGetter<Value>(for keyPath: AnyKeyPath, expecting: Value.Type, getter: () -> Any) {
		guard !validatedObservedValues.contains(keyPath) else {
			return
		}
		receivedPing = false
		let result = getter()
		if receivedPing || result is ObservedValue<Value> {
			validatedObservedValues.insert(keyPath)
		} else {
			print("Warning: update handlers for property \(type(of: keyPath)) won’t be called as it doesn’t have a @ViewState property wrapper!")
		}
	}
}

/// Forwarding calls to ``StateObserver``
extension ObservableState {
	/// Calls all observers for the given keyPath with new and old value
	func notifyUpdate<Value>(
		_ update: StateUpdate<Value>,
		at keyPath: KeyPath<Self, Value>,
		from storage: PartialKeyPath<Self>
	) {
		stateObserver.handleUpdate(update, at: keyPath, storage: storage)
	}

	/// Creates an observer for the value at the given keyPath
	func addObserver<Value>(
		keyPath: PartialKeyPath<Self>,
		handler: UpdateHandler<Value>
	) -> StateValueObserver {
		stateObserver.validateGetter(for: keyPath, expecting: Value.self) {
			self[keyPath: keyPath]
		}
		let observer = stateObserver.addObserver(keyPath: keyPath, handler: handler)
		if handler.updateWithCurrentValue {
			if let currentValue = self[keyPath: keyPath] as? Value {
				observer.handleUpdate(.current(value: currentValue))
			} else if let wrapper = self[keyPath: keyPath] as? ObservedValue<Value> {
				/// When adding observer from ``ObservedValue`` the keyPath points to the wrapper itself
				observer.handleUpdate(.current(value: wrapper.storage))
			}
		}
		return StateValueObserver(observer)
	}
}

/// Type of update an observer is called with
enum StateUpdate<Value> {
	/// Called when initial value should be provided
	case current(value: Value)
	/// Called when state was updated but not necessarily to different value
	case updated(old: Value, new: Value)
}

/// Any observer capable of handling a state updates
protocol UpdateHandleable {
	func handleUpdate<Value>(_ update: StateUpdate<Value>)
}

extension StateObserver {

	fileprivate func handleUpdate<Value>(
		_ update: StateUpdate<Value>,
		at valueKeyPath: AnyKeyPath,
		storage storageKeyPath: AnyKeyPath
	) {
		for observer in observers.filter({ $0.keyPath == valueKeyPath || $0.keyPath == storageKeyPath }) {
			observer.handleUpdate(update)
		}
	}

	fileprivate func addObserver<Value>(
		keyPath: AnyKeyPath,
		handler: UpdateHandler<Value>
	) -> Observer<Value> {
		let observer = Observer(keyPath: keyPath, handler: handler)
		observer.onRelease = { [weak self] id in
			self?.observers.removeAll(where: { $0.id == id })
		}
		observers.append(WeakObserver(observer))
		return observer
	}

	/// The actual observer of any state update, with a reference to the keyPath and executes the provided update handler
	class Observer<Value>: UpdateHandleable {
		typealias ID = UUID

		let id: ID = UUID()
		let keyPath: AnyKeyPath
		let updateHandler: UpdateHandler<Value>

		/// Closure called when observer is deallocated
		var onRelease: ((_ id: ID) -> Void)?

		init(keyPath: AnyKeyPath, handler: UpdateHandler<Value>) {
			self.keyPath = keyPath
			self.updateHandler = handler
		}

		deinit {
			onRelease?(id)
		}

		func handleUpdate<UpdatedValue>(_ update: StateUpdate<UpdatedValue>) {
			guard let update = update as? StateUpdate<Value> else {
				preconditionFailure("Update called with wrong type: \(update)")
			}
			updateHandler.handle(update: update)
		}
	}

	/// Weak wrapper for observer, forwarding state updates
	struct WeakObserver: UpdateHandleable, Equatable, Hashable {

		let id: UUID
		let keyPath: AnyKeyPath
		let observer: () -> UpdateHandleable?

		init<Value>(_ observer: Observer<Value>) {
			self.id = observer.id
			self.keyPath = observer.keyPath as AnyKeyPath
			self.observer = { [weak observer] in
				observer
			}
		}

		@inlinable
		func handleUpdate<Value>(_ update: StateUpdate<Value>) {
			observer()?.handleUpdate(update)
		}

		static func == (left: WeakObserver, right: WeakObserver) -> Bool {
			return left.id == right.id
		}

		func hash(into hasher: inout Hasher) {
			hasher.combine(id)
		}
	}
}
