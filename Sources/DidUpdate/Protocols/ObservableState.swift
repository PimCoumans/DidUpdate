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

private var stateObserverKey = "ObservableStateObserver"
public extension ObservableState {
	private func newObserver() -> StateObserver { .init() }

	var stateObserver: StateObserver {
		if let handler = objc_getAssociatedObject(self, &stateObserverKey) as? StateObserver {
			return handler
		}
		let handler = newObserver()
		objc_setAssociatedObject(self, &stateObserverKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return handler
	}

	/// Wrapper to create local proxies using dynamic member subscripts
	/// - Returns: ``ObservableValues`` struct pointing to wrapping self
	var observableValues: ObservableValues<Self> {
		ObservableValues(observing: self)
	}

	internal func valueProxy<Value>(from keyPath: ReferenceWritableKeyPath<Self, Value>) -> ValueProxy<Value> {
		ValueProxy {
			self[keyPath: keyPath]
		} set: { newValue in
			self[keyPath: keyPath] = newValue
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}

	internal func readonlyProxy<Value>(from keyPath: KeyPath<Self, Value>) -> ReadOnlyProxy<Value> {
		ReadOnlyProxy {
			self[keyPath: keyPath]
		} updateHandler: { handler in
			self.addObserver(keyPath: keyPath, handler: handler)
		}
	}
}
