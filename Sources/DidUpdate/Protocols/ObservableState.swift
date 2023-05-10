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
	public init(observing: @autoclosure @escaping () -> StateObject) {
		self.stateObject = observing
	}

	public subscript<Value>(
		dynamicMember keyPath: ReferenceWritableKeyPath<StateObject, Value>
	) -> ValueProxy<Value> {
		stateObject().valueProxy(from: keyPath)
	}

	@_disfavoredOverload
	public subscript<Value>(
		dynamicMember keyPath: KeyPath<StateObject, Value>
	) -> ReadOnlyProxy<Value> {
		stateObject().readonlyProxy(from: keyPath)
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
	public var observableValues: ObservableValues<Self> {
		ObservableValues(observing: self)
	}

	func valueProxy<Value>(from keyPath: ReferenceWritableKeyPath<Self, Value>) -> ValueProxy<Value> {
		ValueProxy {
			self[keyPath: keyPath]
		} set: { newValue in
			self[keyPath: keyPath] = newValue
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}

	func readonlyProxy<Value>(from keyPath: KeyPath<Self, Value>) -> ReadOnlyProxy<Value> {
		ReadOnlyProxy {
			self[keyPath: keyPath]
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}
}
