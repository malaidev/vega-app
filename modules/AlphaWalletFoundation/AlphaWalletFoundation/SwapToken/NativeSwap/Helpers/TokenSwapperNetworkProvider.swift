//
//  LiQuestTokenSwapperNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

import Foundation
import Combine
import SwiftyJSON
import Alamofire
import BigInt
import AlphaWalletCore

public protocol TokenSwapperNetworkProvider {
    func fetchSupportedTools() -> AnyPublisher<[SwapTool], SwapError>
    func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError>
    func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError>
    func fetchSwapRoutes(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<[SwapRoute], SwapError>
    func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<SwapQuote, SwapError>
}

public final class LiQuestTokenSwapperNetworkProvider: TokenSwapperNetworkProvider {
    private static let baseUrl = URL(string: "https://li.quest")!
    public init() {}

    public func fetchSupportedTools() -> AnyPublisher<[SwapTool], SwapError> {
        Alamofire.request(ToolsRequest()).validate()
            .responseDataPublisher()
            .tryMap { jsonData, _ -> [SwapTool] in
                if let response: SwapToolsResponse = try? JSONDecoder().decode(SwapToolsResponse.self, from: jsonData) {
                    return response.tools
                } else {
                    throw SwapError.invalidJson
                }
            }.mapError { LiQuestTokenSwapperNetworkProvider.mapToSwapError($0) }
            .eraseToAnyPublisher()
    }

    public func fetchSwapRoutes(fromToken: TokenToSwap, toToken: TokenToSwap, slippage: String, fromAmount: BigUInt, exchanges: [String]) -> AnyPublisher<[SwapRoute], SwapError> {
        return Alamofire.request(RoutesRequest(fromToken: fromToken, toToken: toToken, slippage: slippage, fromAmount: fromAmount, exchanges: exchanges)).validate()
            .responseDataPublisher()
            .tryMap { jsonData, _ -> [SwapRoute] in
                if let response: SwapRouteReponse = try? JSONDecoder().decode(SwapRouteReponse.self, from: jsonData) {
                    return response.routes
                } else {
                    throw SwapError.invalidJson
                }
            }.mapError { return LiQuestTokenSwapperNetworkProvider.mapToSwapError($0) }
            .eraseToAnyPublisher()
    }

    public func fetchSupportedChains() -> AnyPublisher<[RPCServer], PromiseError> {
        return Alamofire.request(SupportedChainsRequest()).validate()
            .responseJSONPublisher()
            .map { rawJson, _ -> [RPCServer] in
                let chains = JSON(rawJson)["chains"].arrayValue
                return chains.compactMap { each in return RPCServer(chainIdOptional: each["id"].intValue) }
            }.eraseToAnyPublisher()
    }

    public func fetchSupportedTokens(for server: RPCServer) -> AnyPublisher<SwapPairs, PromiseError> {
        return Alamofire.request(SupportedTokensRequest(server: server))
            .responseDataPublisher()
            .map { jsonData, _ -> SwapPairs in
                if let connections: Swap.Connections = try? JSONDecoder().decode(Swap.Connections.self, from: jsonData) {
                    return SwapPairs(connections: connections)
                } else {
                    return SwapPairs(connections: .init(connections: []))
                }
            }.eraseToAnyPublisher()
    }

    public func fetchSwapQuote(fromToken: TokenToSwap, toToken: TokenToSwap, wallet: AlphaWallet.Address, slippage: String, fromAmount: BigUInt, exchange: String) -> AnyPublisher<SwapQuote, SwapError> {
        let request = SwapQuoteRequest(fromToken: fromToken, toToken: toToken, wallet: wallet, slippage: slippage, fromAmount: fromAmount, exchange: exchange)
        return Alamofire.request(request)
            .responseJSONPublisher()
            .tryMap { rawJson, _ -> SwapQuote in
                guard let data = try? JSONSerialization.data(withJSONObject: rawJson) else { throw SwapError.invalidJson }
                if let swapQuote = try? JSONDecoder().decode(SwapQuote.self, from: data) {
                    return swapQuote
                } else if let error = try? JSONDecoder().decode(SwapQuote.Error.self, from: data) {
                    throw SwapError.unableToBuildSwapUnsignedTransaction(message: error.message)
                } else {
                    throw SwapError.unableToBuildSwapUnsignedTransactionFromSwapProvider
                }
            }.mapError { LiQuestTokenSwapperNetworkProvider.mapToSwapError($0) }
            .eraseToAnyPublisher()
    }

