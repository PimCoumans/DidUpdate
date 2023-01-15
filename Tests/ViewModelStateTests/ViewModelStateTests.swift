import XCTest
import SwiftUI
import Combine
import ViewModelState

final class ViewModelStateTests: XCTestCase {

	class SomeViewModel: StateContainer {
		@ViewState var frame: CGRect = .zero {
			didSet {
				print("ViewModel DidSet called: \(frame)")
			}
		}
		@ViewState var toesje: String = "Lief" {
			didSet {
				print("MIAOW: \(toesje)")
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

    func testExample() throws {

		let view = SomeView()
		let subview = SomeSubview(frame: view.$viewModel.frame, cat: view.$viewModel.toesje)
		let furtherSubview = SomeFurtherSubview(size: subview.$frame.size)
		view.$viewModel.frame.didChange { old, new, _ in
			print("View frame handler called: \(old), \(new)")
		}.add(to: &observers)
		subview.cat = "ZO CUTE, OMG!"
		subview.$frame.didChange { old, new, _ in
			print("Subview frame handler called: \(old), \(new)")
		}.add(to: &observers)
		subview.$frame.didChange(comparing: \.size.width) { oldValue, newValue, isInitial in
			print("Width changed!")
		}.add(to: &observers)
		furtherSubview.$size.didChange { old, new, _ in
			print("Further size handler called: \(old), \(new)")
		}.add(to: &observers)

		view.$viewModel.toesje.didChange { oldValue, newValue, isInitial in
			print("TOESJE: \(newValue)")
		}.add(to: &observers)
		view.viewModel.observableValues.frame.didChange { newValue in
			print("value: \(newValue)")
		}.add(to: &observers)

		print(1)
		print(view.viewModel.frame)
		print(subview.frame)
		print(furtherSubview.size)

		print(2)
		view.viewModel.frame.size = CGSize(width: 20, height: 40)

		print(3)
		print(view.viewModel.frame)
		print(subview.frame)
		print(furtherSubview.size)

		print(4)
		subview.frame.size = CGSize(width: 20, height: 69)

		print(5)
		print(view.viewModel.frame)
		print(subview.frame)
		print(furtherSubview.size)

		print(6)
		furtherSubview.size = CGSize(width: 13, height: 777)

		print(7)
		print(view.viewModel.frame)
		print(subview.frame)
		print(furtherSubview.size)

		print(8)
		view.viewModel.frame.size = CGSize(width: 13, height: 777)
		view.viewModel.frame = CGRect(x: 1, y: 2, width: 3, height: 4)

		print(9)
		view.viewModel.toesje = "MIAOW"

		print(10)

		observers.removeAll()

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
