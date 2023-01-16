import XCTest
import SwiftUI
import Combine
import ViewModelState

final class ViewModelStateTests: XCTestCase {

	class SomeViewModel: StateContainer {

		struct ViewModelProperty {
			var string: String = "SomeString"
			var optional: Int? = nil

			var computed: String {
				string.appending(String(describing: optional))
			}
		}

		var calledFrameDidSet: Bool = false
		var calledFrameChangeHandler: Bool = false
		@ViewState var frame: CGRect = .zero { didSet {
			calledFrameDidSet = true
		}}

		var calledArrayDidSet: Bool = false
		var calledArrayChangeHandler: Bool = false
		@ViewState var array: [Int] = [0] { didSet {
			calledArrayDidSet = true
		}}

		var calledOptionalDidSet: Bool = false
		var calledOptionalDidChangeHandler: Bool = false
		var calledOptionalComparingDidChangeHandler: Bool = false
		@ViewState var optional: CGRect? { didSet {
			calledOptionalDidSet = true
		}}

		var calledStructDidSet: Bool = false
		var calledStructDidChangeHandler: Bool = false
		var calledStructComputedDidChangeHandler: Bool = false
		@ViewState var structProperty = ViewModelProperty() { didSet {
			calledStructDidSet = true
		}}

		var observers: [ViewStateObserver] = []
		init() {
			observers.add {
				$frame.size.width.description.count.didChange { [unowned self] newValue in
					self.calledArrayChangeHandler = true
				}
				$optional.didChange { [unowned self] newValue in
					self.calledOptionalDidChangeHandler = true
				}
				$optional.didChange(comparing: \.width) { [unowned self] newValue in
					self.calledOptionalComparingDidChangeHandler = true
				}

				$structProperty.didChange { [unowned self] newValue in
					self.calledStructDidSet = true
				}
				$structProperty.computed.didChange { [unowned self] newValue in
					self.calledStructComputedDidChangeHandler = true
				}
			}

		}
	}

	class SomeView {
		@ViewModel var viewModel: SomeViewModel = SomeViewModel()
	}

	class SomeSubview {
		@ValueProxy var frame: CGRect
		@ValueProxy var cat: String
		init(frame: ValueProxy<CGRect>, cat: ValueProxy<String>) {
			self._frame = frame
			self._cat = cat
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
		view.viewModel.$optional.didChange(comparing: \.width) { newValue in
			print("Width changed: \(String(describing: newValue?.width))")
		}.add(to: &observers)
		view.viewModel.optional?.size.width = 2
		view.viewModel.optional = .zero
		view.viewModel.optional?.origin.y = 20
		view.viewModel.optional = nil
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
