import XCTest
import SwiftUI
import Combine
import ViewModelState

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

		var observers: [ViewStateObserver] = []
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

	var observers: [ViewStateObserver] = []

	func testOptionalObserving() {
		let view = SomeView()
		let bool = BooleanContainer()

		view.$viewModel.optional.didChange(comparing: \.width) { newValue in
			bool.value = true
		}.add(to: &observers)

		bool.expect(false) { view.viewModel.optional?.size.width = 2 }
		bool.expect(true) { view.viewModel.optional = .zero }
		bool.expect(true) { view.viewModel.optional?.size.width = 2 }
		bool.expect(false) { view.viewModel.optional?.size.width = 2 }
		bool.expect(true) { view.viewModel.optional = nil }
		observers.removeAll()
	}

	func testDidChangeHandler() {
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero
		let basicFrame = CGRect(x: 1, y: 2, width: 3, height: 4)

		// Reuse same observer variable so active observer gets replaced
		var observer = view.$viewModel.frame.didChange { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning
		// Changed called when frame actually changed
		bool.expect(true) { view.viewModel.frame = basicFrame }
		// But not when set to the same value
		bool.expect(false) { view.viewModel.frame = basicFrame }

		observer = view.$viewModel.frame.didChange(compareEqual: false, handler: { newValue in
			bool.value = true
		})
		// Change called when set to the same value
		bool.expect(true) { view.viewModel.frame = basicFrame }
		observer = view.$viewModel.frame.didChange(comparing: \.width, { newValue in
			bool.value = true
		})
		// Change not called when origin is updated
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
		// Change called when width is updated
		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		// Change called immediately with current value
		bool.expect(true) {
			observer = view.$viewModel.frame.didChange(withCurrent: true, handler: { newValue in
				bool.value = true
			})
		}
	}

	func testStateValueObservers() {
		// Same as above but using projected value of `@StateValue` property wrappers
		let view = SomeView()
		let bool = BooleanContainer()
		view.viewModel.frame = .zero
		let basicFrame = CGRect(x: 1, y: 2, width: 3, height: 4)

		// Reuse same observer variable so active observer gets replaced
		var observer = view.viewModel.$frame.didChange { newValue in
			bool.value = true
		}
		_ = observer // hush little 'never read' warning
		// Changed called when frame actually changed
		bool.expect(true) { view.viewModel.frame = basicFrame }
		// But not when set to the same value
		bool.expect(false) { view.viewModel.frame = basicFrame }

		observer = view.viewModel.$frame.didChange(compareEqual: false, handler: { newValue in
			bool.value = true
		})
		// Change called when set to the same value
		bool.expect(true) { view.viewModel.frame = basicFrame }
		observer = view.viewModel.$frame.didChange(comparing: \.width, { newValue in
			bool.value = true
		})
		// Change not called when origin is updated
		bool.expect(false) { view.viewModel.frame.origin.x = 20 }
		// Change called when width is updated
		bool.expect(true) { view.viewModel.frame.size.width = 20 }
		// Change called immediately with current value
		bool.expect(true) {
			observer = view.viewModel.$frame.didChange(withCurrent: true, handler: { newValue in
				bool.value = true
			})
		}
	}

	class SomeObject: ObservableObject {
		@Published var frame: CGRect = .zero {
			didSet {
				print("FRAME CHANGED: \(frame)")
			}
		}
		@Published var optionalFrame: CGRect? = nil { didSet {
			print("Optional frame changed: \(String(describing: optionalFrame))")
		}}
	}

	class SwiftUIView {
		@ObservedObject var viewModel = SomeObject()
	}

	class OtherSwiftUIView {
		@Binding var size: CGSize
		@Binding var frame: CGRect?
		init(size: Binding<CGSize>, frame: Binding<CGRect?>) {
			_size = size
			_frame = frame
		}
	}

	var cancellables: [AnyCancellable] = []

	func testSwiftUIExample() throws {
		let view = SwiftUIView()
		view.viewModel.$frame.sink { frame in
			print("Frame publisher: \(frame)")
		}.store(in: &cancellables)

		view.viewModel.$optionalFrame.sink { frame in
			print("Optional frame publisher: \(String(describing: frame))")
		}.store(in: &cancellables)
		let otherView = OtherSwiftUIView(size: view.$viewModel.frame.size, frame: view.$viewModel.optionalFrame)
		otherView.size.width = 20
		otherView.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
	}
}
