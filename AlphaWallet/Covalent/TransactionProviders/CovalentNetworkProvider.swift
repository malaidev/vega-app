//
//  CovalentNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import Foundation
import Alamofire
import SwiftyJSON 
import Combine
import APIKit
import PromiseKit

public enum DataRequestError: Error {
    case general(error: Error)
}

extension Covalent {
    enum CovalentError: Error {
        case jsonDecodeFailure
        case requestFailure(DataRequestError)
        case sessionError(SessionTaskError)
    }

    final class NetworkProvider {
        private let key = Constants.Credentials.covalentApiKey

        func transactions(walletAddress: AlphaWallet.Address, server: RPCServer, page: Int? = nil, pageSize: Int = 5, blockSignedAtAsc: Bool = false) -> AnyPublisher<TransactionsResponse, CovalentError> {
            return Alamofire
                .request(ApiUrlProvider.transactions(walletAddress: walletAddress, server: server, page: page, pageSize: pageSize, apiKey: key, blockSignedAtAsc: blockSignedAtAsc))
                .validate()
                .responseJSONPublisher(options: [])
                .tryMap { response -> TransactionsResponse in
                    guard let rawJson = response.json as? [String: Any] else { throw CovalentError.jsonDecodeFailure }
                    return try TransactionsResponse(json: JSON(rawJson))
                }
                .mapError { return CovalentError.requestFailure(.general(error: $0)) }
                .eraseToAnyPublisher()
        }

        func balances(walletAddress: AlphaWallet.Address, server: RPCServer, quoteCurrency: String, nft: Bool, noNftFetch: Bool) -> AnyPublisher<BalancesResponse, CovalentError> {
            return Alamofire
                .request(ApiUrlProvider.balances(walletAddress: walletAddress, server: server, quoteCurrency: quoteCurrency, nft: nft, noNftFetch: noNftFetch, apiKey: key))
                .validate()
                .responseJSONPublisher(options: [])
                .tryMap { response -> BalancesResponse in
                    guard let rawJson = response.json as? [String: Any] else { throw CovalentError.jsonDecodeFailure }
                    return try BalancesResponse(json: JSON(rawJson))
                }
                .mapError { return CovalentError.requestFailure(.general(error: $0)) }
                .eraseToAnyPublisher()
        }
    }
}

extension Alamofire.DataRequest {
    /// Adds a handler to be called once the request has finished.
    public func responseJSONPublisher(queue: DispatchQueue? = DispatchQueue.global(), options: JSONSerialization.ReadingOptions = .allowFragments) -> AnyPublisher<(json: Any, response: PMKAlamofireDataResponse), DataRequestError> {
        var dataRequest: DataRequest?
        let publisher = Future<(json: Any, response: PMKAlamofireDataResponse), DataRequestError> { seal in
            dataRequest = self.responseJSON(queue: queue, options: options) { response in
                switch response.result {
                case .success(let value):
                    seal(.success((value, PMKAlamofireDataResponse(response))))
                case .failure(let error):
                    seal(.failure(.general(error: error)))
                }
            }
        }.handleEvents(receiveCancel: {
            dataRequest?.cancel()
        })

        return publisher
            .eraseToAnyPublisher()
    }
}