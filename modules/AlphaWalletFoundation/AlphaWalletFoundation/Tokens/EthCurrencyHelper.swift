// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit.UIColor

public struct EthCurrencyHelper {
    private let ticker: CoinTicker?

    public enum Change24h {
        case appreciate(percentageChange24h: Double)
        case depreciate(percentageChange24h: Double)
        case none
    }
    
    public var change24h: Change24h {
        return change24h(from: ticker?.percent_change_24h)
    }

    public var marketPrice: Double? {
        return ticker?.price_usd
    }

    public func valueChanged24h(value: NSDecimalNumber?) -> Double? {
        guard let fiatValue = fiatValue(value: value), let ticker = ticker else { return .none }

        return fiatValue * ticker.percent_change_24h / 100
    }

    public func change24h(from value: Double?) -> Change24h {
        if let value = value {
            if isValueAppreciated24h(value) {
                return .appreciate(percentageChange24h: value)
            } else if isValueDepreciated24h(value) {
                return .depreciate(percentageChange24h: value)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }

    public func fiatValue(value: NSDecimalNumber?) -> Double? {
        guard let value = value, let ticker = ticker else { return .none }

        return value.doubleValue * ticker.price_usd
    }

    private func isValueAppreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange > 0
        } else {
            return false
        }
    }

    private func isValueDepreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange < 0
        } else {
            return false
        }
    }

    public init(ticker: CoinTicker?) {
        self.ticker = ticker
    }
}

extension EthCurrencyHelper.Change24h {
    public var string: String? {
        switch self {
        case .appreciate(let percentageChange24h):
            return "\(Formatter.priceChange.string(from: percentageChange24h) ?? "")%"
        case .depreciate(let percentageChange24h):
            return "\(Formatter.priceChange.string(from: percentageChange24h) ?? "")%"
        case .none:
            return nil
        }
    }
}
