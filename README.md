# DidUpdate
SwiftUI inspired State observing without SwiftUI

> So, like `ObservableObject` but without any of that SwiftUI or Combine stuff

```swift
class ViewModel: ObservableState {
    @ObservedValue var username: String = "Hello"
    
    func clearUsername() {
        username = ""
    }
}

class MyView: UIView {
    @ObservedState var viewModel = ViewModel()
    
    var observers: [StateValueObserver] = []
    
    // Pass through values (like 'Binding')
    lazy var usernameLabel = UILabel()
    lazy var resetButton = UIButton(frame: .zero, primaryAction: UIAction { [unowned self] _ in
	    viewModel.clearUsername()
    })

    func setupView() {
        // Add a closure to be called when value is updated
        $viewModel.name.didUpdate { [weak self] name in
            self?.usernameLabel.text = name
        }.add(to: observers)
    }
}
```

## Installation
To add this dependency to your Xcode project, select File -> Add Package and enter this repository's URL: `https://github.com/PimCoumans/DidUpdate`
