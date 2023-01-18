/// Enables change observation logic on any class conforming to``ObservableState`` and creates so-called 'value proxies' through its projected value (using the`$` prefix).
/// Relies on the ``ObservedValue`` property wrapper to update any observers, observing properties without this wrapper will log a warning (for now).
///
/// To subscribe to updates from your view use:
/// ```
/// $viewModel.yourValue.didChange { [weak self] newValue in
///    print("yourValue did update: \(newValue)")
/// }
/// ```
/// or from within your model class:
/// ```
/// init() {
///     $yourValue.didChange { [unowned self] newValue in
///         print("yourValue did update: \(newValue)")
///     }
/// }
/// ```
@propertyWrapper
public struct ObservedState<StateObject: ObservableState> {

	/// Creates `ValueProxy` structs to forward getting and setting of values and allow adding observers for specific keyPaths
	@dynamicMemberLookup
	public struct ObservableValues {
		fileprivate var object: StateObject
		public init(observing: StateObject) {
			self.object = observing
		}

		public subscript<Value>(
			dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
		) -> ValueProxy<Value> {
			ValueProxy(
				get: { object[keyPath: keyPath]},
				set: { newValue in
					object[keyPath: keyPath] = newValue
				},
				changeHandler: { changeHandler in
					object.addObserver(keyPath: keyPath, handler: changeHandler)
				}
			)
		}
	}

	private var observableValues: ObservableValues

	public init(wrappedValue: StateObject) {
		observableValues = ObservableValues(observing: wrappedValue)
	}

	public var wrappedValue: StateObject { observableValues.object }
	public var projectedValue: ObservableValues { observableValues }
}
