import XCTest
import DidUpdate

class BooleanContainer {
	var value: Bool = false
	func expect(_ expectedValue: Bool, operation: () -> Void) {
		value = false
		operation()
		XCTAssertEqual(value, expectedValue, "⚠️ Boolean after operation not of expected value")
	}
}

final class ViewModelStateTests: XCTestCase {

	class SomeViewModel: ObservableState {

		struct ViewModelProperty {
			var string: String = "SomeString"
			var optional: Int? = nil

			var computed: String {
				string.appending(String(describing: optional))
			}
		}

		let frameBoolean = BooleanContainer()
		@ObservedValue var frame: CGRect = .zero { didSet {
			frameBoolean.value = true
		}}

		let arrayBoolean = BooleanContainer()
		@ObservedValue var array: [Int] = [0] { didSet {
			arrayBoolean.value = true
		}}

		let optionalBoolean = BooleanContainer()
		@ObservedValue var optional: CGRect? { didSet {
			optionalBoolean.value = true
		}}

		let structBoolean = BooleanContainer()
		@ObservedValue var structProperty = ViewModelProperty() { didSet {
			structBoolean.value = true
		}}

		@StoredValue("StoredProperty") var storedProperty: Bool = false
		@StoredValue("OptionalStoredProperty") var optionalStoredProperty: String?
	}

	class SomeView {
		@ObservedState var viewModel: SomeViewModel = SomeViewModel()
		func createSubview() -> SomeSubview {
			SomeSubview(frame: $viewModel.frame, array: $viewModel.array, optionalFrame: $viewModel.optional)
		}
	}

	class SomeSubview {
		let frameBoolean = BooleanContainer()
		@ValueProxy var frame: CGRect
		let arrayBoolean = BooleanContainer()
		@ValueProxy var array: [Int]
		let optionalBoolean = BooleanContainer()
		@ValueProxy var optional: CGRect?

		var observers: [StateValueObserver] = []
		init(frame: ValueProxy<CGRect>, array: ValueProxy<[Int]>, optionalFrame: ValueProxy<CGRect?>) {
			self._frame = frame
			self._array = array
			self._optional = optionalFrame

			observers.add {
				$frame.didChange { [weak self] newValue in
					self?.frameBoolean.value = true
				}
				$array.didChange { [weak self] newValue in
					self?.arrayBoolean.value = true
				}
				$optional.didChange { [weak self] newValue in
					self?.optionalBoolean.value = true
				}
			}

		}
		func createSubview() -> SomeFurtherSubview {
			SomeFurtherSubview(size: $frame.size)
		}
	}

	class SomeFurtherSubview {
		@ValueProxy var size: CGSize
		init(size: ValueProxy<CGSize>) {
			self._size = size
		}
	}

