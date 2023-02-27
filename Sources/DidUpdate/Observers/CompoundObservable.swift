//
//  CompoundObservable.swift
//  
//
//  Created by Pim on 24/02/2023.
//

import Foundation

extension UpdateObservable {
	fileprivate var value: Value {
		var value: Value?
		_ = didUpdate(withCurrent: true) { currentValue in
			value = currentValue
		}
		return value!
	}
}
/// Experimental: create an observer for multiple values
public struct CompoundObservable<Observables>: UpdateObservable {
	public typealias Value = Observables

	let isEquatable: Bool
	let valueProvider: () -> Observables
	var observables: [any UpdateObservable] = []

	init(observables: [any UpdateObservable], provider: @escaping @autoclosure () -> Observables) {
		self.valueProvider = provider
		self.observables = observables
		isEquatable = observables.allSatisfy { $0.self is any Equatable }
	}

	public init<A, B>(_ a: A, _ b: B) where A: UpdateObservable, B: UpdateObservable, Value == (A.Value, B.Value) {
		self.init(observables: [a, b], provider: (a.value, b.value))
	}

	public init<A, B, C>(_ a: A, _ b: B, _ c: C) where A: UpdateObservable, B: UpdateObservable, C: UpdateObservable, Value == (A.Value, B.Value, C.Value) {
		self.init(observables: [a, b, c], provider: (a.value, b.value, c.value))
	}

	public init<A, B, C, D>(_ a: A, _ b: B, _ c: C, _ d: D) where A: UpdateObservable, B: UpdateObservable, C: UpdateObservable, D: UpdateObservable, Value == (A.Value, B.Value, C.Value, D.Value) {
		self.init(observables: [a, b, c, d], provider: (a.value, b.value, c.value, d.value))
	}

	public func addUpdateHandler(_ handler: DidUpdate.UpdateHandler<Observables>) -> Observer {
		var observers: [StateValueObserver] = []
		for observer in observables {
			observer.didUpdate { oldValue, newValue, isCurrent in
				let values = valueProvider()
				handler.handle(update: .updated(old: values, new: values))
			}.add(to: &observers)
		}
		let observer = StateObserver.Observer(keyPath: \CompoundObservable.value, handler: handler)
		observer.onRelease = { _ in
			observers.removeAll()
		}
		return StateValueObserver(observer)
	}
}
