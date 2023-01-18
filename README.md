# DidUpdate
> SwiftUI inspired State observing without SwiftUI

So, like `ObservableObject` but without any of that SwiftUI or Combine stuff

```swift
class ViewModel: ObservableState {
    @ObservedValue var name: String = "Hello"
}

class MyView: UIView {
    @ObservedState var viewModel = ViewModel()
    var observers: [StateValueObserver] = []
    
    func setupView() {
		let observer = $viewModel.name.didUpdate { [weak self] name in
			print("Name updated: \(name)")
		}.add(to: observers)
	}
}
```
