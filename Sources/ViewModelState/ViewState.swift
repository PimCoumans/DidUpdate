/// Available for any on properties of classes conforming to ``StateContainer``.
/// `ViewState` makes sure that change handlers created through``ValueProxy/didChange(withLatest:_:)-5y47`` will be called with the  changes
/// intercepted by this property wrapper.
@propertyWrapper
public struct ViewState<Value> {

	private var storage: Value
	public init(wrappedValue: Value) {
		self.storage = wrappedValue
	}

	@dynamicMemberLookup
	public struct Observer: ChangeObservable {
		let changeHandler: (_ handler: ChangeHandler<Value>) -> ViewStateObserver
		public func addChangeHandler(_ handler: ChangeHandler<Value>) -> ViewStateObserver {
			changeHandler(handler)
		}

		public subscript<Subject>(
			dynamicMember keyPath: WritableKeyPath<Value, Subject>
		) -> ViewState<Subject>.Observer {
			.init { handler in
				changeHandler(handler.passThrough(from: keyPath))
			}
		}
	}

	/// Updates  the enclosing ``StateContainer``'s ``StateContainerObserver`` whenever the value is changed
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
			instance.notifyChange(at: storageKeyPath, from: oldValue, to: newValue)
		}
	}

	public static subscript<EnclosingSelf: StateContainer>(
		_enclosingInstance instance: EnclosingSelf,
		projected projectedKeyPath: KeyPath<EnclosingSelf, Observer>,
		storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
	) -> Observer {
		get {
			Observer(changeHandler: { instance.addObserver(keyPath: storageKeyPath, handler: $0) })
		}
	}

	@available(
		*, unavailable,
		 message: "This property wrapper can only be applied to properties of classes conforming to StateContainer")
	public var wrappedValue: Value {
		get { fatalError() }
		set { fatalError() }
	}

	@available(
		*, unavailable,
		 message: "This property wrapper can only be applied to properties of classes conforming to StateContainer")
	public var projectedValue: Observer {
		fatalError()
	}
}
