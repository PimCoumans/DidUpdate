import Foundation

public class StateChangeObserver {

	private var observers: [WeakObserver] = []

	// TODO: Add methods for initial value and comparing values
	func didUpdate<Container: StateContainer, Value: Equatable>(
		_ viewModel: Container,
		keyPath: WritableKeyPath<Container, Value>,
		from oldValue: Value,
		to newValue: Value
	) {
		for observer in observers.filter({ $0.keyPath == keyPath }) {
			observer.handleChange(.changed(old: oldValue, new: newValue))
		}
	}

	func addObserver<Container: StateContainer, Value: Equatable>(
		keyPath: WritableKeyPath<Container, Value>,
		handler: ChangeHandler<Value>
	) -> Observer<Container, Value> {
		let observer = Observer(keyPath: keyPath, handler: handler)
		observer.onRelease = { [weak self] id in
			self?.observers.removeAll(where: { $0.id == id })
		}
		observers.append(WeakObserver(observer))
		return observer
	}
}

internal enum StateChange<Value: Equatable> {
	case initial(value: Value)
	case changed(old: Value, new: Value)
}

internal struct ChangeHandler<Value: Equatable> {
	let shouldHandleChange: (_ change: StateChange<Value>) -> Bool
	let acceptsInitialValue: Bool
	let handler: (_ change: StateChange<Value>) -> Void
}

internal protocol StateObserver {
	func handleChange(_ change: StateChange<some Equatable>)
}

internal extension StateChangeObserver {

	class Observer<Container, Value: Equatable>: StateObserver {

		typealias ID = UUID

		let id: ID = UUID()
		let keyPath: WritableKeyPath<Container, Value>
		let changeHandler: ChangeHandler<Value>

		var onRelease: ((_ id: ID) -> Void)?

		init(keyPath: WritableKeyPath<Container, Value>, handler: ChangeHandler<Value>) {
			self.keyPath = keyPath
			self.changeHandler = handler
		}

		deinit {
			onRelease?(id)
		}

		func handleChange(_ change: StateChange<some Equatable>) {
			guard let change = change as? StateChange<Value> else {
				preconditionFailure("Updated called with wrong type: \(change)")
			}
			if changeHandler.shouldHandleChange(change) {
				changeHandler.handler(change)
			}
		}
	}

	struct WeakObserver: StateObserver {

		let id: UUID
		let keyPath: AnyKeyPath
		let observer: () -> (any StateObserver)?

		init<Container: StateContainer>(_ observer: Observer<Container, some Equatable>) {
			self.id = observer.id
			self.keyPath = observer.keyPath as AnyKeyPath
			self.observer = { [weak observer] in
				observer
			}
		}

		@inlinable
		func handleChange(_ change: StateChange<some Equatable>) {
			observer()?.handleChange(change)
		}
	}
}
