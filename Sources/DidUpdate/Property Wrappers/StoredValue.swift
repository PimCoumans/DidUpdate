import Foundation

/// Available to properties on classes conforming to ``ObservableState``.
/// `StoredValue` behaves just like ``ObservedValue`` only  its actual storage is handled by `UserDefaults`.
/// Other than that it can create a ``ReadOnlyValueProxy`` (or ``ValueProxy`` through ``ObservedState``’s projected value)
/// and as a result its projected value allows for the creation of ``UpdateObservable/didUpdate(withCurrent:handler:)-3mf14`` observers.
@propertyWrapper
public struct StoredValue<Value> {
	let defaultValue: Value

	let getter: () -> Value?
	let setter: (Value) -> Void

	private var storage: Value {
		get {
			getter() ?? defaultValue
		}
		nonmutating set {
			setter(newValue)
		}
	}

	/// Creates a new StoredValue property wrapper
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
		defaultValue = wrappedValue
		getter = {
			store.value(forKey: key) as? Value
		}
		setter = { value in
			store.set(value, forKey: key)
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
			/// For more details look into `validateGetter()` in ``StateObserver``’s implementation
			instance.stateObserver.ping()
			return instance[keyPath: storageKeyPath].storage
		}
		set {
			let oldValue = instance[keyPath: storageKeyPath].storage
			let update: StateUpdate = .updated(old: oldValue, new: newValue)
			instance[keyPath: storageKeyPath].storage = newValue
			/// Notify ``ObservableState`` of update
			instance.notifyUpdate(update, at: wrappedKeyPath, from: storageKeyPath)
		}
	}

	/// Creates a read only proxy to the ``StoredValue``’s current value and allows adding update handlers
	public static subscript<EnclosingSelf: ObservableState>(
		_enclosingInstance instance: EnclosingSelf,
		projected projectedKeyPath: KeyPath<EnclosingSelf, ReadOnlyProxy<Value>>,
		storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
	) -> ReadOnlyProxy<Value> {
		get {
			return ReadOnlyProxy(
				get: {
					instance[keyPath: storageKeyPath].storage
				},
				updateHandler: { instance.addObserver(keyPath: storageKeyPath, handler: $0) }
			)
		}
	}

	@available(
		*, unavailable,
		 message: "This property wrapper can only be applied to properties of classes conforming to ObservableState")
	public var wrappedValue: Value {
		get { fatalError() }
		set { fatalError() }
	}

	@available(
		*, unavailable,
		 message: "This property wrapper can only be applied to properties of classes conforming to ObservableState")
	public var projectedValue: ReadOnlyProxy<Value> {
		fatalError()
	}
}

extension StoredValue where Value: ExpressibleByNilLiteral {
	/// Creates a new StoredValue property wrapper with a default `nil` value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init<WrappedValue>(wrappedValue: Optional<WrappedValue> = nil, _ key: String, store: UserDefaults = .standard) where Value == Optional<WrappedValue> {
		defaultValue = wrappedValue
		getter = {
			store.value(forKey: key) as? Value
		}
		setter = { value in
			if let value {
				store.setValue(value, forKey: key)
			} else {
				store.removeObject(forKey: key)
			}
		}
	}
}
