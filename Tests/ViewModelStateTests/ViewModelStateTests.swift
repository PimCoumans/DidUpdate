import XCTest
import SwiftUI
import Combine
import ViewModelState

final class ViewModelStateTests: XCTestCase {

	class SomeViewModel: StateContainer {
		var calledFrameSetter: Bool = false
		var calledFrameDidChange: Bool = false

		@ViewState var frame: CGRect = .zero {
			didSet {
				calledFrameSetter = true
			}
		}
		@ViewState var array: [Int] = [0] {
			didSet {
				print("[ViewModel/Array] Updated: \(array)")
			}
		}

		var someString: String = "Nothing" {
			didSet {
				print("[ViewModel/someString] DidSet")
			}
		}

		var observers: [ViewStateObserver] = []
		init() {
			$frame.didChange { [unowned self] newValue in
				self.calledFrameDidChange = true
			}.add(to: &observers)
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

	func testStuff() {
		let view = SomeView()
		let subview = SomeSubview(frame: view.$viewModel.frame, cat: view.$viewModel.someString)
		let furtherView = SomeFurtherSubview(size: subview.$frame.size)

		view.$viewModel.frame.didChange(compareEqual: false) { newValue in
			print("[View/Frame] Updated: \(newValue)")
		}.add(to: &observers)
		view.$viewModel.frame.didChange { newValue in
			print("[View/Frame] Changed: \(newValue)")
		}.add(to: &observers)
		view.$viewModel.frame.size.didChange { newValue in
			print("[View/Frame.Size] didChange: \(newValue)")
		}.add(to: &observers)
		view.$viewModel.frame.didChange(comparing: \.size) { newValue in
			print("[View/Frame] (\\.size) didChange: \(newValue)")
		}.add(to: &observers)
		subview.$frame.didChange { newValue in
			print("[SubView/Frame] didChange: \(newValue)")
		}.add(to: &observers)
		furtherView.$size.didChange { newValue in
			print("[FurtherView/Size] didChange: \(newValue)")
		}.add(to: &observers)

		view.viewModel.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
		view.viewModel.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
		view.viewModel.frame.size = CGSize(width: 5, height: 6)
		view.viewModel.frame.size = CGSize(width: 5, height: 6)

		furtherView.size = CGSize(width: 7, height: 8)
	}

	func testViewStateObserver() {
		let view = SomeView()
		let subview = SomeSubview(frame: view.$viewModel.frame, cat: view.$viewModel.someString)
		let furtherView = SomeFurtherSubview(size: subview.$frame.size)

		view.$viewModel.frame.didChange { newValue in
			print("[ViewModel/Frame] DidChange: \(newValue)")
		}.add(to: &observers)
		view.viewModel.$frame.didChange { newValue in
			print("[ViewModel/$Frame] DidChange: \(newValue)")
		}.add(to: &observers)
		view.viewModel.$frame.size.didChange { newValue in
			print("[ViewModel/$Frame.size] DidChange: \(newValue)")
		}.add(to: &observers)
		view.viewModel.frame = CGRect(x: 1, y: 2, width: 3, height: 4)
	}

	class SomeObject: ObservableObject {
		@Published var frame: CGRect = .zero {
			didSet {
				print("FRAME CHANGED: \(frame)")
			}
		}
		var toes: String = "Cute!" { didSet {
			print("MIAOW")
		}}
	}

	class SwiftUIView {
		@ObservedObject var viewModel = SomeObject()
	}

	class OtherSwiftUIView {
		@Binding var size: CGSize
		@Binding var cat: String
		init(cat: Binding<String>, size: Binding<CGSize>) {
			_size = size
			_cat = cat
		}
	}

	var cancellables: [AnyCancellable] = []

	func testSwiftUIExample() throws {
		let view = SwiftUIView()
		view.viewModel.$frame.sink { frame in
			print("Publisher: \(frame)")
		}.store(in: &cancellables)
		let otherView = OtherSwiftUIView(cat: view.$viewModel.toes, size: view.$viewModel.frame.size)
		otherView.size.width = 20
		otherView.cat = "zo cute!"
	}
}
