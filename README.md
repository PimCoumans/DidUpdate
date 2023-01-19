# DidUpdate
SwiftUI inspired state observing without SwiftUI

_So, like `ObservableObject` but without any of that SwiftUI or Combine stuff_

```swift
class MyView: UIView {
    /// Conform your model classes to `ObservableState`
    class ViewModel: ObservableState {
        /// Use `ObservedValue` for your model's properties
        @ObservedValue var count: Int = 0
    }

    class StepperView: UIView {
        /// Store passed through bindings with `ValueProxy`
        @ValueProxy var count: Int

        lazy var minusButton = UIButton(frame: .zero, primaryAction: UIAction { [unowned self] _ in
            count -= 1
        })
        lazy var plusButton = UIButton(frame: .zero, primaryAction: UIAction { [unowned self] _ in
            count += 1
        })

        init(count: ValueProxy<Int>) {
            self._count = count
            super.init(frame: .zero)
            self.addSubview(minusButton)
            self.addSubview(plusButton)
        }
    }

    @ObservedState var viewModel = ViewModel()
    var observers: [StateValueObserver] = []

    lazy var countLabel = UILabel()
    // Pass value proxy to ViewModel's count property
    lazy var stepper = StepperView(count: $viewModel.count)

    func setupView() {
        addSubview(stepper)
        // Use an update handler to set the label‘s text when count updates
        $viewModel.count.didUpdate { [weak self] count in
            self?.countLabel.text = "\(count)"
        }.add(to: &observers)
    }
}
```
*(basic counter sample code demonstrating updating a `ValueProxy` and `didUpdate` logic)*

## 📦 Installation
To add this dependency to your Xcode project, select File -> Add Package and enter this repository's URL: `https://github.com/PimCoumans/DidUpdate`

## 🤷 But, why?
I love SwiftUI, but for now I feel more comfortable using plain old UIKit for the more complex parts of my apps. I **do** love how SwiftUI lets you define state and have it automatically update all your views when anything changes. I wanted _that_, but not with the overhead of importing SwiftUI or Combine and using a bunch of publishers, or learning a whole new reactive library.

So I reverse-over-engineered the parts I liked and introduced the ability to add update handlers to your bindings (`ObservedValue` in DidUpdate land).

Now you can have a tiny reactive-ish architecture for you UIKit views too!

## ↔️ What does it do exactly?
The two main features are
- Tell you when a specific property in your model class has been updated, and when it conforms to `Equatable` even when its value was actually changed.
- Pass along two-way binding property wrappers that can update properties on your model class, making sure its `didSet { }` is called as well. It‘s also possible to create bindings to nested properties using KeyPath subscripts (like `$viewModel.someFrame.size.width`).

## ✨ How can I do this?
To enable this magic, make sure your model object conforms to `ObservableState` and hold onto it using the `@ObservedState` property wrapper in your view (controller). For all your model‘s properties use `@ObservedValue` when you want these to be observable.

### Handling updates/changes
On all value properties you get a bunch of `didUpdate` methods, allowing you to provide update handlers that are executed when the property is updated.
```swift
let observer = $viewModel.username.didUpdate { username in
    print("Username updated to: \(username)")
}
```
or when you have a `@ValueProxy` set in some other view:
```swift
let observer = $username.didUpdate { username in
    print("Username updated to: \(username)")
}
```
Ideally you‘d store those returned observers in an array, much like `[AnyCancellable]`:
```swift
var observers: [StateValueObserver] = []
func addObservers() {
    $username.didUpate { newValue in
        // ...
    }.add(to: &observers)
}
```

Besides `didUpdate` there's also `didChange` indicating the value has actually changed (meaning not considered equal when conforming to `Equatable`):
```swift
let observer = $viewModel.username.didChange { username in
    print("Username has changed to: \(username)")
}
```
and `didChange(comparing:)` to compare the values at a given key path:
```swift
// Update handler only called when username.isEmpty changes 
let observer = $viewModel.username.didChange(comparing: \.isEmpty) { username in
    if !username.isEmpty {
        print("Username no longer empty")
    } else {
        print("Username empty again")
    }
}
```

### Two-way binding (value proxies)
To pass around two-way bindings to these values, you can create a `ValueProxy` by accessing the projected value (with `$`) of your object‘s property wrapper:

```swift
class SubView: UIView {
    @ValueProxy var username: String
    init(username: ValueProxy<String>) {
        _username = username
    }
}
// in your main view, access the projected value using the `$` prefix 
let someSubView = SubView(username: $viewModel.username)
```

Changing the username property in `SubView` in this example would automatically update the property in your viewModel. Reading the `username` property in `SubView` would give you the actual up-to-date value, even when changed from somewhere else (just like you‘d expect from `@Binding`).

