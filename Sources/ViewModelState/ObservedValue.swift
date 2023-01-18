/// Available to properties on classes conforming to ``ObservableState``.
/// `ObservedValue` makes sure that update handlers created through``UpdateObservable/didChange(withCurrent:handler:)-3mf14``
/// will be called with the updates intercepted by this property wrapper.
@propertyWrapper
public struct ObservedValue<Value> {

	internal var storage: Value
	public init(wrappedValue: Value) {
		self.storage = wrappedValue
	}

	@dynamicMemberLookup
	public struct Observer: UpdateObservable {
		let updateHandler: (_ handler: UpdateHandler<Value>) -> StateValueObserver

		public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> StateValueObserver {
			updateHandler(handler)
		}

		public subscript<Subject>(
			dynamicMember keyPath: KeyPath<Value, Subject>
		) -> ObservedValue<Subject>.Observer {
			.init { handler in
				updateHandler(handler.passThrough(from: keyPath))
			}
		}
	}

	/// Updates  the enclosing ``ObservableState``'s ``StateObserver`` whenever the value is changed
	public static subscript<EnclosingSelf: ObservableState>(
		_enclosingInstance instance: EnclosingSelf,
		wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
		storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
	) -> Value {
		get {
			/// Ping update observer signaling value getter was intercepted by this property wrapper
			/// For more details look into `validateGetter()` in ``StateObserver``‘s implementation
			instance.stateObserver.ping()
			return instance[keyPath: storageKeyPath].storage
		}
		set {
			let oldValue = instance[keyPath: storageKeyPath].storage
			let update = StateUpdate.updated(old: oldValue, new: newValue)
			instance[keyPath: storageKeyPath].storage = newValue
			/// Notify ``ObservableState`` of update
			instance.notifyUpdate(update, at: wrappedKeyPath, from: storageKeyPath)
		}
	}

	public static subscript<EnclosingSelf: ObservableState>(
		_enclosingInstance instance: EnclosingSelf,
		projected projectedKeyPath: KeyPath<EnclosingSelf, Observer>,
		storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
	) -> Observer {
		get {
			Observer(updateHandler: { instance.addObserver(keyPath: storageKeyPath, handler: $0) })
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
