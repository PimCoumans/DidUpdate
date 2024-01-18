import Foundation

/// Prevents `didUpdate/didChange` callbacks whenever the `ValueProxy` was updated directly through the property wrapper.
/// In cases where a `ValueProxy` both reports back *and* acts on value changes, the update handlers of the proxy should be ignored when local state
/// is manually updated. The `ExternallyUpdating` property wrapper ignores any incoming updates when the value is updated directly and
/// allows any other updates to come through.
@propertyWrapper @dynamicMemberLookup
public struct ExternallyUpdating<Value>: UpdateObservable {

	private class ProxyStorage {
		let proxy: ValueProxy<Value>
		var isUpdating: Bool = false
		init(valueProxy: ValueProxy<Value>) {
			self.proxy = valueProxy
		}

		var value: Value {
			get { proxy.get() }
			set {
				isUpdating = true
				proxy.set(newValue)
				isUpdating = false
			}
		}
	}

	private let storage: ProxyStorage

	public var wrappedValue: Value {
		get { storage.value }
		set { storage.value = newValue }
	}

	public init(valueProxy: ValueProxy<Value>) {
		storage = ProxyStorage(valueProxy: valueProxy)
	}

	public var projectedValue: ExternallyUpdating<Value> { self }

	public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> ExternallyUpdating<Subject> {
		ExternallyUpdating<Subject>(valueProxy: ValueProxy(storage.proxy, keyPath: keyPath))
	}

	@_disfavoredOverload
	public subscript<Subject>(dynamicMember keyPath: KeyPath<Value, Subject>) -> ReadOnlyProxy<Subject> {
		ReadOnlyProxy(storage.proxy, keyPath: keyPath)
	}
}

extension ExternallyUpdating {

	public var currentValue: Value {
		wrappedValue
	}
	
	public func addUpdateHandler(_ handler: UpdateHandler<Value>) -> Observer {
		let localHandler = UpdateHandler(
			updateWithCurrentValue: handler.updateWithCurrentValue,
			shouldHandleUpdate: { _ in !storage.isUpdating },
			handler: { handler.handle(update: $0) }
		)
		return storage.proxy.addUpdateHandler(localHandler)
	}

	public func map<MappedValue>(_ transform: @escaping (Value) -> MappedValue) -> ReadOnlyProxy<MappedValue> {
		ReadOnlyProxy<MappedValue>(
			get: { transform(wrappedValue) },
			updateHandler: { update in
				storage.proxy.updateHandler(update.mapped(using: transform))
			}
		)
	}
}
