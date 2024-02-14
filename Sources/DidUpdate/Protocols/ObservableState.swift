import Foundation

/// Adds an update observer to your model class, allowing subscriptions to update in values annotated with `@ObservedValue`.
/// See the ``ObservedState`` property wrapper for more info.
public protocol ObservableState: AnyObject {
	/// Observer updated from `@ViewState` property wrappers
	var stateObserver: StateObserver { get }
}

/// Creates `ValueProxy` structs to forward getting and setting of values and allow adding observers for specific keyPaths
@dynamicMemberLookup
public struct ObservableValues<StateObject: ObservableState> {
	fileprivate var stateObject: () -> StateObject
	fileprivate init(observing: @autoclosure @escaping () -> StateObject) {
		self.stateObject = observing
	}

	public subscript<Value>(
		dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
	) -> ValueProxy<Value> {
		stateObject().valueProxy(from: keyPath)
	}

	@_disfavoredOverload
	public subscript<Value>(
		dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
	) -> WeakValueProxy<Value> {
		stateObject().weakValueProxy(from: keyPath)
	}

	@_disfavoredOverload
	public subscript<Value>(
		dynamicMember keyPath: KeyPath<StateObject, Value>
	) -> ReadOnlyProxy<Value> {
		stateObject().readOnlyProxy(from: keyPath)
	}
}

extension ObservableValues {
	/// Creates `WeakValueProxy` structs to forward getting and setting of values and allow adding observers for specific keyPaths without strongly retaining the source object
	@dynamicMemberLookup
	public struct WeakValues {
		fileprivate var stateObject: () -> StateObject
		fileprivate init(observing: @autoclosure @escaping () -> StateObject) {
			self.stateObject = observing
		}

		public subscript<Value>(
			dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
		) -> WeakValueProxy<Value> {
			stateObject().weakValueProxy(from: keyPath)
		}
	}
	
	/// Creates value proxies that don’t retain the source object so these can be passed through and stored by objects retained by your `ObservableState` class.
	public var weak: WeakValues {
		WeakValues(observing: stateObject())
	}
}

private let key = malloc(1)!

extension ObservableState {
	public var stateObserver: StateObserver {
		guard let observer = objc_getAssociatedObject(self, key) as? StateObserver else {
			let observer = StateObserver()
			objc_setAssociatedObject(self, key, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			return observer
		}
		return observer
	}

	/// Wrapper to create local proxies using dynamic member subscripts
	/// - Returns: ``ObservableValues`` struct pointing to wrapping self
	/// - Note: Be mindful of retain cycles when passing a `ValueProxy` to an object retained by this class, as these proxies strongly capture `self`.
	/// Start your dynamic member lookup with `.weak` to create a `WeakValueProxy` to prevent this issue (`observableValues.weak.yourProperty`)
	public var observableValues: ObservableValues<Self> {
		ObservableValues(observing: self)
	}

	fileprivate func valueProxy<Value>(from keyPath: ReferenceWritableKeyPath<Self, Value>) -> ValueProxy<Value> {
		ValueProxy {
			self[keyPath: keyPath]
		} set: { newValue in
			self[keyPath: keyPath] = newValue
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}

	fileprivate func readOnlyProxy<Value>(from keyPath: KeyPath<Self, Value>) -> ReadOnlyProxy<Value> {
		ReadOnlyProxy {
			self[keyPath: keyPath]
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}

	fileprivate func weakValueProxy<Value>(from keyPath: ReferenceWritableKeyPath<Self, Value>) -> WeakValueProxy<Value> {
		WeakValueProxy(
			currentValue: self[keyPath: keyPath],
			get: { [weak self] in
				self?[keyPath: keyPath]
			},
			set: { [weak self] newValue in
				self?[keyPath: keyPath] = newValue
			},
			updateHandler: { [weak self] handler in
				self?.addObserver(keyPath: keyPath, handler: handler)
			}
		)
	}
}
