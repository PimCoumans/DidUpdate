/// Available for any on properties of classes conforming to ``StateContainer``.
/// `ViewState` makes sure that change handlers created through``ValueProxy/didChange(withLatest:_:)-5y47`` will be called with the  changes
/// intercepted by this property wrapper.
@propertyWrapper
public struct ViewState<Value: Equatable> {

	private var storage: Value
	public init(wrappedValue: Value) {
		self.storage = wrappedValue
	}

	/// Updates  the enclosing ``StateContainer``'s ``StateChangeObserver`` whenever the value is changed
	public static subscript<EnclosingSelf: StateContainer>(
		_enclosingInstance instance: EnclosingSelf,
		wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
		storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
	) -> Value {
		get {
			/// Ping change observer signaling value getter was intercepted by this property wrapper
			/// For more details look into `expectPing()` in `StateChangeObserver`‘s implementation
			instance.changeObserver.ping()
			return instance[keyPath: storageKeyPath].storage
		}
		set {
			let oldValue = instance[keyPath: storageKeyPath].storage
			instance[keyPath: storageKeyPath].storage = newValue
			/// Notify `StateContainer` of change
			instance.notifyChange(at: wrappedKeyPath, from: oldValue, to: newValue)
		}
	}

	@available(
		*, unavailable,
		 message: "This property wrapper can only be applied to properties of classes conforming to StateContainer")
	public var wrappedValue: Value {
		get { fatalError() }
		set { fatalError() }
	}
}
