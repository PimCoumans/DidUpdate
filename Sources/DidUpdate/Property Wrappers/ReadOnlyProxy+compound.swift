import Foundation

extension ReadOnlyProxy {
	/// Combines two observables into one single ``ReadOnlyProxy`` with  a tuple of both values
	/// - Returns: New `ReadOnlyProxy` to use for handling updates or changes to any of the combined values
	public static func compound<A: UpdateObservable, B: UpdateObservable>(
		_ a: A, _ b: B
	) -> Self where Value == (A.Value, B.Value) {
		proxy(from: [a, b], getter: { (a.currentValue, b.currentValue) })
	}

	/// Combines three observables into one single ``ReadOnlyProxy`` with  a tuple of all values
	/// - Returns: New `ReadOnlyProxy` to use for handling updates or changes to any of the combined values
	public static func compound<A: UpdateObservable, B: UpdateObservable, C: UpdateObservable>(
		_ a: A, _ b: B, _ c: C
	) -> Self where Value == (A.Value, B.Value, C.Value) {
		proxy(from: [a, b, c], getter: { (a.currentValue, b.currentValue, c.currentValue) })
	}

	/// Combines four observables into one single ``ReadOnlyProxy`` with  a tuple of all values
	/// - Returns: New `ReadOnlyProxy` to use for handling updates or changes to any of the combined values
	public static func compound<A: UpdateObservable, B: UpdateObservable, C: UpdateObservable, D: UpdateObservable>(
		_ a: A, _ b: B, _ c: C, _ d: D
	) -> Self where Value == (A.Value, B.Value, C.Value, D.Value) {
		proxy(from: [a, b, c, d], getter: { (a.currentValue, b.currentValue, c.currentValue, d.currentValue) })
	}
}

extension ReadOnlyProxy {
	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	public func didChange<A: Equatable, B: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer where Value == (A, B) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	public func didChange<A: Equatable, B: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping FullDidUpdateHandler
	) -> Observer where Value == (A, B) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	public func didChange<A: Equatable, B: Equatable, C: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer where Value == (A, B, C) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	public func didChange<A: Equatable, B: Equatable, C: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping FullDidUpdateHandler
	) -> Observer where Value == (A, B, C) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing just the new value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	public func didChange<A: Equatable, B: Equatable, C: Equatable, D: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping DidUpdateHandler
	) -> Observer where Value == (A, B, C, D) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}

	/// Adds an update handler called whenever the observed value has changed, comparing old and new value
	/// - Parameters:
	///   - provideCurrent: Whether the provided closure should be called immediately with the current value
	///   - handler: Closure executed containing the old and new value, and whether the closure was called with the current value
	/// - Returns: Opaque class storing the observation, making sure the closure isn't called when deallocated
	public func didChange<A: Equatable, B: Equatable, C: Equatable, D: Equatable>(
		withCurrent provideCurrent: Bool = false,
		handler: @escaping FullDidUpdateHandler
	) -> Observer where Value == (A, B, C, D) {
		addUpdateHandler(.init(
			shouldHandleUpdate: { $0.hasChangedValue(comparing: { $0 != $1 }) },
			updateWithCurrent: provideCurrent,
			handler: handler
		))
	}
}

extension ReadOnlyProxy {
	private static func proxy(
		from proxies: [any UpdateObservable],
		getter: @escaping () -> Value
	) -> ReadOnlyProxy {
		var previousValue = getter()
		var wasInitial: Bool = true
		return ReadOnlyProxy(
			get: getter,
			updateHandler: { handler in
				let observers = proxies.map {
					$0.didUpdate(withCurrent: handler.updateWithCurrentValue, handler: { _, _, isInitialUpdate in
						let newValue = getter()
						if isInitialUpdate && wasInitial {
							handler.handle(update: .current(value: newValue))
							wasInitial = false
						} else {
							handler.handle(update: .updated(old: previousValue, new: newValue))
						}
						previousValue = newValue
					})
				}
				return StateValueObserver(observers)
			}
		)
	}
}