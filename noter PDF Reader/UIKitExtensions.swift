import UIKit

extension UINavigationController {
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        navigationBar.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        navigationBar.setNeedsUpdateConstraints()
    }
}
