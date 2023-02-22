import Foundation

/// Adds an update observer to your model class, allowing subscriptions to update in values annotated with `@ObservedValue`.
/// See the ``ObservedState`` property wrapper for more info.
public protocol ObservableState: AnyObject {
	/// Observer updated from `@ViewState` property wrappers
	var stateObserver: StateObserver { get }
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
	/// - Returns: ``ObservedState/ObservableValues`` struct pointing to self
	var valueProxies: ObservedState<Self>.ObservableValues {
		ObservedState<Self>.ObservableValues(observing: self)
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
}
