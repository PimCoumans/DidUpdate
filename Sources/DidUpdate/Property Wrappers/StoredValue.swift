import Foundation

/// Available to properties on classes conforming to ``ObservableState``.
/// `StoredValue` behaves just like ``ObservedValue`` only its actual storage is handled by `UserDefaults`.
/// Other than that it can create a ``ReadOnlyValueProxy`` (or ``ValueProxy`` through ``ObservedState``’s projected value)
/// and as a result its projected value allows for the creation of ``UpdateObservable/didUpdate(withCurrent:handler:)-3mf14`` observers.
@propertyWrapper
public struct StoredValue<Value> {
	let defaultValue: Value

	let getter: () -> Value?
	let setter: (Value) -> Void

	var storage: Value {
		get {
			getter() ?? defaultValue
		}
		nonmutating set {
			setter(newValue)
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

	/// Updates  the enclosing ``ObservableState``’s ``StateObserver`` whenever the value is changed
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
			ReadOnlyProxy(
				get: {
					instance[keyPath: storageKeyPath].storage
				},
				updateHandler: { instance.addObserver(keyPath: storageKeyPath, handler: $0) }
			)
		}
	}
}

extension StoredValue {
	/// Initializes StoredValue property wrapping using a default value
	private init(defaultValue: Value, key: String, store: UserDefaults) {
		self.defaultValue = defaultValue
		getter = {
			store.object(forKey: key) as? Value
		}
		setter = { value in
			store.set(value, forKey: key)
		}
	}
	/// Creates a new StoredValue property wrapper for a Bool value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Bool {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an Int value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Int {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for a Double value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Double {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for a String value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == String {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for a URL value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == URL {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for a Data value
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Data {
		self.init(defaultValue: wrappedValue, key: key, store: store)
	}
}

extension StoredValue {
	/// Creates a new StoredValue property wrapper for a Set value, storing the value as an Array in the user defaults store
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init<Element>(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Set<Element> {
		self.init(
			defaultValue: wrappedValue,
			getter: {
				guard let array = store.object(forKey: key) as? [Element] else {
					return nil
				}
				return Set(array)
			},
			setter: { value in
				store.set(Array(value), forKey: key)
			}
		)
	}
}

extension StoredValue where Value: ExpressibleByNilLiteral {
	/// Initializes StoredValue property wrapping using a default optional value
	private init<WrappedValue>(key: String, store: UserDefaults) where Value == Optional<WrappedValue> {
		defaultValue = nil
		getter = {
			store.object(forKey: key) as? Value
		}
		setter = { value in
			if let value {
				store.set(value, forKey: key)
			} else {
				store.removeObject(forKey: key)
			}
		}
	}
	/// Creates a new StoredValue property wrapper for an optional Bool value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == Bool? {
		self.init(key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an optional Int value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == Int? {
		self.init(key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an optional Double value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == Double? {
		self.init(key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an optional String value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == String? {
		self.init(key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an optional URL value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == URL? {
		self.init(key: key, store: store)
	}
	/// Creates a new StoredValue property wrapper for an optional Data value
	/// - Parameters:
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init(_ key: String, store: UserDefaults = .standard) where Value == Data? {
		self.init(key: key, store: store)
	}
}

extension StoredValue {
	/// Creates a new StoredValue property wrapper for an optional Set value, storing the value as an Array in the user defaults store
	/// - Parameters:
	///   - wrappedValue: Default value when value not found in `UserDefaults`
	///   - key: Key to use to access `UserDefaults`
	///   - store: `UserDefaults` store to use
	public init<Element>(_ key: String, store: UserDefaults = .standard) where Value == Set<Element>? {
		self.init(
			defaultValue: nil,
			getter: {
				guard let array = store.object(forKey: key) as? [Element] else {
					return nil
				}
				return Set(array)
			},
			setter: { value in
				if let value {
					store.set(Array(value), forKey: key)
				} else {
					store.removeObject(forKey: key)
				}
			}
		)
	}
}
