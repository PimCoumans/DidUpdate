/// `StateContainer` -> ObservableObject
/// `ViewModel` -> ObservedObject
/// `ViewState` -> Published
/// `ValueProxy` -> Binding
/// `ViewStateObserver` ->  AnyCancellable

/*
 ## Create binding:
 $viewModel.your.value

 ## Get updates:
 observer = $viewModel.your.value.didChange { [weak self] old, new in }

 */
import Foundation

/// Enables change observation logic through KeyPath subscripts.
/// Use: `$viewModel.yourValue.didChange()` to subscribe to changes
@propertyWrapper
public struct ViewModel<Model: StateContainer> {

	@dynamicMemberLookup
	public struct Wrapper {

		fileprivate let viewModel: Model
		fileprivate init(viewModel: Model) {
			self.viewModel = viewModel
		}

		public subscript<Value: Equatable>(
			dynamicMember keyPath: ReferenceWritableKeyPath<Model, Value>
		) -> ValueProxy<Value> {
			ValueProxy(
				get: { viewModel[keyPath: keyPath]},
				set: { viewModel[keyPath: keyPath] = $0},
				addChangeHandler: { changeHandler in
					let observer = viewModel.changeObserver.addObserver(keyPath: keyPath, handler: changeHandler)
					if changeHandler.acceptsInitialValue {
						observer.handleChange(.initial(value: viewModel[keyPath: keyPath]))
					}
					return ViewStateObserver(observer)
				}
			)
		}
	}

	private let wrapper: Wrapper

	public init(wrappedValue: Model) {
		wrapper = Wrapper(viewModel: wrappedValue)
	}

	public var wrappedValue: Model { wrapper.viewModel }
	public var projectedValue: Wrapper { wrapper }
}

@propertyWrapper
public struct ViewState<Value: Equatable> {

	private var storage: Value
	public init(wrappedValue: Value) {
		self.storage = wrappedValue
	}

	public static subscript<Model: StateContainer>(
		_enclosingInstance instance: Model,
		wrapped wrappedKeyPath: ReferenceWritableKeyPath<Model, Value>,
		storage storageKeyPath: ReferenceWritableKeyPath<Model, Self>
	) -> Value {
		get {
			return instance[keyPath: storageKeyPath].storage
		}
		set {
			let oldValue = instance[keyPath: storageKeyPath].storage
			instance[keyPath: storageKeyPath].storage = newValue
			instance.changeObserver.didUpdate(instance, keyPath: wrappedKeyPath, from: oldValue, to: newValue)
		}
	}

	@available(*, unavailable, message: "This property wrapper can only be applied to a StateContainer")
	public var wrappedValue: Value {
		get { fatalError() }
		set { fatalError() }
	}
}
