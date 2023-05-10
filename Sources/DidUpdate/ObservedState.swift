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

	public var wrappedValue: StateObject { didSet {
		print("Updating an @ObservedState’s value isn’t supported and only new observers will get updated")
	}}
	public var projectedValue: ObservableValues<StateObject> {
		wrappedValue.observableValues
	}

	public init(_ stateObject: StateObject) {
		wrappedValue = stateObject
	}

	public init(wrappedValue: StateObject) {
		self.wrappedValue = wrappedValue
	}
}
