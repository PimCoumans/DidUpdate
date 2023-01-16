import Foundation

/// Adds a change observer to your model class, allowing subscriptions to changes in values annotated with `@ViewState`.
/// See the ``ViewModel`` property wrapper for more info.
public protocol StateContainer: AnyObject {
	/// Observer updated from `@ViewState` property wrappers
	var changeObserver: StateContainerObserver { get }
}

private var changeObserverKey = "updateHandler"
public extension StateContainer {
	private func newHandler() -> StateContainerObserver { .init() }

	var changeObserver: StateContainerObserver {
		if let handler = objc_getAssociatedObject(self, &changeObserverKey) as? StateContainerObserver {
			return handler
		}
		let handler = newHandler()
		objc_setAssociatedObject(self, &changeObserverKey, handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		return handler
	}
}
