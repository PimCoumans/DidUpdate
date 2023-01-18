# DidUpdate
SwiftUI inspired State observing without SwiftUI

_So, like `ObservableObject` but without any of that SwiftUI or Combine stuff_

```swift
class MyView: UIView {
    class MyViewModel: ObservableState {
        @ObservedValue var username: String = "Hello"

        func clearUsername() { username = "" }
   }

    @ObservedState var viewModel = MyViewModel()
	var observers: [StateValueObserver] = []

    lazy var usernameLabel = UILabel()
    lazy var resetButton = UIButton(frame: .zero, primaryAction: UIAction { [unowned self] _ in
        viewModel.clearUsername()
    })

    func setupView() {
        // Add a update handler to be called when username is updated
        $viewModel.username.didUpdate { [weak self] name in
            self?.usernameLabel.text = name
        }.add(to: &observers)

        // Add a update handler when username.isEmpty has changed (using Equatable)
        $viewModel.username.didChange(
            comparing: \.isEmpty,  // KeyPath to value to compare 
            withCurrent: true      // Let closure be called with current value
        ) { [weak self] username in
            // Hide resetButton when username is empty
            self?.resetButton.isHidden = username.isEmpty
        }.add(to: &observers)
    }
}
```

## Installation
To add this dependency to your Xcode project, select File -> Add Package and enter this repository's URL: `https://github.com/PimCoumans/DidUpdate`

## But, why?
I love SwiftUI, but for now I feel more comfortable using plain old UIKit for the more complex parts of my apps. I **do** love how SwiftUI lets you define state and have it automatically update all your views when anything changes. I wanted _that_, but not with the overhead of importing SwiftUI or Combine and using a bunch of publishers, or learning a whole new reactive library.

So I reverse-over-engineered the parts I liked and introduced the ability to add update handlers to your bindings (`ObservedValue` in DidUpdate land).

Now you can have a tiny reactive-ish architecture for you UIKit views too!