	func testOptionalObserving() {
		let view = SomeView()
		let bool = BooleanContainer()

		let observer = view.$viewModel.optional.didChange(comparing: \.width) { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning

		bool.expect(false) { view.viewModel.optional?.size.width = 2 }
		bool.expect(true) { view.viewModel.optional = .zero }
		bool.expect(true) { view.viewModel.optional?.size.width = 2 }
		bool.expect(false) { view.viewModel.optional?.size.width = 2 }
		bool.expect(true) { view.viewModel.optional = nil }
	}

	func testUpdateHandlers() {
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero
		let basicFrame = CGRect(x: 1, y: 2, width: 3, height: 4)

		// Reuse same observer variable so active observer gets replaced
		var observer = view.$viewModel.frame.didChange { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning
		// Update called when frame actually changed
		bool.expect(true) { view.viewModel.frame = basicFrame }
		// But not when set to the same value
		bool.expect(false) { view.viewModel.frame = basicFrame }

		observer = view.$viewModel.frame.didUpdate(handler: { newValue in
			bool.value = true
		})
		// Update called when set to the same value
		bool.expect(true) { view.viewModel.frame = basicFrame }
		observer = view.$viewModel.frame.didChange(comparing: \.width, { newValue in
			bool.value = true
		})
		// Update not called when origin is updated
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
		// Update called when width is updated
		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		// Update called immediately with current value
		bool.expect(true) {
			observer = view.$viewModel.frame.didChange(withCurrent: true, handler: { newValue in
				bool.value = true
			})
		}
	}

	func testStateValueObservers() {
		// Same as above but using projected value of `@ObservedValue` property wrappers
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero
		let basicFrame = CGRect(x: 1, y: 2, width: 3, height: 4)

		// Reuse same observer variable so active observer gets replaced
		var observer = view.viewModel.$frame.didChange { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning
		// Update called when frame actually changed
		bool.expect(true) { view.viewModel.frame = basicFrame }
		// But not when set to the same value
		bool.expect(false) { view.viewModel.frame = basicFrame }

		observer = view.viewModel.$frame.didUpdate(handler: { newValue in
			bool.value = true
		})
		// Update called when set to the same value
		bool.expect(true) { view.viewModel.frame = basicFrame }
		observer = view.viewModel.$frame.didChange(comparing: \.width, { newValue in
			bool.value = true
		})
		// Update not called when origin is updated
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
		// Update called when width is updated
		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		// Update called immediately with current value
		bool.expect(true) {
			observer = view.viewModel.$frame.didChange(withCurrent: true, handler: { newValue in
				bool.value = true
			})
		}
	}

	func testMapping() {
		// Test functionality of mapping proxies
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero

		let observer = view.$viewModel.frame.map(\.width).didChange { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning
		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		bool.expect(false) { view.viewModel.frame.size.height = 20 }
	}

	func testCompoundProxies() {
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero

		let observer = ReadOnlyProxy.compound(
			view.$viewModel.frame.width,
			view.$viewModel.frame.height
		).didChange { width, height in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning

		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		bool.expect(false) { view.viewModel.frame.size.width = 20 }
		bool.expect(true) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
	}

	func testWeakCompoundProxies() {
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero

		let observer = ReadOnlyProxy.compound(
			view.viewModel.observableValues.weak.frame.map { $0.width },
			view.viewModel.observableValues.weak.frame.height
		).didChange { width, height in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning

		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		bool.expect(false) { view.viewModel.frame.size.width = 20 }
		bool.expect(true) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
	}

	func testNestedMaps() {
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero

		let testSize: CGFloat = 10

		let widthBigger = view.$viewModel.frame.width.map { $0 > testSize }
		let heightBigger = view.$viewModel.frame.height.map { $0 > testSize }
		let leftBigger = view.$viewModel.frame.minX.map { $0 > testSize }
		let topBigger = view.$viewModel.frame.minY.map { $0 > testSize }

		let sizeBigger = ReadOnlyProxy.compound(
			widthBigger,
			heightBigger
		).map { $0 || $1 }

		let frameBigger = ReadOnlyProxy.compound(
			sizeBigger,
			leftBigger,
			topBigger
		).map { $0 || $1 || $2 }

		let someOtherThing = ReadOnlyProxy.compound(
			frameBigger,
			view.$viewModel.optional.map { $0 != nil }
		).map { $0 || $1 }

		let observer = someOtherThing.didChange { _ in
			bool.value = true
		}

		_ = observer

		bool.expect(true, operation: { view.viewModel.frame.size.width = 12 })
		bool.expect(false, operation: { view.viewModel.frame.size.height = 11 })
		bool.expect(false, operation: { view.viewModel.frame.size.width = 5 })
		bool.expect(true, operation: { view.viewModel.frame.size.height = 2 })
		bool.expect(true, operation: { view.viewModel.optional = .zero })
		bool.expect(false, operation: { view.viewModel.frame.size.height = 20 })
	}

	func testStoredValues() {
		let view = SomeView()
		let bool = BooleanContainer()

		let defaults = UserDefaults.standard
		defaults.removeObject(forKey: "StoredProperty")
		defaults.removeObject(forKey: "OptionalStoredProperty")

		var observer = view.$viewModel.storedProperty.didChange { newValue in
			bool.value = true
		}
		_ = observer

		bool.expect(false) { view.viewModel.storedProperty = false }
		bool.expect(true) { view.viewModel.storedProperty = true }

		observer = view.$viewModel.optionalStoredProperty.didChange { newValue in
			bool.value = true
		}

		bool.expect(false) { view.viewModel.optionalStoredProperty = nil }
		bool.expect(true) { view.viewModel.optionalStoredProperty = "someString" }
	}

	func testStoredCompoundProxy() {
		let view = SomeView()
		let bool = BooleanContainer()
		let secondBool = BooleanContainer()
		view.viewModel.frame = .zero

		let compoundProxy = ReadOnlyProxy.compound(
			view.$viewModel.frame.width,
			view.$viewModel.frame.height
		)
		let observer = compoundProxy.didChange { width, height in
			bool.value = true
		}
		let secondObserver = compoundProxy.didChange { width, height in
			secondBool.value = true
		}
		_ = (observer, secondObserver) // hush little 'never read' warning

		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		bool.expect(false) { view.viewModel.frame.size.width = 20 }
		bool.expect(true) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.size.height = 20 }
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }

		secondBool.expect(true) { view.viewModel.frame.size.width = 30 }
		secondBool.expect(true) { view.viewModel.frame.size.height = 30 }
		secondBool.expect(false) { view.viewModel.frame.size.height = 30 }
	}
}
