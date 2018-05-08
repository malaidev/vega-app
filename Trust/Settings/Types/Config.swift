// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import ObjectiveC

struct Config {

    struct Keys {
        static let chainID = "chainID"
        static let isCryptoPrimaryCurrency = "isCryptoPrimaryCurrency"
        static let isDebugEnabled = "isDebugEnabled"
        static let currencyID = "currencyID"
        static let dAppBrowser = "dAppBrowser"
        static let walletAddressesAlreadyPromptedForBackUp = "walletAddressesAlreadyPromptedForBackUp "
        static let language = "language"
    }

    let defaults: UserDefaults

    init(
        defaults: UserDefaults = UserDefaults.standard
    ) {
        self.defaults = defaults
    }

    var currency: Currency {
        get {
            //If it is saved currency
            if let currency = defaults.string(forKey: Keys.currencyID) {
                return Currency(rawValue: currency)!
            }
            //If ther is not saved currency try to use user local currency if it is supported.
            let avaliableCurrency = Currency.allValues.first { currency in
                return currency.rawValue == Locale.current.currencySymbol
            }
            if let isAvaliableCurrency = avaliableCurrency {
                return isAvaliableCurrency
            }
            //If non of the previous is not working return USD.
            return Currency.USD
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.currencyID) }
    }

    var chainID: Int {
        get {
            let id = defaults.integer(forKey: Keys.chainID)
            guard id > 0 else { return RPCServer.main.chainID }
            return id
        }
        set { defaults.set(newValue, forKey: Keys.chainID) }
    }

    var language: String? {
        get { return defaults.string(forKey: Keys.language) }
        set {
            let preferenceKeyForOverridingInAppLanguage = "AppleLanguages"
            if let language = newValue {
                defaults.set(newValue, forKey: Keys.language)
                defaults.set([language], forKey: preferenceKeyForOverridingInAppLanguage)
            } else {
                defaults.removeObject(forKey: Keys.language)
                defaults.removeObject(forKey: preferenceKeyForOverridingInAppLanguage)
            }
            defaults.synchronize()
            LiveLanguageSwitcherBundle.switchLanguage(to: newValue)
        }
    }

    var isCryptoPrimaryCurrency: Bool {
        get { return defaults.bool(forKey: Keys.isCryptoPrimaryCurrency) }
        set { defaults.set(newValue, forKey: Keys.isCryptoPrimaryCurrency) }
    }

    var isDebugEnabled: Bool {
        get { return defaults.bool(forKey: Keys.isDebugEnabled) }
        set { defaults.set(newValue, forKey: Keys.isDebugEnabled) }
    }

    var server: RPCServer {
        return RPCServer(chainID: chainID)
    }

    var rpcURL: URL {
        let urlString: String = {
            switch server {
            case .main: return "https://mainnet.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .classic: return "https://mewapi.epool.io/"
            case .callisto: return "https://callisto.network/" //TODO Add endpoint
            case .kovan: return "https://kovan.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .ropsten: return "https://ropsten.infura.io/llyrtzQ3YhkdESt2Fzrk" //"http://stormbird.duckdns.org:8545"
            case .rinkeby: return "https://rinkeby.infura.io/llyrtzQ3YhkdESt2Fzrk"
            case .poa: return "https://core.poa.network"
            case .sokol: return "https://sokol.poa.network"
            case .custom(let custom):
                return custom.endpoint
            }
        }()
        return URL(string: urlString)!
    }

    var remoteURL: URL {
        let urlString: String = {
            switch server {
            case .main: return "https://api.trustwalletapp.com"
            case .classic: return "https://classic.trustwalletapp.com"
            case .callisto: return "https://callisto.trustwalletapp.com"
            case .kovan: return "https://kovan.trustwalletapp.com"
            case .ropsten: return "https://ropsten.trustwalletapp.com"
            case .rinkeby: return "https://rinkeby.trustwalletapp.com"
            case .poa: return "https://poa.trustwalletapp.com"
            case .sokol: return "https://trust-sokol.herokuapp.com"
            case .custom(let custom):
                return "" // Enable? make optional
            }
        }()
        return URL(string: urlString)!
    }

    var walletAddressesAlreadyPromptedForBackUp: [String] {
        if let addresses = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            return addresses as! [String]
        } else {
            return []
        }
    }

    func addToWalletAddressesAlreadyPromptedForBackup(address: String) {
        var addresses: [String]
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            addresses = value as! [String]
        } else {
            addresses = [String]()
        }
        addresses.append(address)
        defaults.setValue(addresses, forKey: Keys.walletAddressesAlreadyPromptedForBackUp)
    }

    func isWalletAddresseAlreadyPromptedForBackUp(address: String) -> Bool {
        if let value = defaults.array(forKey: Keys.walletAddressesAlreadyPromptedForBackUp) {
            let addresses = value as! [String]
            return addresses.contains(address)
        } else {
            return false
        }
    }

}
