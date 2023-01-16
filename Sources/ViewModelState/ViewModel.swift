/// Enables change observation logic on any class conforming to``StateContainer`` and creates so-called 'value proxies' through its projected value (using the`$` prefix).
/// Relies on the ``ViewState`` property wrapper to update any observers, observing properties without this wrapper will log a warning (for now).
///
/// To subscribe to changes from your view use:
/// ```
/// $viewModel.yourValue.didChange { [weak self] newValue in
///    print("yourValue changed: \(newValue)")
/// }
/// ```
/// or from within your model class:
/// ```
/// init() {
///     $yourValue.didChange { [unowned self] newValue in
///         print("yourValue changed: \(newValue)")
///     }
/// }
/// ```
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
