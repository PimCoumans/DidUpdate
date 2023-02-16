/// Enables update observation logic on any class conforming to``ObservableState`` and creates so-called 'value proxies' through its projected value (using the`$` prefix).
/// Relies on the ``ObservedValue`` property wrapper to update any observers, observing properties without this wrapper will log a warning (for now).
///
/// To subscribe to updates from your view use:
/// ```
/// $viewModel.yourValue.didUpdate { [weak self] newValue in
///    print("yourValue did update: \(newValue)")
/// }
/// ```
/// or from within your model class:
/// ```
/// init() {
///     $yourValue.didUpdate { [unowned self] newValue in
///         print("yourValue did update: \(newValue)")
///     }
/// }
/// ```
@propertyWrapper
public struct ObservedState<StateObject: ObservableState> {

	/// Creates `ValueProxy` structs to forward getting and setting of values and allow adding observers for specific keyPaths
	@dynamicMemberLookup
	public struct ObservableValues {
		fileprivate var stateObject: () -> StateObject
		public init(observing: @autoclosure @escaping () -> StateObject) {
			self.stateObject = observing
		}

		public subscript<Value>(
			dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
		) -> ValueProxy<Value> {
			ValueProxy(
				get: { stateObject()[keyPath: keyPath]},
				set: { newValue in
					stateObject()[keyPath: keyPath] = newValue
				},
				updateHandler: { updateHandler in
					stateObject().addObserver(keyPath: keyPath, handler: updateHandler)
				}
			)
		}
	}

	public var wrappedValue: StateObject
	public var projectedValue: ObservableValues {
		ObservableValues(observing: wrappedValue)
	}

	public init(_ stateObject: StateObject) {
		wrappedValue = stateObject
	}

	public init(wrappedValue: StateObject) {
		self.wrappedValue = wrappedValue
	}
}
