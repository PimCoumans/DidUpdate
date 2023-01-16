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

 or:
 var observers: [ViewStateObserver] = []
 $viewModel.your.value.didChange { [weak self] new in /* ... */ }.add(to: &observers)

 */


/// Enables change observation logic through `KeyPath` subscripts.
/// Use `$viewModel.yourValue.didChange { ... }` to subscribe to changes
/// or from within your viewModel: `self.$yourValue.didChange { ... }`
@propertyWrapper
public struct ViewModel<Model: StateContainer> {

	/// Creates `ValueProxy` structs to forward getting and setting of values and allow adding observers for specific keyPaths
	@dynamicMemberLookup
	public struct ObservableValues {
		fileprivate var viewModel: Model
		public init(viewModel: Model) {
			self.viewModel = viewModel
		}

		public subscript<Value>(
			dynamicMember keyPath: ReferenceWritableKeyPath<Model, Value>
		) -> ValueProxy<Value> {
			ValueProxy(
				get: { viewModel[keyPath: keyPath]},
				set: { newValue in
					viewModel[keyPath: keyPath] = newValue
				},
				changeHandler: { changeHandler in
					viewModel.addObserver(keyPath: keyPath, handler: changeHandler)
				}
			)
		}
	}

	private var observableValues: ObservableValues

	public init(wrappedValue: Model) {
		observableValues = ObservableValues(viewModel: wrappedValue)
	}

	public var wrappedValue: Model { observableValues.viewModel }
	public var projectedValue: ObservableValues { observableValues }
}
