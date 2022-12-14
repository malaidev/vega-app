// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappsHomeViewControllerHeaderViewViewModel {
    let isEditing: Bool

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.defaultViewBackground
    }

    var title: String {
        return R.string.localizable.dappBrowserTitle()
    }

    var myDappsButtonImage: UIImage? {
        return R.image.myDapps()
    }

    var myDappsButtonTitle: String {
        return R.string.localizable.myDappsButtonImageLabel()
    }

    var historyButtonImage: UIImage? {
        return R.image.history()
    }

    var historyButtonTitle: String {
        return R.string.localizable.historyButtonImageLabel()
    }
}