    private static func mapToSwapError(_ e: Error) -> SwapError {
        if let error = e as? SwapError {
            return error
        } else {
            return SwapError.unknownError
        }
    }
}

fileprivate extension LiQuestTokenSwapperNetworkProvider {

    struct ToolsRequest: URLRequestConvertible {

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworkProvider.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/tools"
            return try URLRequest(url: components.asURL(), method: .get)
        }
    }

    struct RoutesRequest: URLRequestConvertible {
        let fromToken: TokenToSwap
        let toToken: TokenToSwap
        let slippage: String
        let fromAmount: BigUInt
        let exchanges: [String]
        
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworkProvider.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/advanced/routes"
            var request = try URLRequest(url: components.asURL(), method: .post)
            var options: Parameters = ["slippage": slippage.doubleValue]
            if !exchanges.isEmpty {
                options["exchanges"] = exchanges
            }

            return try JSONEncoding().encode(request, with: [
                "options": options,
                "fromChainId": fromToken.server.chainID,
                "toChainId": toToken.server.chainID,
                "fromTokenAddress": fromToken.address.eip55String,
                "toTokenAddress": toToken.address.eip55String,
                "fromAmount": String(fromAmount)
            ]).appending(httpHeaders: ["accept": "application/json"])
        }
    }

    struct SwapQuoteRequest: URLRequestConvertible {
        let fromToken: TokenToSwap
        let toToken: TokenToSwap
        let wallet: AlphaWallet.Address
        let slippage: String
        let fromAmount: BigUInt
        let exchange: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworkProvider.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/quote"
            var request = try URLRequest(url: components.asURL(), method: .get)

            return try URLEncoding().encode(request, with: [
                "fromChain": fromToken.server.chainID,
                "toChain": toToken.server.chainID,
                "fromToken": fromToken.address.eip55String,
                "toToken": toToken.address.eip55String,
                "fromAddress": wallet.eip55String,
                "fromAmount": String(fromAmount),
                //"order": "BEST_VALUE", this param doesn't work for now
                "slippage": slippage,
                //"allowExchanges": "paraswap,openocean,0x,uniswap,sushiswap,quickswap,honeyswap,pancakeswap,spookyswap,viperswap,solarbeam,dodo",
                "allowExchanges": exchange,
            ])
        }
    }

    struct SupportedTokensRequest: URLRequestConvertible {
        let server: RPCServer

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworkProvider.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/connections"
            var request = try URLRequest(url: components.asURL(), method: .post)

            return try URLEncoding().encode(request, with: [
                "fromChain": server.chainID,
                "toChain": server.chainID,
            ])
        }
    }

    struct SupportedChainsRequest: URLRequestConvertible {
        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: LiQuestTokenSwapperNetworkProvider.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/v1/chains"
            return try URLRequest(url: components.asURL(), method: .get)
        }
    }
}

extension URLRequest {

    public func appending(httpHeaders: [String: String]) -> URLRequest {
        var request = self
        request.allHTTPHeaderFields = (request.allHTTPHeaderFields ?? [:]).merging(httpHeaders) { (_, new) in new }

        return request
    }

    public func curl(pretty: Bool = false) -> String {

        var data: String = ""
        let complement = pretty ? "\\\n" : ""
        let method = "-X \(self.httpMethod ?? "GET") \(complement)"
        let url = "\"" + (self.url?.absoluteString ?? "") + "\""

        var header = ""

        if let httpHeaders = self.allHTTPHeaderFields, !httpHeaders.keys.isEmpty {
            for (key, value) in httpHeaders {
                header += "-H \"\(key): \(value)\" \(complement)"
            }
        }

        if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            data = "-d \"\(bodyString)\" \(complement)"
        }

        let command = "curl -i " + complement + method + header + data + url

        return command
    }

}
